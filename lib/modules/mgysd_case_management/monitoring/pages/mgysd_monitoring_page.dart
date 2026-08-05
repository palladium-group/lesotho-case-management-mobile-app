import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:sqflite/sqflite.dart';

class MgysdMonitoringPage extends StatefulWidget {
  const MgysdMonitoringPage({
    Key? key,
    required this.color,
    required this.mgysdCase,
    this.householdTei,
    this.householdName,
    this.clientName,
  }) : super(key: key);

  final Color color;
  final MgysdCase mgysdCase;
  final String? householdTei;
  final String? householdName;
  final String? clientName;

  @override
  State<MgysdMonitoringPage> createState() => _MgysdMonitoringPageState();
}

class _MonitoringGoal {
  final String id;
  final String carePlanId;
  final String socialInvestigationId;
  final String householdTei;
  final String subjectTei;
  final String subjectName;
  final String subjectRole;
  final String term;
  final String goal;
  final String goalStatus;
  final List<_ServiceRecord> services;

  const _MonitoringGoal({
    required this.id,
    required this.carePlanId,
    required this.socialInvestigationId,
    required this.householdTei,
    required this.subjectTei,
    required this.subjectName,
    required this.subjectRole,
    required this.term,
    required this.goal,
    required this.goalStatus,
    required this.services,
  });
}

class _ServiceRecord {
  final String id;
  final String serviceDate;
  final String serviceProvided;
  final String outcome;
  final String status;

  const _ServiceRecord({
    required this.id,
    required this.serviceDate,
    required this.serviceProvided,
    required this.outcome,
    required this.status,
  });
}

class _GoalReviewControllers {
  final TextEditingController progressNotes = TextEditingController();
  final TextEditingController challenges = TextEditingController();
  final TextEditingController recommendation = TextEditingController();
  final TextEditingController nextFollowupDate = TextEditingController();
  String progressStatus = 'IN_PROGRESS';

  void dispose() {
    progressNotes.dispose();
    challenges.dispose();
    recommendation.dispose();
    nextFollowupDate.dispose();
  }
}

// CHANGE 1 — _PersonInterviewedEntry class
class _PersonInterviewedEntry {
  final String localId;
  final TextEditingController nameController;
  final TextEditingController roleOtherController;
  final TextEditingController purposeController;
  String role;

  _PersonInterviewedEntry({
    required this.localId,
    String name = '',
    this.role = '',
    String roleOther = '',
    String purpose = '',
  })  : nameController = TextEditingController(text: name),
        roleOtherController = TextEditingController(text: roleOther),
        purposeController = TextEditingController(text: purpose);

  bool get requiresRoleSpecification =>
      role == 'Other stakeholder (specify)' ||
          role == 'Other member of the HH (specify)' ||
          role == 'OTHER';

  String get resolvedRole {
    final specified = roleOtherController.text.trim();
    return requiresRoleSpecification && specified.isNotEmpty ? specified : role;
  }

  void dispose() {
    nameController.dispose();
    roleOtherController.dispose();
    purposeController.dispose();
  }

  Map<String, dynamic> toJson() => {
    'name': nameController.text.trim(),
    'roleOrRelationship': role,
    'roleOrRelationshipOther': roleOtherController.text.trim(),
    'roleOrRelationshipDisplay': resolvedRole,
    'purposeOfInterview': purposeController.text.trim(),
  };
}

class _MgysdMonitoringPageState extends State<MgysdMonitoringPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  String _monitoringId = '';
  String _parentCaseId = '';
  String _householdTei = '';
  String _caseOrgUnit = '';
  String _activeCarePlanId = '';
  String _activeCarePlanStatus = '';
  String _activeSocialInvestigationId = '';

  String _monitoringReason = 'ROUTINE_MONITORING';
  String _overallProgressStatus = 'IN_PROGRESS';

  final TextEditingController _monitoringDateController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _overallChallengesController = TextEditingController();
  final TextEditingController _nextActionsController = TextEditingController();
  final TextEditingController _nextVisitDateController = TextEditingController();

  final TextEditingController _reassessmentReasonController = TextEditingController();
  String _reassessmentRiskLevel = '';
  final TextEditingController _reassessmentFindingsController = TextEditingController();
  final TextEditingController _reassessmentImmediateActionsController = TextEditingController();

  final List<_MonitoringGoal> _goals = [];
  final Map<String, _GoalReviewControllers> _goalReviews = {};

  // CHANGE 2 — _personsInterviewed list
  final List<_PersonInterviewedEntry> _personsInterviewed = [];

  static const List<String> _monitoringReasons = [
    'ROUTINE_MONITORING',
    'REASSESSMENT',
  ];

  static const Map<String, String> _monitoringReasonLabels = {
    'ROUTINE_MONITORING': 'Routine monitoring',
    'REASSESSMENT': 'Reassessment',
  };

  static const List<String> _progressStatuses = [
    'NOT_STARTED',
    'IN_PROGRESS',
    'ACHIEVED',
    'NO_LONGER_RELEVANT',
    'NEEDS_REASSESSMENT',
  ];

  static const Map<String, String> _progressLabels = {
    'NOT_STARTED': 'Not started',
    'IN_PROGRESS': 'In progress',
    'ACHIEVED': 'Achieved',
    'NO_LONGER_RELEVANT': 'No longer relevant',
    'NEEDS_REASSESSMENT': 'Needs reassessment',
  };

  static const List<String> _riskLevels = [
    'LOW',
    'MEDIUM',
    'HIGH',
  ];

  static const Map<String, String> _riskLevelLabels = {
    'LOW': 'Low',
    'MEDIUM': 'Medium',
    'HIGH': 'High',
  };

  static const List<String> _personInterviewRoleOptions = [
    'Parent(s)',
    'Teacher',
    'Nurse',
    'Area Chief',
    'Community Health Worker',
    'Neighbour',
    'Caregiver/Personal assistant',
    'Community counsellor',
    'Other stakeholder (specify)',
    'Other member of the HH (specify)',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _parentCaseId = widget.mgysdCase.id.split('__').first;
    _monitoringId = _resolveMonitoringId(widget.mgysdCase.id);
    _monitoringDateController.text = _today();
    _loadData();
  }

  @override
  void dispose() {
    _monitoringDateController.dispose();
    _summaryController.dispose();
    _overallChallengesController.dispose();
    _nextActionsController.dispose();
    _nextVisitDateController.dispose();
    _reassessmentReasonController.dispose();
    _reassessmentFindingsController.dispose();
    _reassessmentImmediateActionsController.dispose();
    for (final review in _goalReviews.values) {
      review.dispose();
    }
    // CHANGE 8 — dispose persons interviewed
    for (final entry in _personsInterviewed) {
      entry.dispose();
    }
    super.dispose();
  }

  String _resolveMonitoringId(String rawId) {
    if (rawId.trim().length == 11 && !rawId.contains('__')) return rawId.trim();
    final parts = rawId.split('__');
    if (parts.length >= 3 && parts.last.trim().length == 11) return parts.last.trim();
    return AppUtil.getUid();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  String _today() {
    final d = DateTime.now();
    return _formatDate(d);
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = _formatDate(picked));
    }
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

  Future<bool> _columnExists(Database db, String table, String column) async {
    try {
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.any((row) => (row['name'] ?? '').toString() == column);
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureMonitoringColumns(Database db) async {
    Future<void> add(String table, String column, String sql) async {
      if (await _tableExists(db, table) && !await _columnExists(db, table, column)) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mgysd_monitoring_goal (
        id TEXT PRIMARY KEY,
        monitoringId TEXT,
        caseId TEXT,
        householdTei TEXT,
        carePlanId TEXT,
        socialInvestigationId TEXT,
        memberTei TEXT,
        goalId TEXT,
        progressStatus TEXT,
        progressNotes TEXT,
        challenges TEXT,
        recommendation TEXT,
        nextFollowupDate TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT DEFAULT 'not-synced'
      )
    ''');

    await add('mgysd_monitoring', 'carePlanId',
        "ALTER TABLE mgysd_monitoring ADD COLUMN carePlanId TEXT DEFAULT ''");
    await add('mgysd_monitoring', 'socialInvestigationId',
        "ALTER TABLE mgysd_monitoring ADD COLUMN socialInvestigationId TEXT DEFAULT ''");
    await add('mgysd_monitoring', 'monitoringReason',
        "ALTER TABLE mgysd_monitoring ADD COLUMN monitoringReason TEXT DEFAULT ''");
    await add('mgysd_monitoring', 'syncStatus',
        "ALTER TABLE mgysd_monitoring ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'");

    await add('mgysd_care_plan', 'carePlanStatus',
        "ALTER TABLE mgysd_care_plan ADD COLUMN carePlanStatus TEXT DEFAULT 'ACTIVE'");
    await add('mgysd_care_plan', 'planStatus',
        "ALTER TABLE mgysd_care_plan ADD COLUMN planStatus TEXT DEFAULT 'ACTIVE'");
    await add('mgysd_care_plan', 'socialInvestigationId',
        "ALTER TABLE mgysd_care_plan ADD COLUMN socialInvestigationId TEXT DEFAULT ''");

    await add('mgysd_care_plan_goal', 'carePlanId',
        "ALTER TABLE mgysd_care_plan_goal ADD COLUMN carePlanId TEXT DEFAULT ''");
    await add('mgysd_care_plan_goal', 'socialInvestigationId',
        "ALTER TABLE mgysd_care_plan_goal ADD COLUMN socialInvestigationId TEXT DEFAULT ''");
    await add('mgysd_care_plan_goal', 'goalStatus',
        "ALTER TABLE mgysd_care_plan_goal ADD COLUMN goalStatus TEXT DEFAULT 'open'");
  }

  String _text(dynamic value) => (value ?? '').toString().trim();

  Future<void> _resolveCaseContext(Database db) async {
    _householdTei = (widget.householdTei ?? '').trim();

    final enrollmentRows = await db.query(
      'enrollment',
      where: 'enrollment = ?',
      whereArgs: [_parentCaseId],
      limit: 1,
    );

    if (enrollmentRows.isNotEmpty) {
      final row = enrollmentRows.first;
      _caseOrgUnit = _text(row['orgUnit']);
      if (_householdTei.isEmpty) {
        _householdTei = _text(row['trackedEntityInstance']);
      }
    }
  }

  String _planLifecycleFromRow(Map<String, Object?> row) {
    final value = _text(row['carePlanStatus']).isNotEmpty
        ? _text(row['carePlanStatus'])
        : _text(row['planStatus']).isNotEmpty
        ? _text(row['planStatus'])
        : 'ACTIVE';
    return value.toUpperCase();
  }

  Future<void> _loadActiveCarePlan(Database db) async {
    _activeCarePlanId = '';
    _activeCarePlanStatus = '';
    _activeSocialInvestigationId = '';

    if (_householdTei.isEmpty || !await _tableExists(db, 'mgysd_care_plan')) return;

    final rows = await db.query(
      'mgysd_care_plan',
      where: '''
        householdTei = ?
        AND UPPER(COALESCE(carePlanStatus, planStatus, 'ACTIVE')) = 'ACTIVE'
      ''',
      whereArgs: [_householdTei],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return;
    final row = rows.first;
    _activeCarePlanId = _text(row['id']);
    _activeCarePlanStatus = _planLifecycleFromRow(row);
    _activeSocialInvestigationId = _text(row['socialInvestigationId']);
  }

  Future<List<_ServiceRecord>> _servicesForGoal(Database db, String goalId) async {
    if (goalId.isEmpty || !await _tableExists(db, 'mgysd_service_provision')) {
      return <_ServiceRecord>[];
    }

    final rows = await db.query(
      'mgysd_service_provision',
      where: 'goalId = ?',
      whereArgs: [goalId],
      orderBy: 'serviceDate DESC, updatedAt DESC',
    );

    return rows.map((row) {
      return _ServiceRecord(
        id: _text(row['id']),
        serviceDate: _text(row['serviceDate']),
        serviceProvided: _text(row['serviceProvided']).isNotEmpty
            ? _text(row['serviceProvided'])
            : _readPayloadValue(row, 'serviceProvided'),
        outcome: _text(row['outcome']).isNotEmpty
            ? _text(row['outcome'])
            : _readPayloadValue(row, 'outcome'),
        status: _text(row['status']),
      );
    }).toList();
  }

  String _readPayloadValue(Map<String, Object?> row, String key) {
    try {
      final raw = _text(row['payloadJson']);
      if (raw.isEmpty) return '';
      final decoded = jsonDecode(raw);
      if (decoded is Map) return _text(decoded[key]);
    } catch (_) {}
    return '';
  }

  Future<void> _loadGoals(Database db) async {
    _goals.clear();
    for (final review in _goalReviews.values) {
      review.dispose();
    }
    _goalReviews.clear();

    if (_activeCarePlanId.isEmpty || !await _tableExists(db, 'mgysd_care_plan_goal')) return;

    final rows = await db.query(
      'mgysd_care_plan_goal',
      where: '''
        carePlanId = ?
        AND LOWER(COALESCE(goalStatus, 'open')) != 'achieved'
      ''',
      whereArgs: [_activeCarePlanId],
      orderBy: 'createdAt ASC',
    );

    for (final row in rows) {
      final id = _text(row['id']);
      if (id.isEmpty) continue;

      final goalText = _text(row['goalDescription']).isNotEmpty
          ? _text(row['goalDescription'])
          : _text(row['goal']);
      if (goalText.isEmpty) continue;

      final services = await _servicesForGoal(db, id);
      _goals.add(
        _MonitoringGoal(
          id: id,
          carePlanId: _activeCarePlanId,
          socialInvestigationId: _activeSocialInvestigationId,
          householdTei: _householdTei,
          subjectTei: _text(row['targetTei']).isNotEmpty
              ? _text(row['targetTei'])
              : _text(row['subjectTei']),
          subjectName: _text(row['targetName']).isNotEmpty
              ? _text(row['targetName'])
              : _text(row['subjectName']),
          subjectRole: _text(row['subjectRole']).isNotEmpty
              ? _text(row['subjectRole'])
              : _text(row['targetType']).isNotEmpty
              ? _text(row['targetType'])
              : 'Household member',
          term: _text(row['goalCategory']).isNotEmpty
              ? _text(row['goalCategory'])
              : _text(row['term']),
          goal: goalText,
          goalStatus: _text(row['goalStatus']).isEmpty ? 'open' : _text(row['goalStatus']),
          services: services,
        ),
      );
      _goalReviews[id] = _GoalReviewControllers();
    }
  }

  Future<void> _loadSavedMonitoring(Database db) async {
    if (!await _tableExists(db, 'mgysd_monitoring')) return;

    final rows = await db.query(
      'mgysd_monitoring',
      where: 'id = ?',
      whereArgs: [_monitoringId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    _monitoringReason = _text(row['monitoringReason']).isEmpty
        ? _monitoringReason
        : _text(row['monitoringReason']);
    _monitoringDateController.text = _text(row['monitoringDate']).isEmpty
        ? _monitoringDateController.text
        : _text(row['monitoringDate']);
    _activeCarePlanId = _text(row['carePlanId']).isEmpty ? _activeCarePlanId : _text(row['carePlanId']);
    _activeSocialInvestigationId = _text(row['socialInvestigationId']).isEmpty
        ? _activeSocialInvestigationId
        : _text(row['socialInvestigationId']);

    try {
      final payloadRaw = _text(row['payloadJson']);
      if (payloadRaw.isNotEmpty) {
        final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
        _overallProgressStatus = _text(payload['overallProgressStatus']).isEmpty
            ? _overallProgressStatus
            : _text(payload['overallProgressStatus']);
        _summaryController.text = _text(payload['summary']);
        _overallChallengesController.text = _text(payload['overallChallenges']);
        _nextActionsController.text = _text(payload['nextActions']);
        _nextVisitDateController.text = _text(payload['nextVisitDate']);
        _reassessmentReasonController.text = _text(payload['reassessmentReason']);
        _reassessmentRiskLevel = _normaliseRiskLevel(_text(payload['reassessmentRiskLevel']));
        _reassessmentFindingsController.text = _text(payload['reassessmentFindings']);
        _reassessmentImmediateActionsController.text = _text(payload['reassessmentImmediateActions']);

        // CHANGE 4 — restore persons interviewed
        final list = payload['personsInterviewed'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          _personsInterviewed.clear();
          for (final item in list) {
            final m = item as Map<String, dynamic>;
            final savedRole = _text(m['roleOrRelationship']);
            final savedRoleOther = _text(m['roleOrRelationshipOther']);
            final normalisedRole = _normaliseInterviewRole(savedRole);
            _personsInterviewed.add(_PersonInterviewedEntry(
              localId: DateTime.now().microsecondsSinceEpoch.toString(),
              name: _text(m['name']),
              role: normalisedRole,
              roleOther: savedRoleOther.isNotEmpty
                  ? savedRoleOther
                  : normalisedRole == 'OTHER' &&
                  savedRole.isNotEmpty &&
                  savedRole.toUpperCase() != 'OTHER'
                  ? savedRole
                  : '',
              purpose: _text(m['purposeOfInterview']),
            ));
          }
        }
      }
    } catch (_) {}

    if (await _tableExists(db, 'mgysd_monitoring_goal')) {
      final goalRows = await db.query(
        'mgysd_monitoring_goal',
        where: 'monitoringId = ?',
        whereArgs: [_monitoringId],
      );
      for (final goalRow in goalRows) {
        final goalId = _text(goalRow['goalId']);
        if (goalId.isEmpty || !_goalReviews.containsKey(goalId)) continue;
        final review = _goalReviews[goalId]!;
        review.progressStatus = _text(goalRow['progressStatus']).isEmpty
            ? review.progressStatus
            : _text(goalRow['progressStatus']);
        review.progressNotes.text = _text(goalRow['progressNotes']);
        review.challenges.text = _text(goalRow['challenges']);
        review.recommendation.text = _text(goalRow['recommendation']);
        review.nextFollowupDate.text = _text(goalRow['nextFollowupDate']);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = await _db();
      await _ensureMonitoringColumns(db);
      await _resolveCaseContext(db);
      await _loadActiveCarePlan(db);
      await _loadGoals(db);
      await _loadSavedMonitoring(db);
      // CHANGE 3 — seed one blank entry if nothing was restored
      if (_personsInterviewed.isEmpty) _addPersonInterviewed();
    } catch (e) {
      _showSnack('Failed to load monitoring: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // CHANGE 2 — add/remove helpers
  void _addPersonInterviewed() {
    setState(() {
      _personsInterviewed.add(
        _PersonInterviewedEntry(
          localId: DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );
    });
  }

  void _removePersonInterviewed(int index) {
    setState(() {
      _personsInterviewed[index].dispose();
      _personsInterviewed.removeAt(index);
    });
  }

  String _normaliseInterviewRole(String value) {
    if (_personInterviewRoleOptions.contains(value)) return value;
    return value.trim().isEmpty ? '' : 'OTHER';
  }

  String _normaliseRiskLevel(String value) {
    final normalised = value.trim().toUpperCase().replaceAll('_', ' ');
    switch (normalised) {
      case 'LOW':
      case 'LOW RISK':
        return 'LOW';
      case 'MEDIUM':
      case 'MEDIUM RISK':
      case 'MODERATE':
      case 'MODERATE RISK':
        return 'MEDIUM';
      case 'HIGH':
      case 'HIGH RISK':
        return 'HIGH';
      default:
        return '';
    }
  }

  bool _goalNeedsFollowup(String status) {
    return status != 'ACHIEVED' && status != 'NO_LONGER_RELEVANT';
  }

  Map<String, dynamic> _payload(String status) {
    return {
      'id': _monitoringId,
      'caseId': _parentCaseId,
      'householdTei': _householdTei,
      'carePlanId': _activeCarePlanId,
      'socialInvestigationId': _activeSocialInvestigationId,
      'monitoringDate': _monitoringDateController.text.trim(),
      'monitoringReason': _monitoringReason,
      'status': status,
      'overallProgressStatus': _overallProgressStatus,
      'summary': _summaryController.text.trim(),
      'overallChallenges': _overallChallengesController.text.trim(),
      'nextActions': _nextActionsController.text.trim(),
      'nextVisitDate': _nextVisitDateController.text.trim(),
      'reassessmentReason': _reassessmentReasonController.text.trim(),
      'reassessmentRiskLevel': _reassessmentRiskLevel,
      'reassessmentFindings': _reassessmentFindingsController.text.trim(),
      'reassessmentImmediateActions': _reassessmentImmediateActionsController.text.trim(),
      // CHANGE 6 — include personsInterviewed in payload
      'personsInterviewed': _personsInterviewed.map((e) => e.toJson()).toList(),
      'goals': _goals.map((goal) {
        final review = _goalReviews[goal.id];
        return {
          'goalId': goal.id,
          'subjectTei': goal.subjectTei,
          'subjectName': goal.subjectName,
          'goal': goal.goal,
          'progressStatus': review?.progressStatus,
          'progressNotes': review?.progressNotes.text.trim(),
          'challenges': review?.challenges.text.trim(),
          'recommendation': review?.recommendation.text.trim(),
          'nextFollowupDate': review?.nextFollowupDate.text.trim(),
        };
      }).toList(),
    };
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_goalNeedsFollowup(_overallProgressStatus)) {
      _nextVisitDateController.clear();
    }
    for (final review in _goalReviews.values) {
      if (!_goalNeedsFollowup(review.progressStatus)) {
        review.nextFollowupDate.clear();
      }
    }

    if (_householdTei.isEmpty) {
      _showSnack('Household TEI not found. Please refresh the case and try again.');
      return;
    }

    if (_activeCarePlanId.isEmpty) {
      _showSnack('No active Care Plan found. Open Social Investigation and create/check its Care Plan first.');
      return;
    }

    setState(() => _saving = true);
    try {
      final db = await _db();
      final now = DateTime.now().toIso8601String();
      final monitoringDate = _monitoringDateController.text.trim().isEmpty
          ? _today()
          : _monitoringDateController.text.trim();

      await db.insert(
        'events',
        {
          'id': _monitoringId,
          'event': _monitoringId,
          'eventDate': monitoringDate,
          'program': MgysdDhis2Uids.enrolledHouseholdsProgram,
          'programStage': MgysdDhis2Uids.monitoringStage,
          'trackedEntityInstance': _householdTei,
          'status': status,
          'orgUnit': _caseOrgUnit,
          'syncStatus': 'not-synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.insert(
        'mgysd_monitoring',
        {
          'id': _monitoringId,
          'caseId': _monitoringId,
          'parentCaseId': _parentCaseId,
          'rootCaseId': _parentCaseId,
          'householdTei': _householdTei,
          'carePlanId': _activeCarePlanId,
          'socialInvestigationId': _activeSocialInvestigationId,
          'monitoringDate': monitoringDate,
          'monitoringReason': _monitoringReason,
          'stageKey': 'monitoring',
          'status': status,
          'payloadJson': jsonEncode(_payload(status)),
          // CHANGE 7 — persist personsInterviewedJson column
          'personsInterviewedJson': jsonEncode(
              _personsInterviewed.map((e) => e.toJson()).toList()),
          'updatedAt': now,
          'syncStatus': 'not-synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _saveGoalReviews(db, now);

      if (_monitoringReason == 'REASSESSMENT' && status == 'COMPLETED') {
        await _createReassessmentCycle(db, now);
      }

      if (!mounted) return;
      _showSnack(status == 'COMPLETED'
          ? 'Monitoring completed.'
          : 'Monitoring saved as draft.');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Failed to save monitoring: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveGoalReviews(Database db, String now) async {
    for (final goal in _goals) {
      final review = _goalReviews[goal.id];
      if (review == null) continue;

      await db.insert(
        'mgysd_monitoring_goal',
        {
          'id': '${_monitoringId}_${goal.id}',
          'monitoringId': _monitoringId,
          'caseId': _parentCaseId,
          'householdTei': _householdTei,
          'carePlanId': _activeCarePlanId,
          'socialInvestigationId': _activeSocialInvestigationId,
          'memberTei': goal.subjectTei,
          'goalId': goal.id,
          'progressStatus': review.progressStatus,
          'progressNotes': review.progressNotes.text.trim(),
          'challenges': review.challenges.text.trim(),
          'recommendation': review.recommendation.text.trim(),
          'nextFollowupDate': review.nextFollowupDate.text.trim(),
          'createdAt': now,
          'updatedAt': now,
          'syncStatus': 'not-synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (review.progressStatus == 'ACHIEVED' ||
          review.progressStatus == 'NO_LONGER_RELEVANT') {
        await db.update(
          'mgysd_care_plan_goal',
          {
            'goalStatus': review.progressStatus == 'ACHIEVED'
                ? 'achieved'
                : 'no_longer_relevant',
            'updatedAt': now,
            'syncStatus': 'not-synced',
          },
          where: 'id = ?',
          whereArgs: [goal.id],
        );
      }
    }
  }

  Future<void> _createReassessmentCycle(Database db, String now) async {
    final newSocialInvestigationId = AppUtil.getUid();
    final newCarePlanId = AppUtil.getUid();
    final today = _monitoringDateController.text.trim().isEmpty
        ? _today()
        : _monitoringDateController.text.trim();

    await db.update(
      'mgysd_care_plan',
      {
        'carePlanStatus': 'SUPERSEDED',
        'planStatus': 'SUPERSEDED',
        'updatedAt': now,
        'syncStatus': 'not-synced',
      },
      where: 'id = ?',
      whereArgs: [_activeCarePlanId],
    );

    await db.insert(
      'mgysd_social_investigation',
      {
        'id': newSocialInvestigationId,
        'caseId': newSocialInvestigationId,
        'parentCaseId': _parentCaseId,
        'rootCaseId': _parentCaseId,
        'householdTei': _householdTei,
        'investigationDate': today,
        'stageKey': 'social_investigation',
        'status': 'DRAFT',
        'payloadJson': jsonEncode({
          'eventId': newSocialInvestigationId,
          'parentCaseId': _parentCaseId,
          'householdTei': _householdTei,
          'source': 'REASSESSMENT_MONITORING',
          'createdFromMonitoringId': _monitoringId,
          'reassessmentReason': _reassessmentReasonController.text.trim(),
          'reassessmentRiskLevel': _reassessmentRiskLevel,
          'reassessmentFindings': _reassessmentFindingsController.text.trim(),
          'reassessmentImmediateActions': _reassessmentImmediateActionsController.text.trim(),
        }),
        'syncStatus': 'not-synced',
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'mgysd_care_plan',
      {
        'id': newCarePlanId,
        'caseId': _parentCaseId,
        'householdTei': _householdTei,
        'socialInvestigationId': newSocialInvestigationId,
        'planDate': today,
        'status': 'DRAFT',
        'carePlanStatus': 'ACTIVE',
        'planStatus': 'ACTIVE',
        'payloadJson': jsonEncode({
          'carePlanId': newCarePlanId,
          'parentCaseId': _parentCaseId,
          'householdTei': _householdTei,
          'socialInvestigationId': newSocialInvestigationId,
          'createdFromMonitoringId': _monitoringId,
          'copiedOpenGoalsFromCarePlanId': _activeCarePlanId,
        }),
        'updatedAt': now,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final goal in _goals) {
      final review = _goalReviews[goal.id];
      final progress = review?.progressStatus ?? 'IN_PROGRESS';
      if (progress == 'ACHIEVED' || progress == 'NO_LONGER_RELEVANT') continue;

      await db.insert(
        'mgysd_care_plan_goal',
        {
          'id': AppUtil.getUid(),
          'carePlanId': newCarePlanId,
          'caseId': _parentCaseId,
          'householdTei': _householdTei,
          'socialInvestigationId': newSocialInvestigationId,
          'goalCategory': goal.term,
          'term': goal.term,
          'targetType': goal.subjectRole,
          'targetTei': goal.subjectTei,
          'targetName': goal.subjectName,
          'subjectTei': goal.subjectTei,
          'subjectName': goal.subjectName,
          'subjectRole': goal.subjectRole,
          'goalDescription': goal.goal,
          'goal': goal.goal,
          'goalStatus': 'open',
          'createdAt': now,
          'updatedAt': now,
          'syncStatus': 'not-synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _label(String code, Map<String, String> labels) => labels[code] ?? code;

  Widget _surface({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: widget.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15.8, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.blueGrey, height: 1.35, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
        bool readOnly = false,
        VoidCallback? onTap,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF9FBFD),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String value) onChanged,
    Map<String, String>? labels,
    bool requiredField = false,
  }) {
    final safeValue = options.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(labels == null ? option : _label(option, labels), overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        validator: (v) {
          if (!requiredField) return null;
          if ((v ?? '').trim().isEmpty) return 'Required';
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF9FBFD),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _two(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 620) return Column(children: [a, b]);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
      );
    });
  }

  Widget _chip(String label, {Color? color}) {
    final c = color ?? Colors.blueGrey;
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.12)),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _header() {
    final title = (widget.householdName ?? '').trim().isNotEmpty
        ? widget.householdName!.trim()
        : (widget.clientName ?? widget.mgysdCase.fullName);
    return _surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: widget.color.withOpacity(0.12),
            child: Icon(Icons.monitor_heart_outlined, color: widget.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Case: ${widget.mgysdCase.caseNo}', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _chip(_monitoringReasonLabels[_monitoringReason] ?? _monitoringReason, color: widget.color),
                    _chip(_activeCarePlanId.isEmpty ? 'No active care plan' : 'Active care plan', color: _activeCarePlanId.isEmpty ? Colors.redAccent : Colors.green),
                    _chip('${_goals.length} open goals'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monitoringReasonSection() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Monitoring Type',
            'Choose whether this is a normal follow-up visit or a reassessment that starts a new investigation and support cycle.',
            Icons.route_outlined,
          ),
          _input(
            _monitoringDateController,
            'Monitoring Date',
            readOnly: true,
            onTap: () => _pickDate(_monitoringDateController),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          _dropdown(
            label: 'Reason for Monitoring',
            value: _monitoringReason,
            options: _monitoringReasons,
            labels: _monitoringReasonLabels,
            requiredField: true,
            onChanged: (v) => setState(() => _monitoringReason = v),
          ),
          if (_monitoringReason == 'REASSESSMENT')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.deepOrange.withOpacity(0.14)),
              ),
              child: const Text(
                'Completing reassessment will create a new Social Investigation and new ACTIVE Care Plan. Unresolved goals will be copied forward. The old Care Plan will become superseded.',
                style: TextStyle(color: Colors.black87, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // CHANGE 5 — _personsInterviewedSection widget method
  Widget _personsInterviewedSection() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Persons interviewed',
            'People interviewed during this monitoring visit and the purpose of each interview.',
            Icons.people_alt_outlined,
          ),
          ..._personsInterviewed.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFD),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Person ${idx + 1}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _input(entry.nameController, 'First name'),
                  _dropdown(
                    label: 'Role / Relationship',
                    value: entry.role,
                    options: _personInterviewRoleOptions,
                    onChanged: (value) {
                      setState(() {
                        entry.role = value;
                        if (!entry.requiresRoleSpecification) {
                          entry.roleOtherController.clear();
                        }
                      });
                    },
                  ),
                  if (entry.requiresRoleSpecification)
                    _input(
                      entry.roleOtherController,
                      'Specify role / relationship',
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Please specify the role / relationship'
                          : null,
                    ),
                  _input(
                    entry.purposeController,
                    'Purpose of interview',
                    maxLines: 2,
                  ),
                  if (_personsInterviewed.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _removePersonInterviewed(idx),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: _addPersonInterviewed,
            icon: const Icon(Icons.add),
            label: const Text('Add another person interviewed'),
          ),
        ],
      ),
    );
  }

  Widget _carePlanSummary() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Current Support Plan',
            'Monitoring is linked to the current active Care Plan. Service progress is reviewed against its open goals.',
            Icons.assignment_turned_in_outlined,
          ),
          if (_activeCarePlanId.isEmpty)
            const Text(
              'No active Care Plan was found. Open the Social Investigation record and check its linked Care Plan first.',
              style: TextStyle(color: Colors.redAccent, height: 1.35, fontWeight: FontWeight.w700),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Care Plan: $_activeCarePlanId', color: widget.color),
                _chip('Status: $_activeCarePlanStatus', color: Colors.green),
                if (_activeSocialInvestigationId.isNotEmpty)
                  _chip('Investigation: $_activeSocialInvestigationId'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _routineMonitoringSection() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Routine Monitoring Review',
            'Review whether services are moving the household and family members toward the care plan goals.',
            Icons.fact_check_outlined,
          ),
          _dropdown(
            label: 'Overall Progress',
            value: _overallProgressStatus,
            options: _progressStatuses,
            labels: _progressLabels,
            onChanged: (v) {
              setState(() {
                _overallProgressStatus = v;
                if (!_goalNeedsFollowup(v)) {
                  _nextVisitDateController.clear();
                }
              });
            },
          ),
          _input(_summaryController, 'Overall progress summary', maxLines: 4),
          _input(_overallChallengesController, 'Overall challenges / barriers', maxLines: 4),
          _input(_nextActionsController, 'Next actions required', maxLines: 4),
          if (_goalNeedsFollowup(_overallProgressStatus))
            _input(
              _nextVisitDateController,
              'Next visit date',
              readOnly: true,
              onTap: () => _pickDate(_nextVisitDateController),
            ),
        ],
      ),
    );
  }

  Widget _reassessmentSection() {
    if (_monitoringReason != 'REASSESSMENT') return const SizedBox.shrink();
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Reassessment Findings',
            'Capture why the case requires reassessment. A new investigation and care plan cycle will be opened after completion.',
            Icons.restart_alt_outlined,
          ),
          _input(_reassessmentReasonController, 'Reason for reassessment', maxLines: 4, validator: (v) {
            if (_monitoringReason == 'REASSESSMENT' && (v ?? '').trim().isEmpty) return 'Required';
            return null;
          }),
          _dropdown(
            label: 'Updated risk level',
            value: _reassessmentRiskLevel,
            options: _riskLevels,
            labels: _riskLevelLabels,
            requiredField: true,
            onChanged: (value) => setState(() => _reassessmentRiskLevel = value),
          ),
          _input(_reassessmentFindingsController, 'Key reassessment findings', maxLines: 5),
          _input(_reassessmentImmediateActionsController, 'Immediate actions required', maxLines: 4),
        ],
      ),
    );
  }

  Widget _serviceHistory(_MonitoringGoal goal) {
    if (goal.services.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Text(
          'No services recorded for this goal yet.',
          style: TextStyle(color: Colors.blueGrey),
        ),
      );
    }

    return Column(
      children: goal.services.map((service) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.055),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.teal.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (service.serviceDate.isNotEmpty) _chip(service.serviceDate, color: Colors.teal),
                  if (service.status.isNotEmpty) _chip(service.status, color: Colors.blueGrey),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                service.serviceProvided.isEmpty ? 'Service provided' : service.serviceProvided,
                style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25),
              ),
              if (service.outcome.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Outcome: ${service.outcome}', style: const TextStyle(color: Colors.blueGrey, height: 1.25)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _goalReviewCard(_MonitoringGoal goal, int index) {
    final review = _goalReviews[goal.id]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.color.withOpacity(0.12),
                child: Text('${index + 1}', style: TextStyle(color: widget.color, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.goal, style: const TextStyle(fontWeight: FontWeight.w900, height: 1.3)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _chip(goal.subjectName.isEmpty ? 'Household/member' : goal.subjectName, color: widget.color),
                        if (goal.subjectRole.isNotEmpty) _chip(goal.subjectRole),
                        if (goal.term.isNotEmpty) _chip(goal.term),
                        _chip('Services: ${goal.services.length}', color: Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Service history', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _serviceHistory(goal),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Progress Status',
            value: review.progressStatus,
            options: _progressStatuses,
            labels: _progressLabels,
            onChanged: (v) {
              setState(() {
                review.progressStatus = v;
                if (!_goalNeedsFollowup(v)) {
                  review.nextFollowupDate.clear();
                }
              });
            },
          ),
          _input(review.progressNotes, 'Progress observed', maxLines: 4),
          _input(review.challenges, 'Challenges still present', maxLines: 3),
          _input(review.recommendation, 'Recommendation / next action for this goal', maxLines: 3),
          if (_goalNeedsFollowup(review.progressStatus))
            _input(
              review.nextFollowupDate,
              'Goal follow-up date',
              readOnly: true,
              onTap: () => _pickDate(review.nextFollowupDate),
            ),
        ],
      ),
    );
  }

  Widget _goalsSection() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Goal Progress Review',
            'These are unresolved goals from the current active Care Plan. Mark achieved goals carefully because they will not be carried into a new reassessment cycle.',
            Icons.track_changes_outlined,
          ),
          if (_goals.isEmpty)
            const Text(
              'No unresolved goals found under the active Care Plan.',
              style: TextStyle(color: Colors.blueGrey, height: 1.35),
            )
          else
            ...List.generate(_goals.length, (index) => _goalReviewCard(_goals[index], index)),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : () => _save('DRAFT'),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color.withOpacity(0.45)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saving ? null : () => _save('COMPLETED'),
            icon: _saving
                ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Saving...' : 'Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
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
        backgroundColor: widget.color,
        title: const Text('Monitoring'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              _monitoringReasonSection(),
              // CHANGE 5 — placed between monitoring reason and care plan summary
              const SizedBox(height: 12),
              _personsInterviewedSection(),
              const SizedBox(height: 12),
              _carePlanSummary(),
              _routineMonitoringSection(),
              _goalsSection(),
              _reassessmentSection(),
              const SizedBox(height: 4),
              _actions(),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}