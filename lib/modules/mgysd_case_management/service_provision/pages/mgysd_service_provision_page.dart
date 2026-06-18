import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/helpers/mgysd_program_stage_event_helper.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:sqflite/sqflite.dart';

class MgysdServiceProvisionPage extends StatefulWidget {
  const MgysdServiceProvisionPage({
    Key? key,
    required this.color,
    required this.mgysdCase,
    this.householdTei,
    this.householdName,
    this.clientName,
    this.memberTei,
    this.memberName,
    this.memberRole,
  }) : super(key: key);

  final Color color;
  final MgysdCase mgysdCase;
  final String? householdTei;
  final String? householdName;
  final String? clientName;

  /// If null/empty, the service page works at HOUSEHOLD level.
  /// If provided, it works for that specific person/member/client.
  final String? memberTei;
  final String? memberName;
  final String? memberRole;

  @override
  State<MgysdServiceProvisionPage> createState() =>
      _MgysdServiceProvisionPageState();
}

class _CarePlanRecord {
  final String id;
  final String socialInvestigationId;
  final String householdTei;
  final String status;
  final String createdAt;
  final String updatedAt;
  final int goalsForTarget;
  final int servicesForTarget;

  const _CarePlanRecord({
    required this.id,
    required this.socialInvestigationId,
    required this.householdTei,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.goalsForTarget,
    required this.servicesForTarget,
  });

  bool get isActive => status.trim().toUpperCase() == 'ACTIVE';
}

class _CareGoalRecord {
  final String id;
  final String carePlanId;
  final String socialInvestigationId;
  final String term;
  final String targetTei;
  final String targetName;
  final String targetRole;
  final String description;
  final String status;
  final String createdAt;

  const _CareGoalRecord({
    required this.id,
    required this.carePlanId,
    required this.socialInvestigationId,
    required this.term,
    required this.targetTei,
    required this.targetName,
    required this.targetRole,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  bool get isAchieved => status.trim().toLowerCase() == 'achieved';
}

class _ServiceRecord {
  final String id;
  final String serviceDate;
  final String serviceProvided;
  final String provider;
  final String outcome;
  final String goalStatus;
  final String status;
  final String updatedAt;

  const _ServiceRecord({
    required this.id,
    required this.serviceDate,
    required this.serviceProvided,
    required this.provider,
    required this.outcome,
    required this.goalStatus,
    required this.status,
    required this.updatedAt,
  });
}

class _GoalWithServices {
  final _CareGoalRecord goal;
  final List<_ServiceRecord> services;

  const _GoalWithServices({
    required this.goal,
    required this.services,
  });
}

class _MgysdServiceProvisionPageState extends State<MgysdServiceProvisionPage> {
  bool _loading = true;
  bool _saving = false;

  List<_CarePlanRecord> _carePlans = [];
  _CarePlanRecord? _selectedPlan;
  List<_GoalWithServices> _goals = [];
  List<_ServiceRecord> _generalServices = [];

  static const List<Map<String, String>> _goalStatusOptions = [
    {'value': 'open', 'label': 'Open'},
    {'value': 'in_progress', 'label': 'In Progress'},
    {'value': 'achieved', 'label': 'Achieved'},
  ];

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  String get _caseRootId {
    final parts = widget.mgysdCase.id.split('__');
    return parts.isNotEmpty ? parts.first : widget.mgysdCase.id;
  }

  String get _householdTei => (widget.householdTei ?? '').trim();

  String get _targetTei {
    final member = (widget.memberTei ?? '').trim();
    if (member.isNotEmpty) return member;
    return _householdTei;
  }

  bool get _isHouseholdTarget => (widget.memberTei ?? '').trim().isEmpty;

  String get _targetName {
    final member = (widget.memberName ?? '').trim();
    if (member.isNotEmpty) return member;

    final household = (widget.householdName ?? '').trim();
    if (household.isNotEmpty) return household;

    return _isHouseholdTarget ? 'Household' : (widget.clientName ?? '').trim();
  }

  String get _targetRole {
    final role = (widget.memberRole ?? '').trim();
    if (role.isNotEmpty) return role;
    return _isHouseholdTarget ? 'Household' : 'Household member';
  }

  String _today() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _dateOnly(String value) {
    final v = value.trim();
    if (v.length >= 10) return v.substring(0, 10);
    return v;
  }

  String _newDhis2Uid() {
    try {
      return AppUtil.getUid();
    } catch (_) {
      final r = Random();
      final raw = '${DateTime.now().millisecondsSinceEpoch}${r.nextInt(999999)}';
      return raw.length >= 11 ? raw.substring(0, 11) : raw.padRight(11, '0');
    }
  }

  String _text(Object? value) => (value ?? '').toString().trim();

  String _normaliseGoalStatus(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'achieved') return 'achieved';
    if (v == 'in_progress' || v == 'in progress') return 'in_progress';
    return 'open';
  }

  String _goalStatusLabel(String value) {
    switch (_normaliseGoalStatus(value)) {
      case 'achieved':
        return 'Achieved';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Open';
    }
  }

  Color _goalStatusColor(String value) {
    switch (_normaliseGoalStatus(value)) {
      case 'achieved':
        return Colors.green;
      case 'in_progress':
        return Colors.orange.shade800;
      default:
        return Colors.blueGrey;
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
      return rows.any((row) => _text(row['name']) == column);
    } catch (_) {
      return false;
    }
  }

  Future<void> _safeAddColumn(
      Database db,
      String table,
      String column,
      String sql,
      ) async {
    if (!await _columnExists(db, table, column)) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  }

  Future<void> _ensureTablesAndColumns(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mgysd_care_plan (
        id TEXT PRIMARY KEY,
        caseId TEXT,
        householdTei TEXT,
        socialInvestigationId TEXT,
        planDate TEXT,
        status TEXT,
        payloadJson TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mgysd_care_plan_goal (
        id TEXT PRIMARY KEY,
        carePlanId TEXT,
        socialInvestigationId TEXT,
        caseId TEXT,
        householdTei TEXT,
        goalCategory TEXT,
        term TEXT,
        targetType TEXT,
        targetTei TEXT,
        targetName TEXT,
        targetRole TEXT,
        subjectId TEXT,
        subjectTei TEXT,
        subjectName TEXT,
        subjectRole TEXT,
        goalDescription TEXT,
        goal TEXT,
        goalStatus TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mgysd_service_provision (
        id TEXT PRIMARY KEY,
        caseId TEXT,
        householdTei TEXT,
        carePlanId TEXT,
        socialInvestigationId TEXT,
        memberTei TEXT,
        goalId TEXT,
        serviceDate TEXT,
        serviceProvided TEXT,
        provider TEXT,
        outcome TEXT,
        goalStatus TEXT,
        status TEXT,
        payloadJson TEXT,
        updatedAt TEXT,
        syncStatus TEXT
      )
    ''');

    await _safeAddColumn(db, 'mgysd_care_plan', 'socialInvestigationId',
        "ALTER TABLE mgysd_care_plan ADD COLUMN socialInvestigationId TEXT DEFAULT ''");
    await _safeAddColumn(db, 'mgysd_care_plan', 'createdAt',
        "ALTER TABLE mgysd_care_plan ADD COLUMN createdAt TEXT DEFAULT ''");
    await _safeAddColumn(db, 'mgysd_care_plan', 'syncStatus',
        "ALTER TABLE mgysd_care_plan ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'");
    await _safeAddColumn(db, 'mgysd_care_plan', 'carePlanStatus',
        "ALTER TABLE mgysd_care_plan ADD COLUMN carePlanStatus TEXT DEFAULT 'ACTIVE'");

    final goalColumns = <String, String>{
      'carePlanId': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN carePlanId TEXT DEFAULT ''",
      'socialInvestigationId': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN socialInvestigationId TEXT DEFAULT ''",
      'caseId': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN caseId TEXT DEFAULT ''",
      'householdTei': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN householdTei TEXT DEFAULT ''",
      'goalCategory': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN goalCategory TEXT DEFAULT ''",
      'term': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN term TEXT DEFAULT ''",
      'targetType': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN targetType TEXT DEFAULT ''",
      'targetTei': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN targetTei TEXT DEFAULT ''",
      'targetName': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN targetName TEXT DEFAULT ''",
      'targetRole': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN targetRole TEXT DEFAULT ''",
      'subjectId': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN subjectId TEXT DEFAULT ''",
      'subjectTei': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN subjectTei TEXT DEFAULT ''",
      'subjectName': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN subjectName TEXT DEFAULT ''",
      'subjectRole': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN subjectRole TEXT DEFAULT ''",
      'goalDescription': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN goalDescription TEXT DEFAULT ''",
      'goal': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN goal TEXT DEFAULT ''",
      'goalStatus': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN goalStatus TEXT DEFAULT 'open'",
      'createdAt': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN createdAt TEXT DEFAULT ''",
      'updatedAt': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN updatedAt TEXT DEFAULT ''",
      'syncStatus': "ALTER TABLE mgysd_care_plan_goal ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'",
    };

    for (final entry in goalColumns.entries) {
      await _safeAddColumn(db, 'mgysd_care_plan_goal', entry.key, entry.value);
    }

    final serviceColumns = <String, String>{
      'carePlanId': "ALTER TABLE mgysd_service_provision ADD COLUMN carePlanId TEXT DEFAULT ''",
      'socialInvestigationId': "ALTER TABLE mgysd_service_provision ADD COLUMN socialInvestigationId TEXT DEFAULT ''",
      'memberTei': "ALTER TABLE mgysd_service_provision ADD COLUMN memberTei TEXT DEFAULT ''",
      'goalId': "ALTER TABLE mgysd_service_provision ADD COLUMN goalId TEXT DEFAULT ''",
      'serviceProvided': "ALTER TABLE mgysd_service_provision ADD COLUMN serviceProvided TEXT DEFAULT ''",
      'provider': "ALTER TABLE mgysd_service_provision ADD COLUMN provider TEXT DEFAULT ''",
      'outcome': "ALTER TABLE mgysd_service_provision ADD COLUMN outcome TEXT DEFAULT ''",
      'goalStatus': "ALTER TABLE mgysd_service_provision ADD COLUMN goalStatus TEXT DEFAULT ''",
      'syncStatus': "ALTER TABLE mgysd_service_provision ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'",
    };

    for (final entry in serviceColumns.entries) {
      await _safeAddColumn(db, 'mgysd_service_provision', entry.key, entry.value);
    }
  }

  Future<int> _countGoalsForPlanAndTarget(
      Database db,
      String carePlanId,
      String targetTei,
      ) async {
    if (carePlanId.trim().isEmpty || targetTei.trim().isEmpty) return 0;

    try {
      final rows = await db.rawQuery(
        '''
        SELECT COUNT(*) AS countValue
        FROM mgysd_care_plan_goal
        WHERE carePlanId = ?
        AND (
          targetTei = ?
          OR subjectTei = ?
        )
        ''',
        [carePlanId, targetTei, targetTei],
      );
      return int.tryParse(_text(rows.first['countValue'])) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countServicesForPlanAndTarget(
      Database db,
      String carePlanId,
      String targetTei,
      ) async {
    if (carePlanId.trim().isEmpty || targetTei.trim().isEmpty) return 0;

    try {
      final rows = await db.rawQuery(
        '''
        SELECT COUNT(*) AS countValue
        FROM mgysd_service_provision
        WHERE carePlanId = ?
        AND memberTei = ?
        ''',
        [carePlanId, targetTei],
      );
      return int.tryParse(_text(rows.first['countValue'])) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _planLifecycleStatus(Map<String, Object?> row) {
    final lifecycle = _text(row['carePlanStatus']);
    if (lifecycle.isNotEmpty) return lifecycle.toUpperCase();

    // Backward compatibility for old rows created before carePlanStatus existed.
    // DRAFT/COMPLETED are form statuses, not lifecycle statuses, so they must
    // still be treated as ACTIVE unless explicitly SUPERSEDED/CANCELLED.
    final rawStatus = _text(row['status']).toUpperCase();
    if (rawStatus == 'SUPERSEDED' ||
        rawStatus == 'CANCELLED' ||
        rawStatus == 'INACTIVE') {
      return rawStatus;
    }
    return 'ACTIVE';
  }

  Future<void> _loadEverything() async {
    setState(() => _loading = true);

    try {
      final db = await _db();
      await _ensureTablesAndColumns(db);

      if (_householdTei.isEmpty || _targetTei.isEmpty) {
        if (!mounted) return;
        setState(() {
          _carePlans = [];
          _selectedPlan = null;
          _goals = [];
          _generalServices = [];
          _loading = false;
        });
        return;
      }

      var rows = await db.query(
        'mgysd_care_plan',
        where: 'householdTei = ?',
        whereArgs: [_householdTei],
        orderBy: 'updatedAt DESC',
      );

      // Safety cleanup for existing test data: keep only the latest ACTIVE plan.
      // Older active plans are kept as history and blocked from new services.
      final activeRows = rows.where((row) {
        final lifecycle = _planLifecycleStatus(row);
        return lifecycle.toUpperCase() == 'ACTIVE';
      }).toList();

      if (activeRows.length > 1) {
        activeRows.sort((a, b) {
          final ad = _text(a['updatedAt']).isNotEmpty ? _text(a['updatedAt']) : _text(a['createdAt']);
          final bd = _text(b['updatedAt']).isNotEmpty ? _text(b['updatedAt']) : _text(b['createdAt']);
          return bd.compareTo(ad);
        });

        final keepActiveId = _text(activeRows.first['id']);
        for (final oldPlan in activeRows.skip(1)) {
          final oldId = _text(oldPlan['id']);
          if (oldId.isEmpty || oldId == keepActiveId) continue;
          await db.update(
            'mgysd_care_plan',
            {
              'carePlanStatus': 'SUPERSEDED',
              'updatedAt': DateTime.now().toIso8601String(),
              'syncStatus': 'not-synced',
            },
            where: 'id = ?',
            whereArgs: [oldId],
          );
        }

        rows = await db.query(
          'mgysd_care_plan',
          where: 'householdTei = ?',
          whereArgs: [_householdTei],
          orderBy: 'updatedAt DESC',
        );
      }

      final plans = <_CarePlanRecord>[];
      for (final row in rows) {
        final id = _text(row['id']);
        if (id.isEmpty) continue;
        final status = _planLifecycleStatus(row);
        final goalsCount = await _countGoalsForPlanAndTarget(db, id, _targetTei);
        final servicesCount = await _countServicesForPlanAndTarget(db, id, _targetTei);

        plans.add(
          _CarePlanRecord(
            id: id,
            socialInvestigationId: _text(row['socialInvestigationId']),
            householdTei: _text(row['householdTei']),
            status: status,
            createdAt: _text(row['createdAt']),
            updatedAt: _text(row['updatedAt']),
            goalsForTarget: goalsCount,
            servicesForTarget: servicesCount,
          ),
        );
      }

      plans.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        final ad = a.updatedAt.isNotEmpty ? a.updatedAt : a.createdAt;
        final bd = b.updatedAt.isNotEmpty ? b.updatedAt : b.createdAt;
        return bd.compareTo(ad);
      });

      _CarePlanRecord? selected = _selectedPlan;
      if (selected == null || !plans.any((p) => p.id == selected!.id)) {
        selected = plans.isEmpty
            ? null
            : plans.firstWhere(
              (p) => p.isActive,
          orElse: () => plans.first,
        );
      }

      final loadedGoals = selected == null
          ? <_GoalWithServices>[]
          : await _loadGoalsForPlan(db, selected.id);

      final generalServices = selected == null
          ? <_ServiceRecord>[]
          : await _loadServicesForGoal(
        db: db,
        carePlanId: selected.id,
        goalId: '',
        targetTei: _targetTei,
      );

      if (!mounted) return;
      setState(() {
        _carePlans = plans;
        _selectedPlan = selected;
        _goals = loadedGoals;
        _generalServices = generalServices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Failed to load service provision: $e');
    }
  }

  Future<List<_GoalWithServices>> _loadGoalsForPlan(
      Database db,
      String carePlanId,
      ) async {
    if (carePlanId.trim().isEmpty || _targetTei.isEmpty) return [];

    final rows = await db.query(
      'mgysd_care_plan_goal',
      where: '''
        carePlanId = ?
        AND (
          targetTei = ?
          OR subjectTei = ?
        )
      ''',
      whereArgs: [carePlanId, _targetTei, _targetTei],
      orderBy: 'createdAt DESC',
    );

    final result = <_GoalWithServices>[];
    for (final row in rows) {
      final goal = _CareGoalRecord(
        id: _text(row['id']),
        carePlanId: _text(row['carePlanId']),
        socialInvestigationId: _text(row['socialInvestigationId']),
        term: _text(row['goalCategory']).isNotEmpty
            ? _text(row['goalCategory'])
            : _text(row['term']),
        targetTei: _text(row['targetTei']).isNotEmpty
            ? _text(row['targetTei'])
            : _text(row['subjectTei']),
        targetName: _text(row['targetName']).isNotEmpty
            ? _text(row['targetName'])
            : _text(row['subjectName']),
        targetRole: _text(row['targetRole']).isNotEmpty
            ? _text(row['targetRole'])
            : _text(row['subjectRole']),
        description: _text(row['goalDescription']).isNotEmpty
            ? _text(row['goalDescription'])
            : _text(row['goal']),
        status: _text(row['goalStatus']).isEmpty ? 'open' : _text(row['goalStatus']),
        createdAt: _text(row['createdAt']),
      );

      if (goal.id.isEmpty || goal.description.isEmpty) continue;
      final services = await _loadServicesForGoal(
        db: db,
        carePlanId: carePlanId,
        goalId: goal.id,
        targetTei: _targetTei,
      );
      result.add(_GoalWithServices(goal: goal, services: services));
    }

    return result;
  }

  Future<List<_ServiceRecord>> _loadServicesForGoal({
    required Database db,
    required String carePlanId,
    required String goalId,
    required String targetTei,
  }) async {
    if (!await _tableExists(db, 'mgysd_service_provision')) return [];

    final rows = await db.query(
      'mgysd_service_provision',
      where: 'carePlanId = ? AND memberTei = ? AND goalId = ?',
      whereArgs: [carePlanId, targetTei, goalId],
      orderBy: 'updatedAt DESC',
    );

    return rows.map((row) {
      Map<String, dynamic> payload = {};
      try {
        final raw = _text(row['payloadJson']);
        if (raw.isNotEmpty) payload = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}

      return _ServiceRecord(
        id: _text(row['id']),
        serviceDate: _text(row['serviceDate']),
        serviceProvided: _text(row['serviceProvided']).isNotEmpty
            ? _text(row['serviceProvided'])
            : _text(payload['serviceProvided']),
        provider: _text(row['provider']).isNotEmpty
            ? _text(row['provider'])
            : _text(payload['provider']),
        outcome: _text(row['outcome']).isNotEmpty
            ? _text(row['outcome'])
            : _text(payload['outcome']),
        goalStatus: _text(row['goalStatus']).isNotEmpty
            ? _text(row['goalStatus'])
            : _text(payload['goalStatus']),
        status: _text(row['status']),
        updatedAt: _text(row['updatedAt']),
      );
    }).toList();
  }

  Future<void> _selectPlan(_CarePlanRecord plan) async {
    setState(() {
      _selectedPlan = plan;
      _loading = true;
    });

    try {
      final db = await _db();
      final loadedGoals = await _loadGoalsForPlan(db, plan.id);
      final generalServices = await _loadServicesForGoal(
        db: db,
        carePlanId: plan.id,
        goalId: '',
        targetTei: _targetTei,
      );
      if (!mounted) return;
      setState(() {
        _goals = loadedGoals;
        _generalServices = generalServices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Failed to open care plan: $e');
    }
  }

  Future<void> _openServiceDialog({_CareGoalRecord? goal}) async {
    final selectedPlan = _selectedPlan;
    if (selectedPlan == null) {
      _showSnack('No care plan found for this household.');
      return;
    }

    if (!selectedPlan.isActive) {
      _showSnack('This care plan is not active. Services can only be added to the active care plan.');
      return;
    }

    if (goal != null && goal.isAchieved) {
      _showSnack('This goal has already been achieved.');
      return;
    }

    final serviceDate = TextEditingController(text: _today());
    final serviceProvided = TextEditingController();
    final provider = TextEditingController();
    final outcome = TextEditingController();
    final notes = TextEditingController();
    String goalStatus = goal == null ? 'in_progress' : _normaliseGoalStatus(goal.status);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final initial = DateTime.tryParse(serviceDate.text.trim()) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setSheetState(() => serviceDate.text = _formatDate(picked));
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: widget.color.withOpacity(0.12),
                              child: Icon(Icons.volunteer_activism_outlined, color: widget.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Provide Service',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                                  ),
                                  Text(
                                    goal == null ? 'General service for $_targetName' : goal.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.blueGrey, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: serviceDate,
                          readOnly: true,
                          onTap: pickDate,
                          decoration: const InputDecoration(
                            labelText: 'Service Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: serviceProvided,
                          maxLines: 3,
                          validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Required' : null,
                          decoration: const InputDecoration(
                            labelText: 'Service Provided',
                            hintText: 'Describe the service/support provided',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: provider,
                          decoration: const InputDecoration(
                            labelText: 'Provider',
                            hintText: 'Who provided the service?',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: outcome,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Outcome',
                            hintText: 'What changed after this service?',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: goalStatus,
                          isExpanded: true,
                          items: _goalStatusOptions.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['value'],
                              child: Text(item['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => goalStatus = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Goal status after service',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: notes,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.color,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _saving
                                ? null
                                : () async {
                              if (!formKey.currentState!.validate()) return;
                              await _saveService(
                                carePlan: selectedPlan,
                                goal: goal,
                                serviceDate: serviceDate.text.trim(),
                                serviceProvided: serviceProvided.text.trim(),
                                provider: provider.text.trim(),
                                outcome: outcome.text.trim(),
                                notes: notes.text.trim(),
                                goalStatus: goalStatus,
                              );
                              if (mounted && Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Save Service'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    serviceDate.dispose();
    serviceProvided.dispose();
    provider.dispose();
    outcome.dispose();
    notes.dispose();
  }

  Future<void> _saveService({
    required _CarePlanRecord carePlan,
    required _CareGoalRecord? goal,
    required String serviceDate,
    required String serviceProvided,
    required String provider,
    required String outcome,
    required String notes,
    required String goalStatus,
  }) async {
    setState(() => _saving = true);

    try {
      final db = await _db();
      await _ensureTablesAndColumns(db);
      final nowIso = DateTime.now().toIso8601String();
      final eventId = _newDhis2Uid();
      final date = serviceDate.trim().isNotEmpty ? serviceDate.trim() : _today();

      await MgysdProgramStageEventHelper.saveProgramStageEvent(
        db: db,
        eventId: eventId,
        status: 'COMPLETED',
        eventDate: date,
      );

      final payload = {
        'id': eventId,
        'caseId': _caseRootId,
        'householdTei': _householdTei,
        'carePlanId': carePlan.id,
        'socialInvestigationId': carePlan.socialInvestigationId,
        'targetType': _isHouseholdTarget ? 'HOUSEHOLD' : 'MEMBER',
        'memberTei': _targetTei,
        'memberName': _targetName,
        'memberRole': _targetRole,
        'goalId': goal?.id ?? '',
        'goalDescription': goal?.description ?? '',
        'goalTerm': goal?.term ?? '',
        'serviceDate': date,
        'serviceProvided': serviceProvided,
        'provider': provider,
        'outcome': outcome,
        'notes': notes,
        'goalStatus': goalStatus,
        'updatedAt': nowIso,
      };

      await db.insert(
        'mgysd_service_provision',
        {
          'id': eventId,
          'caseId': _caseRootId,
          'householdTei': _householdTei,
          'carePlanId': carePlan.id,
          'socialInvestigationId': carePlan.socialInvestigationId,
          'memberTei': _targetTei,
          'goalId': goal?.id ?? '',
          'serviceDate': date,
          'serviceProvided': serviceProvided,
          'provider': provider,
          'outcome': outcome,
          'goalStatus': goalStatus,
          'status': 'COMPLETED',
          'payloadJson': jsonEncode(payload),
          'updatedAt': nowIso,
          'syncStatus': 'not-synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (goal != null) {
        await db.update(
          'mgysd_care_plan_goal',
          {
            'goalStatus': goalStatus,
            'updatedAt': nowIso,
            'syncStatus': 'not-synced',
          },
          where: 'id = ?',
          whereArgs: [goal.id],
        );
      }

      if (!mounted) return;
      _showSnack('Service saved.');
      await _loadEverything();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save service: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _chip(String label, {Color? color, bool strong = false}) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    final c = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(strong ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(strong ? 0.22 : 0.12)),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _surface({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: widget.color.withOpacity(0.12),
          child: Icon(icon, color: widget.color, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [widget.color, widget.color.withOpacity(0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      padding: const EdgeInsets.all(19),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.16),
            child: Icon(
              _isHouseholdTarget ? Icons.home_work_outlined : Icons.person_outline,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Provision',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _targetName.isEmpty ? widget.mgysdCase.caseNo : _targetName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _chip(_targetRole, color: Colors.white, strong: true),
                    if ((widget.householdName ?? '').trim().isNotEmpty)
                      _chip(widget.householdName!.trim(), color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCarePlans() {
    return _surface(
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 46, color: widget.color),
          const SizedBox(height: 10),
          const Text(
            'No care plans found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create or complete a Social Investigation first. The system will create a corresponding care plan for service provision.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _carePlanList() {
    if (_carePlans.isEmpty) return _emptyCarePlans();

    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Care Plan Records',
            'Latest active care plan is shown first. Old care plans are history and cannot receive new services.',
            Icons.assignment_outlined,
          ),
          const SizedBox(height: 13),
          ..._carePlans.map((plan) {
            final selected = _selectedPlan?.id == plan.id;
            final statusColor = plan.isActive ? Colors.green : Colors.blueGrey;
            final date = plan.updatedAt.isNotEmpty ? plan.updatedAt : plan.createdAt;

            return InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () => _selectPlan(plan),
              child: Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? widget.color.withOpacity(0.075)
                      : const Color(0xFFF9FBFD),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected
                        ? widget.color.withOpacity(0.32)
                        : Colors.blueGrey.withOpacity(0.10),
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: plan.id,
                      groupValue: _selectedPlan?.id,
                      activeColor: widget.color,
                      onChanged: (_) => _selectPlan(plan),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Care Plan ${_dateOnly(date).isEmpty ? plan.id : _dateOnly(date)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _chip(plan.status, color: statusColor, strong: plan.isActive),
                              _chip('${plan.goalsForTarget} goal${plan.goalsForTarget == 1 ? '' : 's'}', color: widget.color),
                              _chip('${plan.servicesForTarget} service${plan.servicesForTarget == 1 ? '' : 's'}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

/*  Widget _generalServiceCard() {
    final plan = _selectedPlan;
    if (plan == null) return const SizedBox.shrink();

    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'General Services',
            'Use this only when the service does not belong to a specific care-plan goal.',
            Icons.miscellaneous_services_outlined,
          ),
          const SizedBox(height: 12),
          if (_generalServices.isEmpty)
            const Text(
              'No general services recorded for this care plan and target.',
              style: TextStyle(color: Colors.blueGrey),
            )
          else
            ..._generalServices.map(_serviceTile),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: plan.isActive ? () => _openServiceDialog() : null,
              icon: const Icon(Icons.add),
              label: const Text('Add General Service'),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.color,
                side: BorderSide(color: widget.color.withOpacity(0.45)),
              ),
            ),
          ),
        ],
      ),
    );
  }*/

  Widget _goalsSection() {
    final plan = _selectedPlan;
    if (plan == null) return const SizedBox.shrink();

    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            _isHouseholdTarget ? 'Household Goals / Gaps' : 'Member Goals / Gaps',
            plan.isActive
                ? 'Provide services against the goals in the selected active care plan.'
                : 'This care plan is not active. It is read-only for service provision.',
            Icons.track_changes_outlined,
          ),
          const SizedBox(height: 13),
          if (_goals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.045),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'No goals/gaps in this care plan are linked to $_targetName.',
                style: const TextStyle(color: Colors.blueGrey, height: 1.35),
              ),
            )
          else
            ..._goals.map(_goalCard),
        ],
      ),
    );
  }

  Widget _goalCard(_GoalWithServices item) {
    final goal = item.goal;
    final statusColor = _goalStatusColor(goal.status);
    final canAddService = (_selectedPlan?.isActive ?? false) && !goal.isAchieved;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: goal.isAchieved
            ? Colors.green.withOpacity(0.035)
            : const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: goal.isAchieved
              ? Colors.green.withOpacity(0.16)
              : Colors.blueGrey.withOpacity(0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.11),
                child: Icon(Icons.flag_outlined, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _chip(goal.term, color: widget.color),
                        _chip(_goalStatusLabel(goal.status), color: statusColor, strong: goal.isAchieved),
                        _chip('${item.services.length} service${item.services.length == 1 ? '' : 's'}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (item.services.isEmpty)
            const Text(
              'No services recorded for this goal yet.',
              style: TextStyle(color: Colors.blueGrey),
            )
          else
            Column(children: item.services.map(_serviceTile).toList()),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: canAddService ? () => _openServiceDialog(goal: goal) : null,
              icon: const Icon(Icons.volunteer_activism_outlined, size: 17),
              label: Text(goal.isAchieved ? 'Achieved' : 'Provide Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceTile(_ServiceRecord service) {
    final statusColor = _goalStatusColor(service.goalStatus);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  service.serviceProvided.isEmpty
                      ? 'Service recorded'
                      : service.serviceProvided,
                  style: const TextStyle(fontWeight: FontWeight.w800, height: 1.3),
                ),
              ),
              if (service.serviceDate.isNotEmpty)
                _chip(_dateOnly(service.serviceDate), color: Colors.blueGrey),
            ],
          ),
          if (service.provider.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Provider: ${service.provider}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12.5),
            ),
          ],
          if (service.outcome.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Outcome: ${service.outcome}',
              style: const TextStyle(color: Colors.black87, fontSize: 12.7, height: 1.3),
            ),
          ],
          if (service.goalStatus.isNotEmpty) ...[
            const SizedBox(height: 7),
            _chip(_goalStatusLabel(service.goalStatus), color: statusColor),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() async => _loadEverything();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: widget.color,
        elevation: 0,
        title: const Text('Service Provision'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              _carePlanList(),
              _goalsSection(),
             // _generalServiceCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

