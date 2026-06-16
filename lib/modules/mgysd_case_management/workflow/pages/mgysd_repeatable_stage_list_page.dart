import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/helpers/mgysd_program_stage_event_helper.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/care_plan/pages/mgysd_care_plan_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/monitoring/pages/mgysd_monitoring_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/referral/pages/mgysd_referral_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/service_provision/pages/mgysd_service_provision_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/social_investigation/pages/mgysd_social_investigation_page.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/case_closure/pages/mgysd_case_closure_page.dart';

class MgysdRepeatableStageListPage extends StatefulWidget {
  const MgysdRepeatableStageListPage({
    Key? key,
    required this.color,
    required this.parentCase,
    required this.stageTitle,
    required this.tableName,
    required this.stageKey,
    required this.icon,
    this.programStage,
    this.trackedEntityInstance,
    this.enrollment,
    this.householdTei,
    this.householdName,
    this.clientName,
    this.subjectName,
    this.subjectRole,
    this.memberTei,
    this.memberName,
    this.memberRole,
  }) : super(key: key);

  final Color color;
  final MgysdCase parentCase;
  final String stageTitle;
  final String tableName;
  final String stageKey;
  final IconData icon;

  /// DHIS2 program stage UID/code.
  final String? programStage;

  /// TEI that owns the event: household TEI for household stages, HH member TEI
  /// for family/member stages.
  final String? trackedEntityInstance;

  /// Kept for context even though the current offline `events` table does not
  /// have an enrollment column.
  final String? enrollment;

  final String? householdTei;
  final String? householdName;
  final String? clientName;
  final String? subjectName;
  final String? subjectRole;

  /// Optional explicit member context. Older callers may only pass
  /// trackedEntityInstance/subjectName/subjectRole, so this page safely falls
  /// back to those values.
  final String? memberTei;
  final String? memberName;
  final String? memberRole;

  @override
  State<MgysdRepeatableStageListPage> createState() =>
      _MgysdRepeatableStageListPageState();
}

class _StageRecord {
  final String id;
  final String status;
  final String date;
  final String summary;
  final bool fromEventsTable;
  final String carePlanId;
  final String carePlanStatus;

  const _StageRecord({
    required this.id,
    required this.status,
    required this.date,
    required this.summary,
    required this.fromEventsTable,
    this.carePlanId = '',
    this.carePlanStatus = '',
  });

  _StageRecord copyWith({
    String? carePlanId,
    String? carePlanStatus,
  }) {
    return _StageRecord(
      id: id,
      status: status,
      date: date,
      summary: summary,
      fromEventsTable: fromEventsTable,
      carePlanId: carePlanId ?? this.carePlanId,
      carePlanStatus: carePlanStatus ?? this.carePlanStatus,
    );
  }
}

class _MgysdRepeatableStageListPageState
    extends State<MgysdRepeatableStageListPage> {
  late Future<List<_StageRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRecords();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  String get _caseRootId {
    final parts = widget.parentCase.id.split('__');
    return parts.isNotEmpty ? parts.first : widget.parentCase.id;
  }

  String get _subjectTei => (widget.trackedEntityInstance ?? '').trim();
  String get _subjectEnrollment => (widget.enrollment ?? '').trim();
  String get _programStage => (widget.programStage ?? '').trim();

  String get _memberTei {
    final explicit = (widget.memberTei ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    return _subjectTei;
  }

  String get _memberName {
    final explicit = (widget.memberName ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final subject = (widget.subjectName ?? '').trim();
    if (subject.isNotEmpty) return subject;
    return (widget.clientName ?? '').trim();
  }

  String get _memberRole {
    final explicit = (widget.memberRole ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final subject = (widget.subjectRole ?? '').trim();
    if (subject.isNotEmpty) return subject;
    return 'Member';
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _nowIso() => DateTime.now().toIso8601String();

  String _newRecordId() {
    return '${_caseRootId}__${widget.stageKey}__${DateTime.now().millisecondsSinceEpoch}';
  }

  String _newUid() {
    try {
      return AppUtil.getUid();
    } catch (_) {
      return DateTime.now().microsecondsSinceEpoch.toString();
    }
  }

  String _dateOnly(String value) {
    final v = value.trim();
    if (v.length >= 10) return v.substring(0, 10);
    return v;
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
      final rows = await db.rawQuery('PRAGMA table_info($tableName)');
      return rows.any((row) => (row['name'] ?? '').toString() == columnName);
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureCarePlanColumns(Database db) async {
    if (!await _tableExists(db, 'mgysd_care_plan')) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mgysd_care_plan (
          id TEXT PRIMARY KEY,
          caseId TEXT,
          householdTei TEXT,
          socialInvestigationId TEXT,
          planDate TEXT,
          status TEXT,
          payloadJson TEXT,
          updatedAt TEXT,
          syncStatus TEXT
        )
      ''');
    }

    final migrations = <String, String>{
      'socialInvestigationId':
      "ALTER TABLE mgysd_care_plan ADD COLUMN socialInvestigationId TEXT DEFAULT ''",
      'carePlanId':
      "ALTER TABLE mgysd_care_plan ADD COLUMN carePlanId TEXT DEFAULT ''",
      'createdAt':
      "ALTER TABLE mgysd_care_plan ADD COLUMN createdAt TEXT DEFAULT ''",
      'planDate':
      "ALTER TABLE mgysd_care_plan ADD COLUMN planDate TEXT DEFAULT ''",
      'syncStatus':
      "ALTER TABLE mgysd_care_plan ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'",
      'carePlanStatus':
      "ALTER TABLE mgysd_care_plan ADD COLUMN carePlanStatus TEXT DEFAULT ''",
    };

    for (final entry in migrations.entries) {
      if (!await _columnExists(db, 'mgysd_care_plan', entry.key)) {
        try {
          await db.execute(entry.value);
        } catch (_) {}
      }
    }
  }

  String _normaliseStatus(String status) {
    final raw = status.trim().toUpperCase();
    if (raw == 'COMPLETED' || raw == 'DONE' || raw == 'COMPLETE') {
      return 'COMPLETED';
    }
    if (raw == 'DRAFT' ||
        raw == 'ACTIVE' ||
        raw == 'IN_PROGRESS' ||
        raw == 'IN PROGRESS' ||
        raw == 'STARTED') {
      return 'IN_PROGRESS';
    }
    if (raw.contains('COMPLETE')) return 'COMPLETED';
    return raw.isEmpty ? 'IN_PROGRESS' : raw;
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Completed';
      case 'IN_PROGRESS':
      case 'DRAFT':
      case 'ACTIVE':
        return 'In progress';
      case 'SUPERSEDED':
        return 'Superseded';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'IN_PROGRESS':
      case 'DRAFT':
      case 'ACTIVE':
        return Colors.orange;
      case 'SUPERSEDED':
        return Colors.blueGrey;
      default:
        return Colors.blueGrey;
    }
  }

  String _firstValue(Map<String, Object?> row, List<String> columns) {
    for (final column in columns) {
      final value = (row[column] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _recordSummary(Map<String, Object?> row) {
    final summary = _firstValue(row, [
      'summary',
      'description',
      'serviceProvided',
      'referralReason',
      'monitoringNotes',
      'findings',
      'riskLevel',
      'outcome',
    ]);

    if (summary.isNotEmpty) return summary;

    final payload = (row['payloadJson'] ?? '').toString().trim();
    if (payload.isNotEmpty) return 'Saved form data available';

    return 'Tap to view or edit this record';
  }

  bool _legacyRowMatches(Map<String, Object?> row) {
    final stagePrefix = '${_caseRootId}__${widget.stageKey}';

    for (final entry in row.entries) {
      final key = entry.key;
      final value = (entry.value ?? '').toString().trim();
      if (value.isEmpty) continue;

      if ((key == 'parentCaseId' || key == 'rootCaseId') &&
          value == _caseRootId) {
        return true;
      }

      if ((key == 'id' || key == 'caseId' || key == 'event') &&
          value.startsWith(stagePrefix)) {
        return true;
      }

      if (value.contains(stagePrefix)) return true;
    }

    return false;
  }

  bool _eventRowMatches(Map<String, Object?> row) {
    final event = (row['event'] ?? row['id'] ?? '').toString();
    final rowTei = (row['trackedEntityInstance'] ?? '').toString();
    final rowProgramStage = (row['programStage'] ?? '').toString();
    final prefix = '${_caseRootId}__${widget.stageKey}';

    if (_subjectTei.isNotEmpty &&
        _programStage.isNotEmpty &&
        rowTei == _subjectTei &&
        rowProgramStage == _programStage) {
      return true;
    }

    if (event.startsWith(prefix)) return true;

    return false;
  }

  _StageRecord _recordFromRow(
      Map<String, Object?> row, {
        required bool fromEventsTable,
      }) {
    final id = _firstValue(row, ['event', 'id', 'caseId', 'recordId', 'uid']);

    final date = _firstValue(row, [
      'eventDate',
      'date',
      'assessmentDate',
      'investigationDate',
      'serviceDate',
      'referralDate',
      'monitoringDate',
      'createdAt',
      'updatedAt',
    ]);

    return _StageRecord(
      id: id,
      status: _normaliseStatus((row['status'] ?? 'ACTIVE').toString()),
      date: date,
      summary: _recordSummary(row),
      fromEventsTable: fromEventsTable,
    );
  }

  Future<Map<String, String>> _carePlanForInvestigation(
      Database db,
      String investigationId,
      ) async {
    try {
      await _ensureCarePlanColumns(db);
      final canonicalCarePlanId = 'CP_$investigationId';
      final legacyCarePlanId = '${investigationId}__care_plan';

      final rows = await db.query(
        'mgysd_care_plan',
        where: 'socialInvestigationId = ? OR id = ? OR id = ?',
        whereArgs: [investigationId, canonicalCarePlanId, legacyCarePlanId],
        orderBy: 'updatedAt ASC',
      );

      if (rows.isEmpty) return <String, String>{};

      Map<String, Object?> keep = rows.first;
      for (final row in rows) {
        final rowId = (row['id'] ?? '').toString();
        if (rowId == canonicalCarePlanId) {
          keep = row;
          break;
        }
      }

      final keepId = (keep['id'] ?? '').toString();

      if (rows.length > 1) {
        for (final duplicate in rows) {
          final duplicateId = (duplicate['id'] ?? '').toString().trim();
          if (duplicateId.isEmpty || duplicateId == keepId) continue;
          try {
            await db.update(
              'mgysd_care_plan',
              {
                'carePlanStatus': 'DUPLICATE_SUPERSEDED',
                'syncStatus': 'not-synced',
              },
              where: 'id = ?',
              whereArgs: [duplicateId],
            );
          } catch (_) {}
        }
      }

      final planStatus = (keep['carePlanStatus'] ?? '').toString().trim();
      final formStatus = (keep['status'] ?? '').toString().trim();

      return {
        'id': keepId,
        'status': planStatus.isNotEmpty ? planStatus : 'ACTIVE',
        'formStatus': formStatus,
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String> _ensureCarePlanForInvestigation({
    required Database db,
    required String investigationId,
    String investigationDate = '',
  }) async {
    await _ensureCarePlanColumns(db);

    final existing = await _carePlanForInvestigation(db, investigationId);
    final existingId = (existing['id'] ?? '').trim();
    if (existingId.isNotEmpty) return existingId;

    final carePlanId = 'CP_$investigationId';
    final nowIso = _nowIso();
    final planDate = investigationDate.trim().isNotEmpty
        ? _dateOnly(investigationDate)
        : _today();

    await db.insert(
      'mgysd_care_plan',
      {
        'id': carePlanId,
        'carePlanId': carePlanId,
        'caseId': _caseRootId,
        'householdTei': (widget.householdTei ?? '').trim(),
        'socialInvestigationId': investigationId,
        'planDate': planDate,
        'status': 'DRAFT',
        'carePlanStatus': 'ACTIVE',
        'payloadJson': '{}',
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return carePlanId;
  }

  Future<List<_StageRecord>> _loadRecords() async {
    final db = await _db();
    final records = <_StageRecord>[];
    final seen = <String>{};

    Future<void> addRecord(_StageRecord record) async {
      if (record.id.trim().isEmpty || seen.contains(record.id)) return;
      seen.add(record.id);

      if (widget.stageKey == 'social_investigation') {
        final carePlan = await _carePlanForInvestigation(db, record.id);
        records.add(
          record.copyWith(
            carePlanId: carePlan['id'] ?? '',
            carePlanStatus: carePlan['status'] ?? '',
          ),
        );
      } else {
        records.add(record);
      }
    }

    if (await _tableExists(db, 'events')) {
      final rows = await db.query('events');
      for (final row in rows) {
        if (_eventRowMatches(row)) {
          await addRecord(_recordFromRow(row, fromEventsTable: true));
        }
      }
    }

    if (widget.tableName.trim().isNotEmpty &&
        widget.tableName != 'events' &&
        await _tableExists(db, widget.tableName)) {
      final rows = await db.query(widget.tableName);
      for (final row in rows) {
        if (_legacyRowMatches(row)) {
          await addRecord(_recordFromRow(row, fromEventsTable: false));
        }
      }
    }

    records.sort((a, b) {
      final ad = a.date.isNotEmpty ? a.date : a.id;
      final bd = b.date.isNotEmpty ? b.date : b.id;
      return bd.compareTo(ad);
    });

    return records;
  }

  Future<void> _refresh() async {
    final nextFuture = _loadRecords();

    if (!mounted) return;

    setState(() {
      _future = nextFuture;
    });

    await nextFuture;
  }

  MgysdCase _caseForRecord(String id) {
    final displayName = (widget.subjectName ?? '').trim().isNotEmpty
        ? widget.subjectName!.trim()
        : widget.parentCase.fullName;

    return MgysdCase(
      id: id,
      caseNo: widget.parentCase.caseNo,
      fullName: displayName,
      district: widget.parentCase.district,
      status: widget.parentCase.status,
      phone: widget.parentCase.phone,
      enrollmentDate: widget.parentCase.enrollmentDate,
    );
  }

  Future<void> _openCarePlanForInvestigation(_StageRecord record) async {
    final db = await _db();
    final carePlanId = await _ensureCarePlanForInvestigation(
      db: db,
      investigationId: record.id,
      investigationDate: record.date,
    );

    final carePlanCase = _caseForRecord(carePlanId);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdCarePlanPage(
          color: widget.color,
          mgysdCase: carePlanCase,
          householdTei: widget.householdTei,
          householdName: widget.householdName,
          clientName: widget.clientName,
          socialInvestigationId: record.id,
          socialInvestigationDate: record.date,
        ),
      ),
    );

    await _refresh();
  }

  Future<void> _openForm(String id) async {
    final mgysdCase = _caseForRecord(id);
    Widget page;

    switch (widget.stageKey) {
      case 'social_investigation':
        page = MgysdSocialInvestigationPage(
          color: widget.color,
          mgysdCase: mgysdCase,
          householdTei: widget.householdTei,
          householdName: widget.householdName,
          clientName: widget.clientName,
        );
        break;
      case 'service_provision':
        page = MgysdServiceProvisionPage(
          color: widget.color,
          mgysdCase: mgysdCase,
          householdTei: widget.householdTei,
          householdName: widget.householdName,
          clientName: widget.clientName,
          memberTei: _memberTei,
          memberName: _memberName,
          memberRole: _memberRole,
        );
        break;
      case 'referral':
        page = MgysdReferralPage(
          color: widget.color,
          mgysdCase: mgysdCase,
          householdTei: widget.householdTei,
          householdName: widget.householdName,
          clientName: widget.subjectName ?? widget.clientName,
        );
        break;
      case 'monitoring':
        page = MgysdMonitoringPage(
          color: widget.color,
          mgysdCase: mgysdCase,
          householdTei: widget.householdTei,
          householdName: widget.householdName,
          clientName: widget.clientName,
        );
        break;
      case 'case_closure':
        page = MgysdCaseClosurePage(
          color: widget.color,
          mgysdCase: mgysdCase,
          householdTei: widget.householdTei,
          householdName: widget.householdName,
          clientName: widget.clientName,
        );
        break;
      default:
        return;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _refresh();
  }

  Future<void> _addNew() async {
    final db = await _db();
    final id = _newRecordId();

    await MgysdProgramStageEventHelper.saveContext(
      db: db,
      eventId: id,
      parentCaseId: _caseRootId,
      stageKey: widget.stageKey,
      tableName: widget.tableName,
      programStage: _programStage,
      trackedEntityInstance: _subjectTei,
      enrollment: _subjectEnrollment,
      householdTei: widget.householdTei,
      householdName: widget.householdName,
      clientName: widget.clientName,
      subjectName: widget.subjectName,
      subjectRole: widget.subjectRole,
    );

    await _openForm(id);
  }

  Widget _chip(String label, {required Color color}) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _header(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: widget.color.withOpacity(0.13),
            child: Icon(widget.icon, color: widget.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stageTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count saved record${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12.5,
                  ),
                ),
                if ((widget.subjectName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _chip(widget.subjectName!.trim(), color: widget.color),
                      if ((widget.subjectRole ?? '').trim().isNotEmpty)
                        _chip(widget.subjectRole!.trim(), color: Colors.blueGrey),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carePlanAction(_StageRecord record) {
    if (widget.stageKey != 'social_investigation') {
      return const SizedBox.shrink();
    }

    final status = record.carePlanStatus.trim().isEmpty
        ? 'Active'
        : _statusLabel(record.carePlanStatus);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: widget.color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: widget.color.withOpacity(0.14),
            child: Icon(Icons.assignment_outlined, color: widget.color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Linked Care Plan',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lifecycle: $status • one plan per investigation',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _openCarePlanForInvestigation(record),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color.withOpacity(0.40)),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(_StageRecord record, int index) {
    final color = _statusColor(record.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openForm(record.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: widget.color.withOpacity(0.12),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.stageTitle} ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12.5,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip(_statusLabel(record.status), color: color),
                            if (record.date.trim().isNotEmpty)
                              _chip(_dateOnly(record.date), color: Colors.blueGrey),
                            if (record.fromEventsTable)
                              _chip('Event', color: widget.color),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.blueGrey),
                ],
              ),
              _carePlanAction(record),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        CircleAvatar(
          radius: 38,
          backgroundColor: widget.color.withOpacity(0.10),
          child: Icon(widget.icon, color: widget.color, size: 36),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No ${widget.stageTitle} records yet',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Tap Add New to create the first record.',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.color,
        title: Text(widget.stageTitle),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.color,
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: const Text('Add New'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_StageRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Loading records...',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    'Failed to load records: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              );
            }

            final records = snapshot.data ?? <_StageRecord>[];
            if (records.isEmpty) return _emptyState();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
              children: [
                _header(records.length),
                ...records.asMap().entries.map(
                      (entry) => _recordCard(entry.value, entry.key),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
