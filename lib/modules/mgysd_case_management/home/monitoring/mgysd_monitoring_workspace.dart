import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/monitoring/pages/mgysd_monitoring_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/helpers/mgysd_program_stage_event_helper.dart';
import 'package:sqflite/sqflite.dart';

class MgysdMonitoringWorkspace extends StatefulWidget {
  const MgysdMonitoringWorkspace({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdMonitoringWorkspace> createState() =>
      _MgysdMonitoringWorkspaceState();
}

class _MonitoringHousehold {
  const _MonitoringHousehold({
    required this.enrollmentId,
    required this.householdTei,
    required this.fileNumber,
    required this.clientName,
    required this.location,
    required this.enrollmentDate,
    required this.monitoringCount,
    required this.latestMonitoringDate,
  });

  final String enrollmentId;
  final String householdTei;
  final String fileNumber;
  final String clientName;
  final String location;
  final String enrollmentDate;
  final int monitoringCount;
  final String latestMonitoringDate;

  bool get hasMonitoring => monitoringCount > 0;

  String get searchableText => <String>[
        fileNumber,
        clientName,
        location,
        enrollmentDate,
        latestMonitoringDate,
        '$monitoringCount',
      ].join(' ').toLowerCase();
}

class _MgysdMonitoringWorkspaceState
    extends State<MgysdMonitoringWorkspace> {
  final TextEditingController _searchController = TextEditingController();

  List<_MonitoringHousehold> _items = <_MonitoringHousehold>[];
  List<_MonitoringHousehold> _filtered = <_MonitoringHousehold>[];

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
        final String key = '${row['attribute'] ?? ''}'.trim();
        final String value = '${row['value'] ?? ''}'.trim();
        if (key.isNotEmpty) values[key] = value;
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

  Future<Map<String, Object>> _monitoringSummary(
    Database db,
    String householdTei,
  ) async {
    if (!await _tableExists(db, 'events')) {
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
          householdTei,
          MgysdDhis2Uids.monitoringStage,
        ],
        orderBy: 'eventDate DESC',
      );

      return <String, Object>{
        'count': rows.length,
        'latestDate':
            rows.isEmpty ? '' : '${rows.first['eventDate'] ?? ''}'.trim(),
      };
    } catch (_) {
      return <String, Object>{
        'count': 0,
        'latestDate': '',
      };
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final Database db = await _db();

      if (!await _tableExists(db, 'enrollment')) {
        if (!mounted) return;
        setState(() {
          _items = <_MonitoringHousehold>[];
          _filtered = <_MonitoringHousehold>[];
          _loading = false;
        });
        return;
      }

      final List<Map<String, Object?>> rows = await db.query(
        'enrollment',
        where: 'program = ?',
        whereArgs: <Object?>[
          MgysdDhis2Uids.enrolledHouseholdsProgram,
        ],
        orderBy: 'enrollmentDate DESC',
      );

      final Map<String, Map<String, Object?>> latest =
          <String, Map<String, Object?>>{};

      for (final Map<String, Object?> row in rows) {
        final String householdTei =
            '${row['trackedEntityInstance'] ?? ''}'.trim();
        if (householdTei.isEmpty) continue;
        latest.putIfAbsent(householdTei, () => row);
      }

      final List<_MonitoringHousehold> result = <_MonitoringHousehold>[];

      for (final MapEntry<String, Map<String, Object?>> entry
          in latest.entries) {
        final String householdTei = entry.key;
        final Map<String, Object?> enrollment = entry.value;

        final Map<String, String> householdAttributes =
            await _attributes(db, householdTei);

        final String? primaryClientTei =
            await _primaryClientTei(db, householdTei);

        final Map<String, String> clientAttributes =
            primaryClientTei == null
                ? <String, String>{}
                : await _attributes(db, primaryClientTei);

        final Map<String, Object> summary =
            await _monitoringSummary(db, householdTei);

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

        result.add(
          _MonitoringHousehold(
            enrollmentId:
                '${enrollment['enrollment'] ?? enrollment['id'] ?? ''}',
            householdTei: householdTei,
            fileNumber:
                fileNumber.isEmpty ? householdTei : fileNumber,
            clientName: _displayName(
              clientAttributes,
              fallback: 'Household client',
            ),
            location: <String>[district, council, village]
                .where((String value) => value.trim().isNotEmpty)
                .join(' • '),
            enrollmentDate: '${enrollment['enrollmentDate'] ?? ''}',
            monitoringCount: summary['count'] as int,
            latestMonitoringDate:
                '${summary['latestDate'] ?? ''}'.trim(),
          ),
        );
      }

      result.sort((_MonitoringHousehold a, _MonitoringHousehold b) {
        if (a.hasMonitoring != b.hasMonitoring) {
          return a.hasMonitoring ? -1 : 1;
        }
        return b.enrollmentDate.compareTo(a.enrollmentDate);
      });

      if (!mounted) return;
      setState(() {
        _items = result;
        _loading = false;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load monitoring workspace: $error'),
        ),
      );
    }
  }

  void _applyFilters() {
    final String query = _searchController.text.trim().toLowerCase();

    final List<_MonitoringHousehold> filtered =
        _items.where((_MonitoringHousehold item) {
      if (_filter == 'MONITORED' && !item.hasMonitoring) return false;
      if (_filter == 'PENDING' && item.hasMonitoring) return false;

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
        'value': 'MONITORED',
        'label': 'Monitoring recorded',
      },
      <String, String>{
        'value': 'PENDING',
        'label': 'No monitoring recorded',
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
                    'Filter monitoring records',
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
                    'Find households with monitoring history or those still awaiting a follow-up.',
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
      case 'MONITORED':
        return 'Monitoring recorded';
      case 'PENDING':
        return 'No monitoring recorded';
      default:
        return 'All enrolled households';
    }
  }

  Future<void> _openMonitoring(
    _MonitoringHousehold household,
  ) async {
    try {
      final Database db = await _db();
      final String rootId = household.enrollmentId.trim().isNotEmpty
          ? household.enrollmentId.trim()
          : household.householdTei.trim();

      final String eventId =
          '${rootId}__monitoring__${DateTime.now().millisecondsSinceEpoch}';

      await MgysdProgramStageEventHelper.saveContext(
        db: db,
        eventId: eventId,
        parentCaseId: household.enrollmentId,
        stageKey: 'monitoring',
        tableName: 'mgysd_monitoring',
        programStage: MgysdDhis2Uids.monitoringStage,
        trackedEntityInstance: household.householdTei,
        enrollment: household.enrollmentId,
        householdTei: household.householdTei,
        householdName: household.fileNumber,
        clientName: household.clientName,
        subjectName: household.clientName,
        subjectRole: 'HOUSEHOLD',
      );

      final MgysdCase monitoringCase = MgysdCase(
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
          builder: (_) => MgysdMonitoringPage(
            color: widget.color,
            mgysdCase: monitoringCase,
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
          content: Text('Could not open monitoring form: $error'),
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

  Widget _householdCard(_MonitoringHousehold household) {
    final Color statusColor =
        household.hasMonitoring ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 23,
            backgroundColor: statusColor.withOpacity(0.11),
            child: Icon(
              Icons.monitor_heart_outlined,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  household.clientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
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
                      household.hasMonitoring
                          ? '${household.monitoringCount} monitoring record${household.monitoringCount == 1 ? '' : 's'}'
                          : 'Monitoring pending',
                      statusColor,
                    ),
                    if (household.latestMonitoringDate.isNotEmpty)
                      _pill(
                        'Latest ${household.latestMonitoringDate}',
                        widget.color,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _openMonitoring(household),
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
                fontSize: 11.8,
              ),
            ),
            child: const Text('Monitoring'),
          ),
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
          children: <Widget>[
            CircleAvatar(
              radius: 34,
              backgroundColor: widget.color.withOpacity(0.09),
              child: Icon(
                Icons.monitor_heart_outlined,
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
              'Households appear here after enrollment. Monitoring is recorded once for the household, not separately for each member.',
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
    final int monitored =
        _items.where((_MonitoringHousehold item) => item.hasMonitoring).length;

    final int totalMonitoringRecords = _items.fold<int>(
      0,
      (int total, _MonitoringHousehold item) =>
          total + item.monitoringCount,
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
                    Icons.monitor_heart_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Monitoring',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalMonitoringRecords records • $monitored/${_items.length} households monitored',
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
                                  'Offline search: searches households stored on this device',
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
