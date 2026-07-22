import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/enrollment/pages/mgysd_new_case_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/social_investigation/pages/mgysd_social_investigation_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/pages/mgysd_repeatable_stage_list_page.dart';
import 'package:sqflite/sqflite.dart';

class MgysdAssessmentWorkspace extends StatefulWidget {
  const MgysdAssessmentWorkspace({
    Key? key,
    required this.color,
    this.refreshToken = 0,
  }) : super(key: key);

  final Color color;
  final int refreshToken;

  @override
  State<MgysdAssessmentWorkspace> createState() =>
      _MgysdAssessmentWorkspaceState();
}

class _HouseholdMember {
  const _HouseholdMember({
    required this.tei,
    required this.name,
    required this.role,
    required this.sex,
    required this.age,
    required this.disability,
    required this.isPrimary,
  });

  final String tei;
  final String name;
  final String role;
  final String sex;
  final String age;
  final String disability;
  final bool isPrimary;
}

class _AssessmentHousehold {
  const _AssessmentHousehold({
    required this.enrollmentId,
    required this.householdTei,
    required this.fileNumber,
    required this.clientName,
    required this.location,
    required this.enrollmentDate,
    required this.enrolled,
    required this.investigationCount,
    required this.clientCategory,
    required this.members,
  });

  final String enrollmentId;
  final String householdTei;
  final String fileNumber;
  final String clientName;
  final String location;
  final String enrollmentDate;
  final bool enrolled;
  final int investigationCount;
  final String clientCategory;
  final List<_HouseholdMember> members;

  bool get isChild => clientCategory.trim().toUpperCase() == 'CHILD';
  String get status => enrolled ? 'ENROLLED' : 'ASSESSED';
  String get searchableText => [
        fileNumber,
        clientName,
        location,
        status,
        clientCategory,
        ...members.map((e) => '${e.name} ${e.role} ${e.sex}'),
      ].join(' ').toLowerCase();
}

class _MgysdAssessmentWorkspaceState
    extends State<MgysdAssessmentWorkspace> {
  final TextEditingController _searchController = TextEditingController();

  List<_AssessmentHousehold> _items = [];
  List<_AssessmentHousehold> _filtered = [];
  bool _loading = true;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MgysdAssessmentWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _db() async {
    final db = await OfflineDbProvider().db;
    if (db == null) throw Exception('Offline database is not ready');
    return db;
  }

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, String>> _attributes(
    Database db,
    String tei,
  ) async {
    final map = <String, String>{};
    if (!await _tableExists(db, 'tracked_entity_instance_attribute')) {
      return map;
    }

    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        where: 'trackedEntityInstance = ?',
        whereArgs: [tei],
      );
      for (final row in rows) {
        final key = (row['attribute'] ?? '').toString();
        final value = (row['value'] ?? '').toString();
        if (key.isNotEmpty) map[key] = value;
      }
    } catch (_) {}

    return map;
  }

  String _first(Map<String, String> attrs, List<String> keys) {
    for (final key in keys) {
      final value = (attrs[key] ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _name(Map<String, String> attrs, String fallback) {
    final first = _first(attrs, [
      MgysdDhis2Uids.attFirstName,
      'ATTR_P_FIRSTNAME',
      'firstName',
    ]);
    final last = _first(attrs, [
      MgysdDhis2Uids.attLastName,
      'ATTR_P_LASTNAME',
      'lastName',
    ]);
    final name = '$first $last'.trim();
    return name.isEmpty ? fallback : name;
  }

  Future<String?> _primaryClientTei(
    Database db,
    String householdTei,
  ) async {
    if (!await _tableExists(db, 'mgysd_household_member')) return null;

    try {
      var rows = await db.query(
        'mgysd_household_member',
        where: 'householdTei = ? AND isPrimaryClient = ?',
        whereArgs: [householdTei, 'true'],
        limit: 1,
      );

      if (rows.isEmpty) {
        rows = await db.query(
          'mgysd_household_member',
          where: 'householdTei = ? AND memberRole = ?',
          whereArgs: [householdTei, 'CLIENT'],
          limit: 1,
        );
      }

      if (rows.isEmpty) return null;
      return (rows.first['memberTei'] ?? '').toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<_HouseholdMember>> _members(
    Database db,
    String householdTei,
  ) async {
    if (!await _tableExists(db, 'mgysd_household_member')) {
      return const [];
    }

    try {
      final rows = await db.query(
        'mgysd_household_member',
        where: 'householdTei = ?',
        whereArgs: [householdTei],
      );

      final result = <_HouseholdMember>[];
      for (final row in rows) {
        final tei = (row['memberTei'] ?? '').toString();
        final attrs = await _attributes(db, tei);
        final role = (row['memberRole'] ?? 'MEMBER').toString();

        result.add(
          _HouseholdMember(
            tei: tei,
            name: _name(attrs, role.replaceAll('_', ' ')),
            role: role.replaceAll('_', ' '),
            sex: _first(attrs, [
              MgysdDhis2Uids.attSex,
              'sex',
            ]),
            age: _first(attrs, [
              MgysdDhis2Uids.attAge,
              'age',
            ]),
            disability: _first(attrs, [
              MgysdDhis2Uids.attIsDisabled,
              'hasDisability',
              'disability',
            ]),
            isPrimary:
                (row['isPrimaryClient'] ?? '').toString().toLowerCase() ==
                    'true',
          ),
        );
      }

      result.sort((a, b) {
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        return a.name.compareTo(b.name);
      });
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<int> _investigationCount(
    Database db,
    String householdTei,
  ) async {
    if (!await _tableExists(db, 'mgysd_social_investigation')) return 0;
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM mgysd_social_investigation WHERE householdTei = ?',
        [householdTei],
      );
      return int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final db = await _db();
      if (!await _tableExists(db, 'enrollment')) {
        if (mounted) {
          setState(() {
            _items = [];
            _filtered = [];
            _loading = false;
          });
        }
        return;
      }

      // Investigation begins from the Assessed Households programme only.
      // Risk level does not control visibility or access.
      final rows = await db.query(
        'enrollment',
        where: 'program = ?',
        whereArgs: [MgysdDhis2Uids.assessedHouseholdsProgram],
        orderBy: 'enrollmentDate DESC',
      );

      final byHousehold = <String, Map<String, Object?>>{};

      for (final row in rows) {
        final householdTei =
            (row['trackedEntityInstance'] ?? '').toString().trim();
        if (householdTei.isEmpty) continue;
        byHousehold.putIfAbsent(householdTei, () => row);
      }

      final result = <_AssessmentHousehold>[];

      for (final entry in byHousehold.entries) {
        final householdTei = entry.key;
        final row = entry.value;
        final householdAttrs = await _attributes(db, householdTei);
        final primaryTei = await _primaryClientTei(db, householdTei);
        final primaryAttrs =
            primaryTei == null ? <String, String>{} : await _attributes(db, primaryTei);
        final members = await _members(db, householdTei);
        const enrolled = false;

        final fileNumber = _first(householdAttrs, [
          MgysdDhis2Uids.attHouseholdFileNumber,
          'ATTR_HH_FILE_NUMBER',
        ]);

        final district = _first(householdAttrs, [
          MgysdDhis2Uids.attHouseholdDistrict,
          'district',
        ]);
        final council = _first(householdAttrs, [
          MgysdDhis2Uids.attHouseholdCommunityCouncil,
          'communityCouncil',
        ]);
        final village = _first(householdAttrs, [
          MgysdDhis2Uids.attHouseholdVillage,
          'village',
        ]);

        result.add(
          _AssessmentHousehold(
            enrollmentId: (row['enrollment'] ?? row['id'] ?? '').toString(),
            householdTei: householdTei,
            fileNumber: fileNumber.isEmpty ? householdTei : fileNumber,
            clientName: _name(primaryAttrs, 'Household client'),
            location: [district, council, village]
                .where((value) => value.trim().isNotEmpty)
                .join(' • '),
            enrollmentDate: (row['enrollmentDate'] ?? '').toString(),
            enrolled: enrolled,
            investigationCount:
                await _investigationCount(db, householdTei),
            clientCategory: _first(primaryAttrs, [
              MgysdDhis2Uids.attClientCategory,
              'clientType',
              'clientCategory',
            ]),
            members: members,
          ),
        );
      }

      result.sort((a, b) {
        if (a.enrolled != b.enrolled) return a.enrolled ? -1 : 1;
        return b.enrollmentDate.compareTo(a.enrollmentDate);
      });

      if (!mounted) return;
      setState(() {
        _items = result;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load assessment workspace: $e')),
      );
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _items.where((item) {
      if (_filter == 'ENROLLED' && !item.enrolled) return false;
      if (_filter == 'ASSESSED' && item.enrolled) return false;
      if (query.isNotEmpty && !item.searchableText.contains(query)) {
        return false;
      }
      return true;
    }).toList();

    setState(() => _filtered = filtered);
  }


  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final options = <Map<String, String>>[
          {'value': 'ALL', 'label': 'All households'},
          {'value': 'ENROLLED', 'label': 'Enrolled households'},
          {'value': 'ASSESSED', 'label': 'Assessed only'},
        ];

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
              children: [
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
                    'Filter households',
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
                    'Choose which intake and assessment records should appear.',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12.3,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((option) {
                  final value = option['value']!;
                  final selected = _filter == value;

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
                          color: selected ? widget.color : Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onChanged: (newValue) {
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
      case 'ENROLLED':
        return 'Enrolled households';
      case 'ASSESSED':
        return 'Assessed only';
      default:
        return 'All households';
    }
  }

  MgysdCase _asCase(_AssessmentHousehold item) {
    return MgysdCase(
      id: item.enrollmentId,
      caseNo: item.fileNumber,
      fullName: item.clientName,
      district: item.location,
      status: item.status,
      enrollmentDate: item.enrollmentDate,
    );
  }

  void _showPrimeroMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Child Cases will be managed in Primero'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openInvestigationList(
    _AssessmentHousehold item,
  ) async {
    if (item.isChild) {
      _showPrimeroMessage();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdRepeatableStageListPage(
          color: widget.color,
          parentCase: _asCase(item),
          stageTitle: 'Social Investigations',
          tableName: 'mgysd_social_investigation',
          stageKey: 'social_investigation',
          programStage: MgysdDhis2Uids.socialInvestigationStage,
          icon: Icons.manage_search_outlined,
          trackedEntityInstance: item.householdTei,
          enrollment: item.enrollmentId,
          householdTei: item.householdTei,
          householdName: item.fileNumber,
          clientName: item.clientName,
          subjectName: item.clientName,
          subjectRole: 'Primary client',
        ),
      ),
    );

    await _load();
  }

  Future<void> _openInvestigation(_AssessmentHousehold item) async {
    if (item.isChild) {
      _showPrimeroMessage();
      return;
    }

    final mgysdCase = _asCase(item);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdSocialInvestigationPage(
          color: widget.color,
          mgysdCase: mgysdCase,
          householdTei: item.householdTei,
          householdName: item.fileNumber,
          clientName: item.clientName,
        ),
      ),
    );

    await _load();
  }

  Widget _memberTile(_HouseholdMember member) {
    final details = [
      if (member.role.isNotEmpty) member.role,
      if (member.sex.isNotEmpty) member.sex,
      if (member.age.isNotEmpty) '${member.age} yrs',
      if (member.disability.isNotEmpty &&
          member.disability.toUpperCase() != 'NO')
        'Disability: ${member.disability}',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: widget.color.withOpacity(0.09),
            child: Icon(
              member.isPrimary
                  ? Icons.person_pin_outlined
                  : Icons.person_outline,
              color: widget.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (member.isPrimary)
            _pill('CLIENT', widget.color),
        ],
      ),
    );
  }

  Widget _householdCard(_AssessmentHousehold item) {
    final statusColor = item.isChild
        ? Colors.amber.shade800
        : (item.enrolled ? Colors.green : Colors.orange);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.12)),
        boxShadow: [
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
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            radius: 23,
            backgroundColor: statusColor.withOpacity(0.11),
            child: Icon(
              item.enrolled
                  ? Icons.home_work_outlined
                  : Icons.fact_check_outlined,
              color: statusColor,
            ),
          ),
          title: Text(
            item.clientName,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: item.isChild
                    ? _showPrimeroMessage
                    : () => _openInvestigationList(item),
                style: TextButton.styleFrom(
                  foregroundColor:
                      item.isChild ? Colors.amber.shade900 : widget.color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11.8,
                  ),
                ),
                icon: Icon(
                  item.isChild
                      ? Icons.lock_outline
                      : Icons.manage_search_outlined,
                  size: 15,
                ),
                label: Text(
                  item.isChild ? 'Primero' : 'Investigation',
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.blueGrey,
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'File ${item.fileNumber}',
                    if (item.location.isNotEmpty) item.location,
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
                  children: [
                    _pill(
                      'Assessed only',
                      statusColor,
                    ),
                    _pill(
                      '${item.members.length} member${item.members.length == 1 ? '' : 's'}',
                      Colors.blueGrey,
                    ),
                    if (item.isChild)
                      _pill('Child • Primero', Colors.amber.shade900),
                    if (!item.isChild)
                      _pill(
                        item.investigationCount == 0
                            ? 'Investigation pending'
                            : '${item.investigationCount} investigation',
                        item.investigationCount == 0
                            ? Colors.deepOrange
                            : Colors.indigo,
                      ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            if (item.isChild) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.amber.shade800.withOpacity(0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.amber.shade900,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'Child Cases will be managed in Primero',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.members.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Household members',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...item.members.map(_memberTile),
              const SizedBox(height: 6),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No household members were found in the offline member table.',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

  @override
  Widget build(BuildContext context) {
    final assessed = _items.length;

    return RefreshIndicator(
      color: widget.color,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.color, const Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Investigation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$assessed assessed household${assessed == 1 ? '' : 's'}',
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
                children: [
                  Row(
                    children: [
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
                        children: [
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
                  if (_filter != 'ALL') ...[
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
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _empty(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _householdCard(_filtered[index]),
                childCount: _filtered.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: widget.color.withOpacity(0.09),
              child: Icon(
                Icons.fact_check_outlined,
                color: widget.color,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No households ready for investigation',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Households appear here after intake and initial risk assessment are completed.',
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
}
