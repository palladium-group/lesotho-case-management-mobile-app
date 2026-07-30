import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/pages/mgysd_repeatable_stage_list_page.dart';
import 'package:sqflite/sqflite.dart';

class MgysdClosureWorkspace extends StatefulWidget {
  const MgysdClosureWorkspace({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdClosureWorkspace> createState() =>
      _MgysdClosureWorkspaceState();
}

class _ClosureHousehold {
  const _ClosureHousehold({
    required this.enrollmentId,
    required this.householdTei,
    required this.fileNumber,
    required this.clientName,
    required this.location,
    required this.enrollmentDate,
    required this.closureCount,
  });

  final String enrollmentId;
  final String householdTei;
  final String fileNumber;
  final String clientName;
  final String location;
  final String enrollmentDate;
  final int closureCount;

  String get searchableText =>
      '$fileNumber $clientName $location'.toLowerCase();
}

class _MgysdClosureWorkspaceState extends State<MgysdClosureWorkspace> {
  final TextEditingController _searchController = TextEditingController();

  List<_ClosureHousehold> _items = [];
  List<_ClosureHousehold> _filtered = [];
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

  Future<Map<String, String>> _attributes(Database db, String tei) async {
    final result = <String, String>{};
    if (!await _tableExists(db, 'tracked_entity_instance_attribute')) {
      return result;
    }
    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        where: 'trackedEntityInstance = ?',
        whereArgs: [tei],
      );
      for (final row in rows) {
        result['${row['attribute'] ?? ''}'] = '${row['value'] ?? ''}';
      }
    } catch (_) {}
    return result;
  }

  String _first(Map<String, String> values, List<String> keys) {
    for (final key in keys) {
      final value = (values[key] ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _name(Map<String, String> attrs) {
    final first =
        _first(attrs, [MgysdDhis2Uids.attFirstName, 'ATTR_P_FIRSTNAME']);
    final last =
        _first(attrs, [MgysdDhis2Uids.attLastName, 'ATTR_P_LASTNAME']);
    final result = '$first $last'.trim();
    return result.isEmpty ? 'Household client' : result;
  }

  Future<String?> _primaryClientTei(Database db, String householdTei) async {
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
      return '${rows.first['memberTei'] ?? ''}';
    } catch (_) {
      return null;
    }
  }

  Future<int> _closureCount(Database db, String householdTei) async {
    if (!await _tableExists(db, 'events')) return 0;
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM events '
        'WHERE trackedEntityInstance = ? AND programStage = ?',
        [householdTei, MgysdDhis2Uids.enrolledCaseClosureStage],
      );
      return int.tryParse('${rows.first['c'] ?? 0}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await _db();
      final rows = await db.query(
        'enrollment',
        where: 'program = ?',
        whereArgs: [MgysdDhis2Uids.enrolledHouseholdsProgram],
        orderBy: 'enrollmentDate DESC',
      );

      final unique = <String, Map<String, Object?>>{};
      for (final row in rows) {
        final tei = '${row['trackedEntityInstance'] ?? ''}'.trim();
        if (tei.isNotEmpty) unique.putIfAbsent(tei, () => row);
      }

      final result = <_ClosureHousehold>[];
      for (final entry in unique.entries) {
        final hhTei = entry.key;
        final enrollment = entry.value;
        final hhAttrs = await _attributes(db, hhTei);
        final primary = await _primaryClientTei(db, hhTei);
        final clientAttrs =
            primary == null ? <String, String>{} : await _attributes(db, primary);

        final file = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdFileNumber,
          'ATTR_HH_FILE_NUMBER',
        ]);
        final district = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdDistrict,
          'district',
        ]);
        final council = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdCommunityCouncil,
          'communityCouncil',
        ]);
        final village = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdVillage,
          'village',
        ]);

        result.add(
          _ClosureHousehold(
            enrollmentId:
                '${enrollment['enrollment'] ?? enrollment['id'] ?? ''}',
            householdTei: hhTei,
            fileNumber: file.isEmpty ? hhTei : file,
            clientName: _name(clientAttrs),
            location: [district, council, village]
                .where((value) => value.isNotEmpty)
                .join(' • '),
            enrollmentDate: '${enrollment['enrollmentDate'] ?? ''}',
            closureCount: await _closureCount(db, hhTei),
          ),
        );
      }

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
        SnackBar(content: Text('Could not load closure workspace: $error')),
      );
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _items.where((item) {
        if (_filter == 'CLOSED' && item.closureCount == 0) return false;
        if (_filter == 'OPEN' && item.closureCount > 0) return false;
        return query.isEmpty || item.searchableText.contains(query);
      }).toList();
    });
  }

  Future<void> _openClosures(_ClosureHousehold household) async {
    final parent = MgysdCase(
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
        builder: (_) => MgysdRepeatableStageListPage(
          color: widget.color,
          parentCase: parent,
          stageTitle: 'Case Closure',
          tableName: 'mgysd_case_closure',
          stageKey: 'case_closure',
          programStage: MgysdDhis2Uids.enrolledCaseClosureStage,
          icon: Icons.task_alt_outlined,
          trackedEntityInstance: household.householdTei,
          enrollment: household.enrollmentId,
          householdTei: household.householdTei,
          householdName: household.fileNumber,
          clientName: household.clientName,
          subjectName: household.clientName,
          subjectRole: 'HOUSEHOLD',
        ),
      ),
    );
    await _load();
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'ALL',
              groupValue: _filter,
              title: const Text('All enrolled households'),
              onChanged: (value) {
                Navigator.pop(sheetContext);
                _filter = value!;
                _applyFilters();
              },
            ),
            RadioListTile<String>(
              value: 'OPEN',
              groupValue: _filter,
              title: const Text('No closure recorded'),
              onChanged: (value) {
                Navigator.pop(sheetContext);
                _filter = value!;
                _applyFilters();
              },
            ),
            RadioListTile<String>(
              value: 'CLOSED',
              groupValue: _filter,
              title: const Text('Closure recorded'),
              onChanged: (value) {
                Navigator.pop(sheetContext);
                _filter = value!;
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(_ClosureHousehold household) {
    final hasClosure = household.closureCount > 0;
    final color = hasClosure ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.10),
            child: Icon(Icons.task_alt_outlined, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  household.clientName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'File ${household.fileNumber}'
                  '${household.location.isEmpty ? '' : ' • ${household.location}'}',
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 11.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasClosure
                      ? '${household.closureCount} closure record'
                      : 'Closure not recorded',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openClosures(household),
            child: const Text(
              'Closure',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: const Row(
                children: [
                  Icon(Icons.task_alt_outlined,
                      color: Colors.white, size: 30),
                  SizedBox(width: 12),
                  Text(
                    'Case Closure',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
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
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(15),
                          child:
                              Icon(Icons.circle, size: 12, color: widget.color),
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? const Icon(Icons.public_outlined,
                                color: Colors.blueGrey)
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
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
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: IconButton(
                      onPressed: _openFilterSheet,
                      icon: Icon(
                        Icons.tune_outlined,
                        color:
                            _filter == 'ALL' ? Colors.blueGrey : widget.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No closure households found')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => _card(_filtered[index]),
                childCount: _filtered.length,
              ),
            ),
        ],
      ),
    );
  }
}
