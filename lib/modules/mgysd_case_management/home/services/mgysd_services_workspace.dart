import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/service_provision/pages/mgysd_service_provision_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/monitoring/pages/mgysd_household_monitoring_list_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/helpers/mgysd_program_stage_event_helper.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/pages/mgysd_repeatable_stage_list_page.dart';
import 'package:sqflite/sqflite.dart';

class MgysdServicesWorkspace extends StatefulWidget {
  const MgysdServicesWorkspace({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdServicesWorkspace> createState() =>
      _MgysdServicesWorkspaceState();
}

class _ServiceMember {
  const _ServiceMember({
    required this.tei,
    required this.enrollment,
    required this.name,
    required this.role,
    required this.sex,
    required this.age,
    required this.disability,
    required this.isPrimary,
    required this.serviceCount,
    required this.latestServiceDate,
  });

  final String tei;
  final String enrollment;
  final String name;
  final String role;
  final String sex;
  final String age;
  final String disability;
  final bool isPrimary;
  final int serviceCount;
  final String latestServiceDate;

  String get searchableText => <String>[
        name,
        role,
        sex,
        age,
        disability,
        '$serviceCount',
        latestServiceDate,
      ].join(' ').toLowerCase();
}

class _ServiceHousehold {
  const _ServiceHousehold({
    required this.enrollmentId,
    required this.householdTei,
    required this.fileNumber,
    required this.clientName,
    required this.location,
    required this.enrollmentDate,
    required this.members,
  });

  final String enrollmentId;
  final String householdTei;
  final String fileNumber;
  final String clientName;
  final String location;
  final String enrollmentDate;
  final List<_ServiceMember> members;

  int get totalServices =>
      members.fold<int>(0, (int total, _ServiceMember item) {
        return total + item.serviceCount;
      });

  int get membersWithServices =>
      members.where((_ServiceMember item) => item.serviceCount > 0).length;

  bool get hasServices => totalServices > 0;

  String get searchableText => <String>[
        fileNumber,
        clientName,
        location,
        enrollmentDate,
        ...members.map((_ServiceMember item) => item.searchableText),
      ].join(' ').toLowerCase();
}

class _MgysdServicesWorkspaceState extends State<MgysdServicesWorkspace> {
  final TextEditingController _searchController = TextEditingController();

  List<_ServiceHousehold> _items = <_ServiceHousehold>[];
  List<_ServiceHousehold> _filtered = <_ServiceHousehold>[];

  bool _loading = true;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _db() async {
    final Database? db = await OfflineDbProvider().db;
    if (db == null) {
      throw Exception('Offline database is not ready');
    }
    return db;
  }

  Future<bool> _tableExists(Database db, String table) async {
    try {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        <Object?>[table],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _columns(Database db, String table) async {
    try {
      final List<Map<String, Object?>> rows =
          await db.rawQuery('PRAGMA table_info($table)');
      return rows
          .map((Map<String, Object?> row) => '${row['name'] ?? ''}')
          .where((String value) => value.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<String?> _firstColumn(
    Database db,
    String table,
    List<String> candidates,
  ) async {
    final List<String> columns = await _columns(db, table);
    for (final String candidate in candidates) {
      if (columns.contains(candidate)) return candidate;
    }
    return null;
  }

  Future<Map<String, String>> _attributes(
    Database db,
    String tei,
  ) async {
    final Map<String, String> values = <String, String>{};

    if (tei.trim().isEmpty ||
        !await _tableExists(db, 'tracked_entity_instance_attribute')) {
      return values;
    }

    try {
      final List<Map<String, Object?>> rows = await db.query(
        'tracked_entity_instance_attribute',
        where: 'trackedEntityInstance = ?',
        whereArgs: <Object?>[tei],
      );

      for (final Map<String, Object?> row in rows) {
        final String attribute = '${row['attribute'] ?? ''}'.trim();
        final String value = '${row['value'] ?? ''}'.trim();
        if (attribute.isNotEmpty) values[attribute] = value;
      }
    } catch (_) {}

    return values;
  }

  String _first(
    Map<String, String> values,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final String value = (values[key] ?? '').trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  String _displayName(
    Map<String, String> values, {
    required String fallback,
  }) {
    final String firstName = _first(values, <String>[
      MgysdDhis2Uids.attFirstName,
      'ATTR_P_FIRSTNAME',
      'firstName',
      'first_name',
    ]);

    final String lastName = _first(values, <String>[
      MgysdDhis2Uids.attLastName,
      'ATTR_P_LASTNAME',
      'lastName',
      'surname',
      'last_name',
    ]);

    final String fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? fallback : fullName;
  }

  Future<String> _memberEnrollment(
    Database db,
    String memberTei,
  ) async {
    if (memberTei.trim().isEmpty || !await _tableExists(db, 'enrollment')) {
      return '';
    }

    try {
      final List<Map<String, Object?>> rows = await db.query(
        'enrollment',
        where: 'trackedEntityInstance = ? AND program = ?',
        whereArgs: <Object?>[
          memberTei,
          MgysdDhis2Uids.familyMemberTrackerProgram,
        ],
        orderBy: 'enrollmentDate DESC',
        limit: 1,
      );

      if (rows.isEmpty) return '';
      return '${rows.first['enrollment'] ?? rows.first['id'] ?? ''}'.trim();
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, Object>> _serviceSummary(
    Database db,
    String memberTei,
  ) async {
    if (memberTei.trim().isEmpty || !await _tableExists(db, 'events')) {
      return <String, Object>{
        'count': 0,
        'latestDate': '',
      };
    }

    try {
      final List<Map<String, Object?>> rows = await db.query(
        'events',
        where: 'trackedEntityInstance = ? AND programStage = ?',
        whereArgs: <Object?>[
          memberTei,
          MgysdDhis2Uids.familyServiceProvisionStage,
        ],
        orderBy: 'eventDate DESC',
      );

      String latestDate = '';
      if (rows.isNotEmpty) {
        latestDate = '${rows.first['eventDate'] ?? ''}'.trim();
      }

      return <String, Object>{
        'count': rows.length,
        'latestDate': latestDate,
      };
    } catch (_) {
      return <String, Object>{
        'count': 0,
        'latestDate': '',
      };
    }
  }

  Future<String?> _primaryClientTei(
    Database db,
    String householdTei,
  ) async {
    if (!await _tableExists(db, 'mgysd_household_member')) return null;

    try {
      List<Map<String, Object?>> rows = await db.query(
        'mgysd_household_member',
        where: 'householdTei = ? AND isPrimaryClient = ?',
        whereArgs: <Object?>[householdTei, 'true'],
        limit: 1,
      );

      if (rows.isEmpty) {
        rows = await db.query(
          'mgysd_household_member',
          where: 'householdTei = ? AND memberRole = ?',
          whereArgs: <Object?>[householdTei, 'CLIENT'],
          limit: 1,
        );
      }

      if (rows.isEmpty) return null;
      return '${rows.first['memberTei'] ?? ''}'.trim();
    } catch (_) {
      return null;
    }
  }

  Future<List<_ServiceMember>> _members(
    Database db,
    String householdTei,
  ) async {
    if (!await _tableExists(db, 'mgysd_household_member')) {
      return <_ServiceMember>[];
    }

    try {
      final List<Map<String, Object?>> rows = await db.query(
        'mgysd_household_member',
        where: 'householdTei = ?',
        whereArgs: <Object?>[householdTei],
      );

      final List<_ServiceMember> result = <_ServiceMember>[];

      for (final Map<String, Object?> row in rows) {
        final String memberTei = '${row['memberTei'] ?? ''}'.trim();
        if (memberTei.isEmpty) continue;

        final String role = '${row['memberRole'] ?? 'MEMBER'}'
            .trim()
            .replaceAll('_', ' ');

        final Map<String, String> attributes =
            await _attributes(db, memberTei);
        final Map<String, Object> serviceSummary =
            await _serviceSummary(db, memberTei);

        result.add(
          _ServiceMember(
            tei: memberTei,
            enrollment: await _memberEnrollment(db, memberTei),
            name: _displayName(
              attributes,
              fallback: role.isEmpty ? 'Household member' : role,
            ),
            role: role,
            sex: _first(attributes, <String>[
              MgysdDhis2Uids.attSex,
              'sex',
            ]),
            age: _first(attributes, <String>[
              MgysdDhis2Uids.attAge,
              'age',
            ]),
            disability: _first(attributes, <String>[
              MgysdDhis2Uids.attIsDisabled,
              'hasDisability',
              'disability',
            ]),
            isPrimary:
                '${row['isPrimaryClient'] ?? ''}'.toLowerCase() == 'true' ||
                    '${row['memberRole'] ?? ''}'.toUpperCase() == 'CLIENT',
            serviceCount: serviceSummary['count'] as int,
            latestServiceDate:
                '${serviceSummary['latestDate'] ?? ''}'.trim(),
          ),
        );
      }

      result.sort((_ServiceMember a, _ServiceMember b) {
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        return a.name.compareTo(b.name);
      });

      return result;
    } catch (_) {
      return <_ServiceMember>[];
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final Database db = await _db();

      if (!await _tableExists(db, 'enrollment')) {
        if (!mounted) return;
        setState(() {
          _items = <_ServiceHousehold>[];
          _filtered = <_ServiceHousehold>[];
          _loading = false;
        });
        return;
      }

      final List<Map<String, Object?>> enrollmentRows = await db.query(
        'enrollment',
        where: 'program = ?',
        whereArgs: <Object?>[
          MgysdDhis2Uids.enrolledHouseholdsProgram,
        ],
        orderBy: 'enrollmentDate DESC',
      );

      final Map<String, Map<String, Object?>> latestByHousehold =
          <String, Map<String, Object?>>{};

      for (final Map<String, Object?> row in enrollmentRows) {
        final String householdTei =
            '${row['trackedEntityInstance'] ?? ''}'.trim();
        if (householdTei.isEmpty) continue;

        latestByHousehold.putIfAbsent(householdTei, () => row);
      }

      final List<_ServiceHousehold> households = <_ServiceHousehold>[];

      for (final MapEntry<String, Map<String, Object?>> entry
          in latestByHousehold.entries) {
        final String householdTei = entry.key;
        final Map<String, Object?> enrollment = entry.value;
        final Map<String, String> householdAttributes =
            await _attributes(db, householdTei);

        final String? primaryClientTei =
            await _primaryClientTei(db, householdTei);
        final Map<String, String> primaryAttributes =
            primaryClientTei == null
                ? <String, String>{}
                : await _attributes(db, primaryClientTei);

        final String fileNumber = _first(
          householdAttributes,
          <String>[
            MgysdDhis2Uids.attHouseholdFileNumber,
            'ATTR_HH_FILE_NUMBER',
            'fileNumber',
          ],
        );

        final String district = _first(
          householdAttributes,
          <String>[
            MgysdDhis2Uids.attHouseholdDistrict,
            'district',
          ],
        );

        final String council = _first(
          householdAttributes,
          <String>[
            MgysdDhis2Uids.attHouseholdCommunityCouncil,
            'communityCouncil',
          ],
        );

        final String village = _first(
          householdAttributes,
          <String>[
            MgysdDhis2Uids.attHouseholdVillage,
            'village',
          ],
        );

        households.add(
          _ServiceHousehold(
            enrollmentId:
                '${enrollment['enrollment'] ?? enrollment['id'] ?? ''}',
            householdTei: householdTei,
            fileNumber:
                fileNumber.isEmpty ? householdTei : fileNumber,
            clientName: _displayName(
              primaryAttributes,
              fallback: 'Household client',
            ),
            location: <String>[district, council, village]
                .where((String value) => value.trim().isNotEmpty)
                .join(' • '),
            enrollmentDate: '${enrollment['enrollmentDate'] ?? ''}',
            members: await _members(db, householdTei),
          ),
        );
      }

      households.sort((_ServiceHousehold a, _ServiceHousehold b) {
        if (a.hasServices != b.hasServices) {
          return a.hasServices ? -1 : 1;
        }
        return b.enrollmentDate.compareTo(a.enrollmentDate);
      });

      if (!mounted) return;
      setState(() {
        _items = households;
        _loading = false;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load services workspace: $error'),
        ),
      );
    }
  }

  void _applyFilters() {
    final String query = _searchController.text.trim().toLowerCase();

    final List<_ServiceHousehold> filtered =
        _items.where((_ServiceHousehold item) {
      if (_filter == 'WITH_SERVICES' && !item.hasServices) return false;
      if (_filter == 'NO_SERVICES' && item.hasServices) return false;
      if (_filter == 'MEMBERS_PENDING' &&
          item.members.isNotEmpty &&
          item.members.every((_ServiceMember member) {
            return member.serviceCount > 0;
          })) {
        return false;
      }

      if (query.isNotEmpty && !item.searchableText.contains(query)) {
        return false;
      }

      return true;
    }).toList();

    setState(() => _filtered = filtered);
  }

  void _openFilterSheet() {
    final List<Map<String, String>> options = <Map<String, String>>[
      <String, String>{
        'value': 'ALL',
        'label': 'All enrolled households',
      },
      <String, String>{
        'value': 'WITH_SERVICES',
        'label': 'Households with services',
      },
      <String, String>{
        'value': 'NO_SERVICES',
        'label': 'No services recorded',
      },
      <String, String>{
        'value': 'MEMBERS_PENDING',
        'label': 'Members without services',
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Filter service records',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Find households receiving support or members who may still need services.',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12.3,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((Map<String, String> option) {
                  final String value = option['value']!;
                  final bool selected = _filter == value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? widget.color.withOpacity(0.08)
                          : const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected
                            ? widget.color.withOpacity(0.22)
                            : Colors.blueGrey.withOpacity(0.08),
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: value,
                      groupValue: _filter,
                      activeColor: widget.color,
                      title: Text(
                        option['label']!,
                        style: TextStyle(
                          color: selected
                              ? widget.color
                              : Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        Navigator.pop(sheetContext);
                        setState(() => _filter = newValue);
                        _applyFilters();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _activeFilterLabel() {
    switch (_filter) {
      case 'WITH_SERVICES':
        return 'Households with services';
      case 'NO_SERVICES':
        return 'No services recorded';
      case 'MEMBERS_PENDING':
        return 'Members without services';
      default:
        return 'All enrolled households';
    }
  }

  MgysdCase _asCase(_ServiceHousehold household) {
    return MgysdCase(
      id: household.enrollmentId,
      caseNo: household.fileNumber,
      fullName: household.clientName,
      district: household.location,
      status: 'ENROLLED',
      enrollmentDate: household.enrollmentDate,
    );
  }

  String _newServiceId(_ServiceHousehold household) {
    final String rootId = household.enrollmentId.trim().isNotEmpty
        ? household.enrollmentId.trim()
        : household.householdTei.trim();

    return '${rootId}__service_provision__${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _openServices(
    _ServiceHousehold household,
    _ServiceMember member,
  ) async {
    try {
      final Database db = await _db();
      final String eventId = _newServiceId(household);

      await MgysdProgramStageEventHelper.saveContext(
        db: db,
        eventId: eventId,
        parentCaseId: household.enrollmentId,
        stageKey: 'service_provision',
        tableName: 'mgysd_service_provision',
        programStage: MgysdDhis2Uids.familyServiceProvisionStage,
        trackedEntityInstance: member.tei,
        enrollment: member.enrollment,
        householdTei: household.householdTei,
        householdName: household.fileNumber,
        clientName: household.clientName,
        subjectName: member.name,
        subjectRole: member.role,
      );

      final MgysdCase serviceCase = MgysdCase(
        id: eventId,
        caseNo: household.fileNumber,
        fullName: member.name,
        district: household.location,
        status: 'ENROLLED',
        enrollmentDate: household.enrollmentDate,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MgysdServiceProvisionPage(
            color: widget.color,
            mgysdCase: serviceCase,
            householdTei: household.householdTei,
            householdName: household.fileNumber,
            clientName: household.clientName,
            memberTei: member.tei,
            memberName: member.name,
            memberRole: member.role,
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open service form: $error'),
        ),
      );
    }
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
        ),
      ),
    );
  }

  Future<void> _openHouseholdServices(
    _ServiceHousehold household,
  ) async {
    try {
      final Database db = await _db();
      final String eventId =
          '${household.enrollmentId.trim().isNotEmpty ? household.enrollmentId.trim() : household.householdTei.trim()}__household_service_provision__${DateTime.now().millisecondsSinceEpoch}';

      await MgysdProgramStageEventHelper.saveContext(
        db: db,
        eventId: eventId,
        parentCaseId: household.enrollmentId,
        stageKey: 'service_provision',
        tableName: 'mgysd_service_provision',
        programStage: MgysdDhis2Uids.familyServiceProvisionStage,
        trackedEntityInstance: household.householdTei,
        enrollment: household.enrollmentId,
        householdTei: household.householdTei,
        householdName: household.fileNumber,
        clientName: household.clientName,
        subjectName: household.clientName,
        subjectRole: 'HOUSEHOLD',
      );

      final MgysdCase serviceCase = MgysdCase(
        id: eventId,
        caseNo: household.fileNumber,
        fullName: household.clientName,
        district: household.location,
        status: 'ENROLLED',
        enrollmentDate: household.enrollmentDate,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MgysdServiceProvisionPage(
            color: widget.color,
            mgysdCase: serviceCase,
            householdTei: household.householdTei,
            householdName: household.fileNumber,
            clientName: household.clientName,
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open household service form: $error'),
        ),
      );
    }
  }

  Future<void> _openHouseholdMonitoring(
    _ServiceHousehold household,
  ) async {
    final MgysdCase householdCase = MgysdCase(
      id: household.enrollmentId,
      caseNo: household.fileNumber,
      fullName: household.clientName,
      district: household.location,
      status: 'ENROLLED',
      enrollmentDate: household.enrollmentDate,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdHouseholdMonitoringListPage(
          color: widget.color,
          householdCase: householdCase,
          householdTei: household.householdTei,
          enrollment: household.enrollmentId,
          householdName: household.fileNumber,
          clientName: household.clientName,
        ),
      ),
    );

    await _load();
  }

  Widget _memberTile(
    _ServiceHousehold household,
    _ServiceMember member,
  ) {
    final List<String> details = <String>[
      if (member.role.trim().isNotEmpty) member.role,
      if (member.sex.trim().isNotEmpty) member.sex,
      if (member.age.trim().isNotEmpty) '${member.age} yrs',
      if (member.disability.trim().isNotEmpty &&
          member.disability.toUpperCase() != 'NO')
        'Disability: ${member.disability}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: member.serviceCount > 0
              ? Colors.green.withOpacity(0.10)
              : Colors.blueGrey.withOpacity(0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: member.serviceCount > 0
                ? Colors.green.withOpacity(0.10)
                : widget.color.withOpacity(0.09),
            child: Icon(
              member.isPrimary
                  ? Icons.person_pin_outlined
                  : Icons.person_outline,
              color: member.serviceCount > 0
                  ? Colors.green
                  : widget.color,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  member.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.2,
                  ),
                ),
                if (details.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    details.join(' • '),
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.4,
                      height: 1.25,
                    ),
                  ),
                ],
                if (member.latestServiceDate.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Latest service: ${member.latestServiceDate}',
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _openServices(household, member),
            style: TextButton.styleFrom(
              foregroundColor: widget.color,
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11.7,
              ),
            ),
            child: Text(
              member.serviceCount == 0
                  ? 'Services'
                  : 'Services (${member.serviceCount})',
            ),
          ),
        ],
      ),
    );
  }

  Widget _householdCard(_ServiceHousehold household) {
    final Color statusColor =
        household.hasServices ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.12),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            radius: 23,
            backgroundColor: statusColor.withOpacity(0.11),
            child: Icon(
              Icons.home_work_outlined,
              color: statusColor,
            ),
          ),
          title: Text(
            household.clientName,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextButton(
                onPressed: () => _openHouseholdServices(household),
                style: TextButton.styleFrom(
                  foregroundColor: widget.color,
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.6),
                ),
                child: const Text('HH Services'),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => _openHouseholdMonitoring(household),
                style: TextButton.styleFrom(
                  foregroundColor: widget.color,
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.6),
                ),
                child: const Text('Monitoring'),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down, color: Colors.blueGrey),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  <String>[
                    'File ${household.fileNumber}',
                    if (household.location.isNotEmpty)
                      household.location,
                  ].join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.8,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    _pill(
                      '${household.members.length} member${household.members.length == 1 ? '' : 's'}',
                      Colors.blueGrey,
                    ),
                    _pill(
                      '${household.totalServices} service${household.totalServices == 1 ? '' : 's'}',
                      statusColor,
                    ),
                    if (household.members.isNotEmpty)
                      _pill(
                        '${household.membersWithServices}/${household.members.length} supported',
                        widget.color,
                      ),
                  ],
                ),
              ],
            ),
          ),
          children: <Widget>[
            if (household.members.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No household members were found. Complete household member enrollment before recording services.',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              )
            else ...<Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Household members',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...household.members.map(
                (_ServiceMember member) =>
                    _memberTile(household, member),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 34,
              backgroundColor: widget.color.withOpacity(0.09),
              child: Icon(
                Icons.volunteer_activism_outlined,
                color: widget.color,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No enrolled households found',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Households appear here after enrollment. Expand a household to manage services for individual members.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int householdsWithServices =
        _items.where((_ServiceHousehold item) => item.hasServices).length;
    final int totalServices = _items.fold<int>(
      0,
      (int total, _ServiceHousehold item) =>
          total + item.totalServices,
    );

    return RefreshIndicator(
      color: widget.color,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    widget.color,
                    const Color(0xFF1976D2),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.volunteer_activism_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Services',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalServices services • $householdsWithServices/${_items.length} households receiving support',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) {
                            setState(() {});
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search this device',
                            prefixIcon: Tooltip(
                              message:
                                  'Offline search: searches households and members stored on this device',
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: widget.color,
                                ),
                              ),
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? const Tooltip(
                                    message:
                                        'Online search will use the globe icon in a later update',
                                    child: Icon(
                                      Icons.public_outlined,
                                      color: Colors.blueGrey,
                                      size: 20,
                                    ),
                                  )
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                      _applyFilters();
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _openFilterSheet,
                              child: Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _filter == 'ALL'
                                        ? Colors.blueGrey.withOpacity(0.10)
                                        : widget.color.withOpacity(0.22),
                                  ),
                                ),
                                child: Icon(
                                  Icons.tune_outlined,
                                  color: _filter == 'ALL'
                                      ? Colors.blueGrey
                                      : widget.color,
                                ),
                              ),
                            ),
                          ),
                          if (_filter != 'ALL')
                            Positioned(
                              right: -3,
                              top: -3,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: widget.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (_filter != 'ALL') ...<Widget>[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Filter: ${_activeFilterLabel()}',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _empty(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return _householdCard(_filtered[index]);
                },
                childCount: _filtered.length,
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }
}
