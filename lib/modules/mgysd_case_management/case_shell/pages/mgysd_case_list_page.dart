import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/mgysd_case_management_list_state/mgysd_case_management_list_state.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/case_shell/pages/mgysd_case_detail_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

class MgysdCaseListPage extends StatefulWidget {
  const MgysdCaseListPage({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdCaseListPage> createState() => _MgysdCaseListPageState();
}

class _CaseListItem {
  const _CaseListItem({
    required this.caseRecord,
    required this.householdTei,
    required this.clientName,
    required this.clientMeta,
    required this.location,
    required this.district,
    required this.programStatus,
    required this.enrollmentDate,
    required this.memberCount,
    required this.openGoals,
    required this.serviceCount,
    required this.monitoringCount,
    required this.investigationCount,
    required this.carePlanCount,
    required this.activeCarePlanCount,
  });

  final MgysdCase caseRecord;
  final String householdTei;
  final String clientName;
  final String clientMeta;
  final String location;
  final String district;
  final String programStatus;
  final String enrollmentDate;
  final int memberCount;
  final int openGoals;
  final int serviceCount;
  final int monitoringCount;
  final int investigationCount;
  final int carePlanCount;
  final int activeCarePlanCount;

  bool get isEnrolled => programStatus.toUpperCase() == 'ENROLLED';
  bool get isAssessed => programStatus.toUpperCase() == 'ASSESSED';
  bool get hasPhone => (caseRecord.phone ?? '').trim().isNotEmpty;

  bool get needsAction {
    if (isAssessed) return true;
    if (isEnrolled && investigationCount == 0) return true;
    if (isEnrolled && activeCarePlanCount == 0) return true;
    if (isEnrolled && openGoals > 0 && serviceCount == 0) return true;
    if (isEnrolled && serviceCount > 0 && monitoringCount == 0) return true;
    return false;
  }

  bool get monitoringDue {
    return isEnrolled &&
        activeCarePlanCount > 0 &&
        serviceCount > 0 &&
        monitoringCount == 0;
  }

  String get decisionTitle {
    if (isAssessed) return 'Review risk and decide enrolment';
    if (investigationCount == 0) return 'Start Social Investigation';
    if (activeCarePlanCount == 0) return 'Open investigation and check Care Plan';
    if (openGoals > 0 && serviceCount == 0) {
      return 'Provide services against open goals';
    }
    if (monitoringDue) return 'Monitoring visit is due';
    if (openGoals == 0 && activeCarePlanCount > 0) {
      return 'Consider case review or closure';
    }
    return 'Continue routine support';
  }

  String get decisionSubtitle {
    if (isAssessed) {
      return 'This household has been assessed but is not yet in active intervention.';
    }
    if (investigationCount == 0) {
      return 'No investigation has been recorded. Start here before planning services.';
    }
    if (activeCarePlanCount == 0) {
      return 'There is no active support cycle visible for this household.';
    }
    if (openGoals > 0 && serviceCount == 0) {
      return 'Care Plan goals exist but no services have been recorded yet.';
    }
    if (monitoringDue) {
      return 'Services exist, but progress has not yet been monitored.';
    }
    if (openGoals == 0 && activeCarePlanCount > 0) {
      return 'No outstanding goals are visible in the current support cycle.';
    }
    return 'Household has active case-management records.';
  }

  int get actionScore {
    if (isEnrolled && investigationCount == 0) return 100;
    if (isEnrolled && activeCarePlanCount == 0) return 90;
    if (monitoringDue) return 80;
    if (isEnrolled && openGoals > 0 && serviceCount == 0) return 70;
    if (isAssessed) return 60;
    return 10;
  }

  String get searchableText {
    return [
      caseRecord.caseNo,
      clientName,
      clientMeta,
      location,
      district,
      programStatus,
      caseRecord.phone ?? '',
      enrollmentDate,
      decisionTitle,
    ].join(' ').toLowerCase();
  }
}

class _MgysdCaseListPageState extends State<MgysdCaseListPage> {
  final TextEditingController _searchController = TextEditingController();

  List<_CaseListItem> _cases = [];
  List<_CaseListItem> _filtered = [];
  bool _loading = true;

  String _statusFilter = 'ALL';
  String _actionFilter = 'ALL';
  String _districtFilter = 'ALL';
  String _sortMode = 'PRIORITY';
  bool _filtersExpanded = false;

  static const String assessedHouseholdsProgramId =
      MgysdDhis2Uids.assessedHouseholdsProgram;
  static const String enrolledHouseholdsProgramId =
      MgysdDhis2Uids.enrolledHouseholdsProgram;

  static const String attFirstName = MgysdDhis2Uids.attFirstName;
  static const String attLastName = MgysdDhis2Uids.attLastName;
  static const String attPhone = MgysdDhis2Uids.attPhone;
  static const String attClientCategory = MgysdDhis2Uids.attClientCategory;
  static const String attSex = MgysdDhis2Uids.attSex;
  static const String attAge = MgysdDhis2Uids.attAge;

  static const String attHouseholdFileNumber =
      MgysdDhis2Uids.attHouseholdFileNumber;
  static const String attHouseholdDistrict =
      MgysdDhis2Uids.attHouseholdDistrict;
  static const String attHouseholdCommunityCouncil =
      MgysdDhis2Uids.attHouseholdCommunityCouncil;
  static const String attHouseholdVillage =
      MgysdDhis2Uids.attHouseholdVillage;

  static const String legacyAttPersonFirstName = 'ATTR_P_FIRSTNAME';
  static const String legacyAttPersonLastName = 'ATTR_P_LASTNAME';
  static const String legacyAttPersonPhone = 'ATTR_P_PHONE';

  @override
  void initState() {
    super.initState();
    _loadHouseholdCases();

    Future.microtask(() {
      Provider.of<MgysdCaseManagementListState>(context, listen: false)
          .refreshMgysdCasesNumber();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _columnExists(
      Database db,
      String tableName,
      String columnName,
      ) async {
    try {
      if (!await _tableExists(db, tableName)) return false;
      final rows = await db.rawQuery('PRAGMA table_info($tableName)');
      return rows.any((row) => (row['name'] ?? '').toString() == columnName);
    } catch (_) {
      return false;
    }
  }

  Future<int> _countRows(
      Database db,
      String tableName,
      String where,
      List<Object?> whereArgs,
      ) async {
    try {
      if (!await _tableExists(db, tableName)) return 0;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $tableName WHERE $where',
        whereArgs,
      );
      if (rows.isEmpty) return 0;
      return int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, String>> _loadTeiAttributes(
      Database db,
      String teiId,
      ) async {
    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        columns: ['attribute', 'value'],
        where: 'trackedEntityInstance = ?',
        whereArgs: [teiId],
      );

      final Map<String, String> map = {};
      for (final row in rows) {
        final att = (row['attribute'] ?? '').toString();
        final val = (row['value'] ?? '').toString();
        if (att.isNotEmpty) map[att] = val;
      }

      return map;
    } catch (_) {
      return <String, String>{};
    }
  }

  String _readFirstName(Map<String, String> attrs) {
    return attrs[attFirstName] ?? attrs[legacyAttPersonFirstName] ?? '';
  }

  String _readLastName(Map<String, String> attrs) {
    return attrs[attLastName] ?? attrs[legacyAttPersonLastName] ?? '';
  }

  String _readPhone(Map<String, String> attrs) {
    return attrs[attPhone] ?? attrs[legacyAttPersonPhone] ?? '';
  }

  String _prettyClientCategory(String value) {
    switch (value.toUpperCase()) {
      case 'CHILD':
        return 'Child';
      case 'Adult':
        return 'Adult';
      case 'ADULT':
        return 'Adult';
      default:
        return value;
    }
  }

  Future<String?> _getPrimaryClientForHousehold(
      Database db,
      String householdTei,
      ) async {
    try {
      final primaryRows = await db.query(
        'mgysd_household_member',
        columns: ['memberTei'],
        where: 'householdTei = ? AND isPrimaryClient = ?',
        whereArgs: [householdTei, 'true'],
        limit: 1,
      );

      if (primaryRows.isNotEmpty) {
        final tei = (primaryRows.first['memberTei'] ?? '').toString().trim();
        if (tei.isNotEmpty) return tei;
      }

      final fallbackRows = await db.query(
        'mgysd_household_member',
        columns: ['memberTei'],
        where: 'householdTei = ? AND memberRole = ?',
        whereArgs: [householdTei, 'CLIENT'],
        limit: 1,
      );

      if (fallbackRows.isNotEmpty) {
        final tei = (fallbackRows.first['memberTei'] ?? '').toString().trim();
        if (tei.isNotEmpty) return tei;
      }
    } catch (_) {}

    return null;
  }

  Future<List<Map<String, Object?>>> _loadHouseholdEnrollmentRows(
      Database db,
      ) async {
    try {
      final rows = await db.query(
        'enrollment',
        where: 'program IN (?, ?)',
        whereArgs: [
          assessedHouseholdsProgramId,
          enrolledHouseholdsProgramId,
        ],
        orderBy: 'enrollmentDate DESC',
      );

      return rows;
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }

  Future<int> _countActiveCarePlans(Database db, String householdTei) async {
    if (householdTei.trim().isEmpty) return 0;

    try {
      if (!await _tableExists(db, 'mgysd_care_plan')) return 0;

      final hasCarePlanStatus =
      await _columnExists(db, 'mgysd_care_plan', 'carePlanStatus');
      final hasPlanStatus =
      await _columnExists(db, 'mgysd_care_plan', 'planStatus');
      final hasStatus = await _columnExists(db, 'mgysd_care_plan', 'status');

      final statusExpression = hasCarePlanStatus
          ? 'carePlanStatus'
          : hasPlanStatus
          ? 'planStatus'
          : hasStatus
          ? 'status'
          : "''";

      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c
        FROM mgysd_care_plan
        WHERE householdTei = ?
        AND UPPER(COALESCE($statusExpression, 'ACTIVE')) = 'ACTIVE'
      ''', [householdTei]);

      if (rows.isEmpty) return 0;
      return int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countOpenGoals(Database db, String householdTei) async {
    if (householdTei.trim().isEmpty) return 0;

    try {
      if (!await _tableExists(db, 'mgysd_care_plan_goal')) return 0;

      final hasHouseholdTei =
      await _columnExists(db, 'mgysd_care_plan_goal', 'householdTei');
      final hasGoalStatus =
      await _columnExists(db, 'mgysd_care_plan_goal', 'goalStatus');

      if (!hasHouseholdTei) return 0;

      final statusExpression = hasGoalStatus ? 'goalStatus' : "'open'";

      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c
        FROM mgysd_care_plan_goal
        WHERE householdTei = ?
        AND LOWER(COALESCE($statusExpression, 'open')) NOT IN ('achieved', 'closed', 'completed')
      ''', [householdTei]);

      if (rows.isEmpty) return 0;
      return int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadHouseholdCases() async {
    setState(() => _loading = true);

    try {
      final db = await _db();
      final enrollmentRows = await _loadHouseholdEnrollmentRows(db);

      final Map<String, Map<String, Object?>> byHousehold = {};

      for (final row in enrollmentRows) {
        final householdTei =
        (row['trackedEntityInstance'] ?? '').toString().trim();
        if (householdTei.isEmpty) continue;

        final program = (row['program'] ?? '').toString().trim();

        final existing = byHousehold[householdTei];
        if (existing == null) {
          byHousehold[householdTei] = row;
        } else {
          final existingProgram = (existing['program'] ?? '').toString().trim();

          if (existingProgram != enrolledHouseholdsProgramId &&
              program == enrolledHouseholdsProgramId) {
            byHousehold[householdTei] = row;
          }
        }
      }

      final List<_CaseListItem> list = [];

      for (final entry in byHousehold.entries) {
        final householdTei = entry.key;
        final row = entry.value;

        final enrollmentId = (row['enrollment'] ?? '').toString().trim();
        final program = (row['program'] ?? '').toString().trim();
        final enrollmentDate = (row['enrollmentDate'] ?? '').toString().trim();

        if (enrollmentId.isEmpty) continue;

        final householdAttrs = await _loadTeiAttributes(db, householdTei);

        final fileNumber =
        (householdAttrs[attHouseholdFileNumber] ?? '').trim();
        final district = (householdAttrs[attHouseholdDistrict] ?? '').trim();
        final communityCouncil =
        (householdAttrs[attHouseholdCommunityCouncil] ?? '').trim();
        final village = (householdAttrs[attHouseholdVillage] ?? '').trim();

        final clientTei = await _getPrimaryClientForHousehold(db, householdTei);
        String fullName = '(No primary client)';
        String phone = '';
        String extra = '';

        if (clientTei != null && clientTei.isNotEmpty) {
          final clientAttrs = await _loadTeiAttributes(db, clientTei);
          final firstName = _readFirstName(clientAttrs).trim();
          final lastName = _readLastName(clientAttrs).trim();
          phone = _readPhone(clientAttrs).trim();

          final category = _prettyClientCategory(
            (clientAttrs[attClientCategory] ?? '').trim(),
          );
          final sex = (clientAttrs[attSex] ?? '').trim();
          final age = (clientAttrs[attAge] ?? '').trim();

          fullName = ('$firstName $lastName').trim();
          if (fullName.isEmpty) fullName = '(No primary client)';

          extra = [
            if (category.isNotEmpty) category,
            if (sex.isNotEmpty) sex,
            if (age.isNotEmpty) '$age yrs',
          ].join(' • ');
        }

        final displayCaseNo = fileNumber.isNotEmpty ? fileNumber : enrollmentId;

        final status =
        program == enrolledHouseholdsProgramId ? 'ENROLLED' : 'ASSESSED';

        final location = [
          district,
          communityCouncil,
          village,
        ].where((value) => value.trim().isNotEmpty).join(' • ');

        final caseRecord = MgysdCase(
          id: enrollmentId,
          caseNo: displayCaseNo,
          fullName: extra.isEmpty ? fullName : '$fullName\n$extra',
          district: location,
          status: status,
          phone: phone,
          enrollmentDate: enrollmentDate,
        );

        final memberCount = await _countRows(
          db,
          'mgysd_household_member',
          'householdTei = ?',
          [householdTei],
        );

        final investigationCount = await _countRows(
          db,
          'mgysd_social_investigation',
          'householdTei = ?',
          [householdTei],
        );

        final carePlanCount = await _countRows(
          db,
          'mgysd_care_plan',
          'householdTei = ?',
          [householdTei],
        );

        final activeCarePlanCount =
        await _countActiveCarePlans(db, householdTei);

        final serviceCount = await _countRows(
          db,
          'mgysd_service_provision',
          'householdTei = ?',
          [householdTei],
        );

        final monitoringCount = await _countRows(
          db,
          'mgysd_monitoring',
          'householdTei = ?',
          [householdTei],
        );

        final openGoals = await _countOpenGoals(db, householdTei);

        list.add(
          _CaseListItem(
            caseRecord: caseRecord,
            householdTei: householdTei,
            clientName: fullName,
            clientMeta: extra,
            location: location,
            district: district,
            programStatus: status,
            enrollmentDate: enrollmentDate,
            memberCount: memberCount,
            openGoals: openGoals,
            serviceCount: serviceCount,
            monitoringCount: monitoringCount,
            investigationCount: investigationCount,
            carePlanCount: carePlanCount,
            activeCarePlanCount: activeCarePlanCount,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _cases = list;
        _filtered = _applyFilters(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cases = [];
        _filtered = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load household cases: $e')),
      );
    }
  }

  List<_CaseListItem> _applyFilters(List<_CaseListItem> source) {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = source.where((item) {
      final matchesSearch = query.isEmpty || item.searchableText.contains(query);

      final matchesStatus = _statusFilter == 'ALL' ||
          item.programStatus.toUpperCase() == _statusFilter;

      final matchesDistrict = _districtFilter == 'ALL' ||
          item.district.toLowerCase() == _districtFilter.toLowerCase();

      bool matchesAction = true;
      switch (_actionFilter) {
        case 'NEEDS_ACTION':
          matchesAction = item.needsAction;
          break;
        case 'MONITORING_DUE':
          matchesAction = item.monitoringDue;
          break;
        case 'OPEN_GOALS':
          matchesAction = item.openGoals > 0;
          break;
        case 'NO_PHONE':
          matchesAction = !item.hasPhone;
          break;
        default:
          matchesAction = true;
      }

      return matchesSearch && matchesStatus && matchesDistrict && matchesAction;
    }).toList();

    switch (_sortMode) {
      case 'NEWEST':
        filtered.sort((a, b) => b.enrollmentDate.compareTo(a.enrollmentDate));
        break;
      case 'OLDEST':
        filtered.sort((a, b) => a.enrollmentDate.compareTo(b.enrollmentDate));
        break;
      case 'NAME':
        filtered.sort(
              (a, b) => a.clientName.toLowerCase().compareTo(
            b.clientName.toLowerCase(),
          ),
        );
        break;
      case 'PRIORITY':
      default:
        filtered.sort((a, b) {
          final scoreCompare = b.actionScore.compareTo(a.actionScore);
          if (scoreCompare != 0) return scoreCompare;
          return b.enrollmentDate.compareTo(a.enrollmentDate);
        });
        break;
    }

    return filtered;
  }

  void _reapplyFilters() {
    setState(() {
      _filtered = _applyFilters(_cases);
    });
  }

  Future<void> _refresh() async {
    await _loadHouseholdCases();
    if (!mounted) return;
    Provider.of<MgysdCaseManagementListState>(context, listen: false)
        .refreshMgysdCasesNumber();
  }

  void _openCase(_CaseListItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdCaseDetailPage(
          color: widget.color,
          mgysdCase: item.caseRecord,
        ),
      ),
    ).then((_) => _refresh());
  }

  void _onAddCase() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use "Report Case" or "Enroll Client Case" workflow'),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ENROLLED':
        return 'Enrolled HH';
      case 'ASSESSED':
        return 'Assessed HH';
      case 'ACTIVE':
        return 'Open';
      case 'COMPLETED':
        return 'Closed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ENROLLED':
        return Colors.green;
      case 'ASSESSED':
        return Colors.deepOrange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.redAccent;
      default:
        return widget.color;
    }
  }

  Color _decisionColor(_CaseListItem item) {
    if (item.investigationCount == 0 && item.isEnrolled) return Colors.redAccent;
    if (item.activeCarePlanCount == 0 && item.isEnrolled) {
      return Colors.deepPurple;
    }
    if (item.monitoringDue) return Colors.amber.shade800;
    if (item.openGoals > 0 && item.serviceCount == 0) return Colors.indigo;
    if (item.isAssessed) return Colors.deepOrange;
    return Colors.green;
  }

  Widget _chip(
      String label, {
        Color? color,
        IconData? icon,
        bool strong = false,
      }) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    final c = color ?? Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(strong ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(strong ? 0.25 : 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return _chip(
      _statusLabel(status),
      color: _statusColor(status),
      strong: true,
    );
  }

  Widget _buildSearchBox() {
    final total = _cases.length;
    final shown = _filtered.length;
    final countText = _loading
        ? 'Loading cases...'
        : shown == total
        ? '$total case${total == 1 ? '' : 's'} available'
        : 'Showing $shown of $total case${total == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _reapplyFilters(),
            style: const TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.search_rounded, color: widget.color),
              suffixIcon: _searchController.text.trim().isNotEmpty
                  ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  _reapplyFilters();
                },
                icon: const Icon(Icons.close_rounded),
              )
                  : null,
              hintText: 'Search cases',
              hintStyle: const TextStyle(
                color: Color(0xFF697386),
                fontWeight: FontWeight.w600,
              ),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: widget.color, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              countText,
              style: const TextStyle(
                color: Color(0xFF5B6678),
                fontSize: 12.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDE5EF)),
        ),
        child: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Color(0xFF172033),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5F6F86),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _availableDistricts() {
    final districts = _cases
        .map((item) => item.district.trim())
        .where((district) => district.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return districts;
  }

  Widget _filterButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      selectedColor: widget.color.withOpacity(0.14),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? widget.color : Colors.black87,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
        fontSize: 12.5,
      ),
      side: BorderSide(
        color: selected
            ? widget.color.withOpacity(0.35)
            : Colors.blueGrey.withOpacity(0.14),
      ),
      onSelected: (_) => onTap(),
    );
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _statusFilter != 'ALL' ||
        _actionFilter != 'ALL' ||
        _districtFilter != 'ALL' ||
        _sortMode != 'PRIORITY';
  }

  int get _activeFilterCount {
    int count = 0;
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_statusFilter != 'ALL') count++;
    if (_actionFilter != 'ALL') count++;
    if (_districtFilter != 'ALL') count++;
    if (_sortMode != 'PRIORITY') count++;
    return count;
  }

  String _activeFilterSummary() {
    final parts = <String>[];

    if (_statusFilter != 'ALL') {
      parts.add(_statusFilter == 'ENROLLED' ? 'Enrolled' : 'Assessed only');
    }

    switch (_actionFilter) {
      case 'NEEDS_ACTION':
        parts.add('Needs action');
        break;
      case 'MONITORING_DUE':
        parts.add('Monitoring due');
        break;
      case 'OPEN_GOALS':
        parts.add('Open goals');
        break;
      case 'NO_PHONE':
        parts.add('No phone');
        break;
    }

    if (_districtFilter != 'ALL') parts.add(_districtFilter);

    switch (_sortMode) {
      case 'NEWEST':
        parts.add('Newest first');
        break;
      case 'OLDEST':
        parts.add('Oldest first');
        break;
      case 'NAME':
        parts.add('Name order');
        break;
    }

    if (parts.isEmpty) return 'Priority view';
    return parts.join(' • ');
  }

  void _clearFilters() {
    _searchController.clear();
    _statusFilter = 'ALL';
    _actionFilter = 'ALL';
    _districtFilter = 'ALL';
    _sortMode = 'PRIORITY';
    _reapplyFilters();
  }

  Widget _filterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final districts = _availableDistricts();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                _filtersExpanded = !_filtersExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_outlined,
                      color: widget.color,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Filters & sorting',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$_activeFilterCount',
                                  style: TextStyle(
                                    color: widget.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _activeFilterSummary(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear'),
                    ),
                  Icon(
                    _filtersExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _filtersExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _filterSectionTitle('Household status'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterButton(
                          label: 'All',
                          selected: _statusFilter == 'ALL',
                          onTap: () {
                            _statusFilter = 'ALL';
                            _reapplyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        _filterButton(
                          label: 'Enrolled',
                          selected: _statusFilter == 'ENROLLED',
                          onTap: () {
                            _statusFilter = 'ENROLLED';
                            _reapplyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        _filterButton(
                          label: 'Assessed only',
                          selected: _statusFilter == 'ASSESSED',
                          onTap: () {
                            _statusFilter = 'ASSESSED';
                            _reapplyFilters();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _filterSectionTitle('Decision support'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterButton(
                          label: 'All actions',
                          selected: _actionFilter == 'ALL',
                          onTap: () {
                            _actionFilter = 'ALL';
                            _reapplyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        _filterButton(
                          label: 'Needs action',
                          selected: _actionFilter == 'NEEDS_ACTION',
                          onTap: () {
                            _actionFilter = 'NEEDS_ACTION';
                            _reapplyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        _filterButton(
                          label: 'Monitoring due',
                          selected: _actionFilter == 'MONITORING_DUE',
                          onTap: () {
                            _actionFilter = 'MONITORING_DUE';
                            _reapplyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        _filterButton(
                          label: 'Open goals',
                          selected: _actionFilter == 'OPEN_GOALS',
                          onTap: () {
                            _actionFilter = 'OPEN_GOALS';
                            _reapplyFilters();
                          },
                        ),
                        const SizedBox(width: 8),
                        _filterButton(
                          label: 'No phone',
                          selected: _actionFilter == 'NO_PHONE',
                          onTap: () {
                            _actionFilter = 'NO_PHONE';
                            _reapplyFilters();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filterSectionTitle('District'),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F9FC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.blueGrey.withOpacity(0.14),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _districtFilter,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'ALL',
                                      child: Text('All districts'),
                                    ),
                                    ...districts.map(
                                          (district) => DropdownMenuItem(
                                        value: district,
                                        child: Text(
                                          district,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    _districtFilter = value;
                                    _reapplyFilters();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filterSectionTitle('Sort by'),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F9FC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.blueGrey.withOpacity(0.14),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sortMode,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'PRIORITY',
                                      child: Text('Priority'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'NEWEST',
                                      child: Text('Newest'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'OLDEST',
                                      child: Text('Oldest'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'NAME',
                                      child: Text('Name'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    _sortMode = value;
                                    _reapplyFilters();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Loading households...',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _searchController.text.trim().isNotEmpty ||
        _statusFilter != 'ALL' ||
        _actionFilter != 'ALL' ||
        _districtFilter != 'ALL';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        CircleAvatar(
          radius: 36,
          backgroundColor: widget.color.withOpacity(0.10),
          child: Icon(
            hasFilters ? Icons.filter_alt_off_outlined : Icons.home_work_outlined,
            size: 34,
            color: widget.color,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            hasFilters
                ? 'No households match your filters'
                : 'No assessed households found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            hasFilters
                ? 'Try clearing search or changing the decision-support filters.'
                : 'Create an Intake and Initial Risk Assessment to register a household.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.blueGrey,
              height: 1.4,
            ),
          ),
        ),
        if (hasFilters) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                _statusFilter = 'ALL';
                _actionFilter = 'ALL';
                _districtFilter = 'ALL';
                _sortMode = 'PRIORITY';
                _reapplyFilters();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Clear filters'),
            ),
          ),
        ],
      ],
    );
  }

  String _actionLabel(_CaseListItem item) {
    if (item.isAssessed) return 'Review risk';
    if (item.investigationCount == 0) return 'Start investigation';
    if (item.activeCarePlanCount == 0) return 'Create care plan';
    if (item.openGoals > 0 && item.serviceCount == 0) return 'Provide service';
    if (item.monitoringDue) return 'Monitor progress';
    if (item.openGoals == 0 && item.activeCarePlanCount > 0) return 'Review for closure';
    return 'Routine support';
  }

  IconData _actionIcon(_CaseListItem item) {
    if (item.isAssessed) return Icons.fact_check_outlined;
    if (item.investigationCount == 0) return Icons.search_rounded;
    if (item.activeCarePlanCount == 0) return Icons.assignment_outlined;
    if (item.openGoals > 0 && item.serviceCount == 0) {
      return Icons.volunteer_activism_outlined;
    }
    if (item.monitoringDue) return Icons.monitor_heart_outlined;
    return Icons.check_circle_outline_rounded;
  }

  Widget _buildActionPill(_CaseListItem item) {
    final color = _decisionColor(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_actionIcon(item), size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _actionLabel(item),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12.4,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE4EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF516176)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2E3A4D),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _cardActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool filled = false,
  }) {
    final ButtonStyle style = filled
        ? ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    )
        : OutlinedButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: const Color(0xFFD8E1EC)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.7,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    return filled
        ? ElevatedButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }

  Widget _buildCaseCard(_CaseListItem item) {
    final record = item.caseRecord;
    final nameParts = record.fullName.split('\n');
    final name = nameParts.isNotEmpty ? nameParts.first : record.fullName;
    final sub = nameParts.length > 1 ? nameParts.sublist(1).join(' • ') : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Material(
        color: Colors.white,
        elevation: 1.6,
        shadowColor: Colors.black.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        item.isEnrolled
                            ? Icons.family_restroom_outlined
                            : Icons.home_work_outlined,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF172033),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (sub.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.4,
                                color: Color(0xFF5F6F86),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Text(
                            record.caseNo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.3,
                              color: Color(0xFF6B788C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusChip(record.status),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            _cardActionPill(
                              icon: Icons.visibility_outlined,
                              label: 'View',
                              color: const Color(0xFF5F6F86),
                              onPressed: () => _openCase(item),
                            ),
                            _cardActionPill(
                              icon: Icons.folder_open_outlined,
                              label: 'Open',
                              color: widget.color,
                              filled: true,
                              onPressed: () => _openCase(item),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildActionPill(item),
                    if (record.district.trim().isNotEmpty)
                      _miniStat(record.district, Icons.place_outlined),
                    if ((record.phone ?? '').trim().isNotEmpty)
                      _miniStat(record.phone!.trim(), Icons.phone_outlined),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(child: _miniStat('${item.memberCount} members', Icons.groups_2_outlined)),
                    const SizedBox(width: 7),
                    Expanded(child: _miniStat('${item.openGoals} goals', Icons.track_changes_outlined)),
                    const SizedBox(width: 7),
                    Expanded(child: _miniStat('${item.monitoringCount} visits', Icons.monitor_heart_outlined)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FA),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.color,
        onPressed: _onAddCase,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            _buildSearchBox(),
            _buildFilters(),
            Expanded(
              child: _loading
                  ? _buildLoadingState()
                  : _filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 90, top: 2),
                itemCount: _filtered.length,
                itemBuilder: (_, index) {
                  return _buildCaseCard(_filtered[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}