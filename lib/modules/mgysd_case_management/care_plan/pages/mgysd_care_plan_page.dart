import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:sqflite/sqflite.dart';

class MgysdCarePlanPage extends StatefulWidget {
  const MgysdCarePlanPage({
    Key? key,
    required this.color,
    required this.mgysdCase,
    this.householdTei,
    this.householdName,
    this.clientName,
    this.socialInvestigationId,
    this.socialInvestigationDate,
  }) : super(key: key);

  final Color color;
  final MgysdCase mgysdCase;
  final String? householdTei;
  final String? householdName;
  final String? clientName;

  /// New workflow link:
  /// One Care Plan belongs to one Social Investigation record.
  /// If this is not passed yet, we fall back to the case root id so old flows
  /// keep working while we update the rest of the app step by step.
  final String? socialInvestigationId;
  final String? socialInvestigationDate;

  @override
  State<MgysdCarePlanPage> createState() => _MgysdCarePlanPageState();
}

class _GoalSubject {
  final String id;
  final String tei;
  final String name;
  final String role;
  final bool isHousehold;

  const _GoalSubject({
    required this.id,
    required this.tei,
    required this.name,
    required this.role,
    required this.isHousehold,
  });

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (isHousehold) return 'Household';
    return '(No name)';
  }

  String get displayRole {
    if (role.trim().isNotEmpty) return role.trim();
    return isHousehold ? 'Household' : 'Household member';
  }
}

class _CareGoal {
  final String id;
  final String carePlanId;
  final String socialInvestigationId;
  final String goalGroup;
  final String term;
  final String subjectId;
  final String subjectTei;
  final String subjectName;
  final String subjectRole;
  final String goal;
  final String goalStatus;
  final String createdAt;

  const _CareGoal({
    required this.id,
    required this.carePlanId,
    required this.socialInvestigationId,
    required this.goalGroup,
    required this.term,
    required this.subjectId,
    required this.subjectTei,
    required this.subjectName,
    required this.subjectRole,
    required this.goal,
    required this.goalStatus,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carePlanId': carePlanId,
      'socialInvestigationId': socialInvestigationId,
      'goalGroup': goalGroup,
      'term': term,
      'subjectId': subjectId,
      'subjectTei': subjectTei,
      'subjectName': subjectName,
      'subjectRole': subjectRole,
      'goal': goal,
      'goalStatus': goalStatus,
      'createdAt': createdAt,
    };
  }

  static _CareGoal fromRow(Map<String, dynamic> row) {
    final rawGoalGroup =
    (row['goalGroup'] ?? row['ownerType'] ?? '').toString().trim();

    return _CareGoal(
      id: (row['id'] ?? '').toString(),
      carePlanId: (row['carePlanId'] ?? '').toString(),
      socialInvestigationId: (row['socialInvestigationId'] ?? '').toString(),
      goalGroup: rawGoalGroup.isEmpty ? 'SOCIAL_WORKER' : rawGoalGroup,
      term: (row['term'] ?? row['goalCategory'] ?? '').toString(),
      subjectId: (row['subjectId'] ?? '').toString(),
      subjectTei: (row['subjectTei'] ?? row['targetTei'] ?? '').toString(),
      subjectName: (row['subjectName'] ?? row['targetName'] ?? '').toString(),
      subjectRole: (row['subjectRole'] ?? '').toString(),
      goal: (row['goal'] ?? row['goalDescription'] ?? '').toString(),
      goalStatus: (row['goalStatus'] ?? 'open').toString(),
      createdAt: (row['createdAt'] ?? '').toString(),
    );
  }
}


class _DisagreementEntry {
  final TextEditingController fullNamesController = TextEditingController();
  final TextEditingController signatureController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController reasonsController = TextEditingController();

  _DisagreementEntry();

  factory _DisagreementEntry.fromJson(Map<String, dynamic> json) {
    final entry = _DisagreementEntry();
    entry.fullNamesController.text = (json['fullNames'] ?? '').toString();
    entry.signatureController.text = (json['signature'] ?? '').toString();
    entry.dateController.text = (json['date'] ?? '').toString();
    entry.reasonsController.text = (json['reasons'] ?? '').toString();
    return entry;
  }

  Map<String, dynamic> toJson() {
    return {
      'fullNames': fullNamesController.text.trim(),
      'signature': signatureController.text.trim(),
      'date': dateController.text.trim(),
      'reasons': reasonsController.text.trim(),
    };
  }

  bool get hasValue {
    return fullNamesController.text.trim().isNotEmpty ||
        signatureController.text.trim().isNotEmpty ||
        dateController.text.trim().isNotEmpty ||
        reasonsController.text.trim().isNotEmpty;
  }

  void dispose() {
    fullNamesController.dispose();
    signatureController.dispose();
    dateController.dispose();
    reasonsController.dispose();
  }
}

class _PlanParticipantEntry {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  String role = '';

  _PlanParticipantEntry();

  factory _PlanParticipantEntry.fromJson(Map<String, dynamic> json) {
    final entry = _PlanParticipantEntry();
    entry.firstNameController.text = (json['firstName'] ?? '').toString();
    entry.lastNameController.text = (json['lastName'] ?? '').toString();
    entry.role = (json['role'] ?? '').toString();
    return entry;
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'role': role.trim(),
    };
  }

  bool get hasValue {
    return firstNameController.text.trim().isNotEmpty ||
        lastNameController.text.trim().isNotEmpty ||
        role.trim().isNotEmpty;
  }

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
  }
}

class _MgysdCarePlanPageState extends State<MgysdCarePlanPage> {
  bool _loading = true;
  bool _saving = false;
  String _status = 'DRAFT';

  final Map<String, TextEditingController> _goalControllers = {};
  final Map<String, String> _selectedSubjectIds = {};

  final TextEditingController _agreedPlanActionController =
  TextEditingController();

  final List<_PlanParticipantEntry> _planParticipants = [
    _PlanParticipantEntry(),
  ];

  final List<_DisagreementEntry> _disagreementEntries = [
    _DisagreementEntry(),
  ];

  List<_GoalSubject> _subjects = [];
  List<_CareGoal> _allGoals = [];
  List<_CareGoal> _shortGoals = [];
  List<_CareGoal> _mediumGoals = [];
  List<_CareGoal> _longGoals = [];

  static const String goalGroupClient = 'CLIENT';
  static const String goalGroupParentGuardian = 'PARENT_GUARDIAN';
  static const String goalGroupSocialWorker = 'SOCIAL_WORKER';

  static const List<String> goalGroups = [
    goalGroupClient,
    goalGroupParentGuardian,
    goalGroupSocialWorker,
  ];

  static const List<String> goalTerms = [
    'SHORT_TERM',
    'MEDIUM_TERM',
    'LONG_TERM',
  ];

  static const String tableCarePlan = 'mgysd_care_plan';
  static const String tableCarePlanGoals = 'mgysd_care_plan_goal';

  static const String attFirstName = MgysdDhis2Uids.attFirstName;
  static const String attLastName = MgysdDhis2Uids.attLastName;
  static const String attPhone = MgysdDhis2Uids.attPhone;
  static const String attRelationshipToClient =
      MgysdDhis2Uids.attRelationshipToClient;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final controller in _goalControllers.values) {
      controller.dispose();
    }

    _agreedPlanActionController.dispose();

    for (final entry in _planParticipants) {
      entry.dispose();
    }

    for (final entry in _disagreementEntries) {
      entry.dispose();
    }

    super.dispose();
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

  String get _socialInvestigationId {
    final direct = (widget.socialInvestigationId ?? '').trim();
    if (direct.isNotEmpty) return direct;
    return _caseRootId;
  }

  String get _carePlanId => 'CP_$_socialInvestigationId';

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _nowIso() => DateTime.now().toIso8601String();

  String _prettyRole(String role) {
    switch (role.toUpperCase()) {
      case 'CLIENT':
        return 'Client';
      case 'MOTHER':
        return 'Mother';
      case 'FATHER':
        return 'Father';
      case 'CAREGIVER':
        return 'Caregiver';
      case 'PERSONAL_ASSISTANT':
        return 'Personal Assistant';
      case 'GUARDIAN':
        return 'Guardian';
      case 'HOUSEHOLD':
        return 'Household';
      case 'HOUSEHOLD_MEMBER':
        return 'Household Member';
      default:
        return role.replaceAll('_', ' ').trim();
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

  Future<void> _addColumnIfMissing(
      Database db,
      String table,
      String column,
      String sql,
      ) async {
    if (await _columnExists(db, table, column)) return;
    try {
      await db.execute(sql);
    } catch (_) {
      // Column may already exist from another migration.
    }
  }

  Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCarePlan (
        id TEXT PRIMARY KEY,
        caseId TEXT,
        householdTei TEXT,
        planDate TEXT,
        status TEXT,
        agreedPlanAction TEXT,
        personsInvolvedInPlanJson TEXT,
        disagreementDetailsJson TEXT,
        payloadJson TEXT,
        updatedAt TEXT,
        syncStatus TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCarePlanGoals (
        id TEXT PRIMARY KEY,
        carePlanId TEXT,
        socialInvestigationId TEXT,
        caseId TEXT,
        householdTei TEXT,
        goalGroup TEXT,
        term TEXT,
        subjectId TEXT,
        subjectTei TEXT,
        subjectName TEXT,
        subjectRole TEXT,
        goal TEXT,
        goalStatus TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT
      )
    ''');

    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'socialInvestigationId',
      "ALTER TABLE $tableCarePlan ADD COLUMN socialInvestigationId TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'carePlanId',
      "ALTER TABLE $tableCarePlan ADD COLUMN carePlanId TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'planDate',
      "ALTER TABLE $tableCarePlan ADD COLUMN planDate TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'syncStatus',
      "ALTER TABLE $tableCarePlan ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'carePlanStatus',
      "ALTER TABLE $tableCarePlan ADD COLUMN carePlanStatus TEXT DEFAULT 'ACTIVE'",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'createdAt',
      "ALTER TABLE $tableCarePlan ADD COLUMN createdAt TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'agreedPlanAction',
      "ALTER TABLE $tableCarePlan ADD COLUMN agreedPlanAction TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'personsInvolvedInPlanJson',
      "ALTER TABLE $tableCarePlan ADD COLUMN personsInvolvedInPlanJson TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      tableCarePlan,
      'disagreementDetailsJson',
      "ALTER TABLE $tableCarePlan ADD COLUMN disagreementDetailsJson TEXT DEFAULT ''",
    );

    final goalColumns = <String, String>{
      'carePlanId': "ALTER TABLE $tableCarePlanGoals ADD COLUMN carePlanId TEXT DEFAULT ''",
      'socialInvestigationId': "ALTER TABLE $tableCarePlanGoals ADD COLUMN socialInvestigationId TEXT DEFAULT ''",
      'caseId': "ALTER TABLE $tableCarePlanGoals ADD COLUMN caseId TEXT DEFAULT ''",
      'householdTei': "ALTER TABLE $tableCarePlanGoals ADD COLUMN householdTei TEXT DEFAULT ''",
      'goalGroup': "ALTER TABLE $tableCarePlanGoals ADD COLUMN goalGroup TEXT DEFAULT 'SOCIAL_WORKER'",
      'term': "ALTER TABLE $tableCarePlanGoals ADD COLUMN term TEXT DEFAULT ''",
      'subjectId': "ALTER TABLE $tableCarePlanGoals ADD COLUMN subjectId TEXT DEFAULT ''",
      'subjectTei': "ALTER TABLE $tableCarePlanGoals ADD COLUMN subjectTei TEXT DEFAULT ''",
      'subjectName': "ALTER TABLE $tableCarePlanGoals ADD COLUMN subjectName TEXT DEFAULT ''",
      'subjectRole': "ALTER TABLE $tableCarePlanGoals ADD COLUMN subjectRole TEXT DEFAULT ''",
      'goal': "ALTER TABLE $tableCarePlanGoals ADD COLUMN goal TEXT DEFAULT ''",
      'goalStatus': "ALTER TABLE $tableCarePlanGoals ADD COLUMN goalStatus TEXT DEFAULT 'open'",
      'createdAt': "ALTER TABLE $tableCarePlanGoals ADD COLUMN createdAt TEXT DEFAULT ''",
      'updatedAt': "ALTER TABLE $tableCarePlanGoals ADD COLUMN updatedAt TEXT DEFAULT ''",
      'syncStatus': "ALTER TABLE $tableCarePlanGoals ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'",
      // Compatibility with previous service-provision reader.
      'ownerType': "ALTER TABLE $tableCarePlanGoals ADD COLUMN ownerType TEXT DEFAULT 'SOCIAL_WORKER'",
      'goalCategory': "ALTER TABLE $tableCarePlanGoals ADD COLUMN goalCategory TEXT DEFAULT ''",
      'targetType': "ALTER TABLE $tableCarePlanGoals ADD COLUMN targetType TEXT DEFAULT ''",
      'targetTei': "ALTER TABLE $tableCarePlanGoals ADD COLUMN targetTei TEXT DEFAULT ''",
      'targetName': "ALTER TABLE $tableCarePlanGoals ADD COLUMN targetName TEXT DEFAULT ''",
      'goalDescription': "ALTER TABLE $tableCarePlanGoals ADD COLUMN goalDescription TEXT DEFAULT ''",
    };

    for (final entry in goalColumns.entries) {
      await _addColumnIfMissing(db, tableCarePlanGoals, entry.key, entry.value);
    }
  }

  Future<Map<String, String>> _attrs(Database db, String tei) async {
    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        columns: ['attribute', 'value'],
        where: 'trackedEntityInstance = ?',
        whereArgs: [tei],
      );

      final map = <String, String>{};
      for (final row in rows) {
        final key = (row['attribute'] ?? '').toString();
        final value = (row['value'] ?? '').toString();
        if (key.trim().isNotEmpty) map[key] = value;
      }
      return map;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String?> _resolveHouseholdTei(Database db) async {
    final direct = (widget.householdTei ?? '').trim();
    if (direct.isNotEmpty) return direct;

    try {
      final enrollmentRows = await db.query(
        'enrollment',
        columns: ['trackedEntityInstance'],
        where: 'enrollment = ?',
        whereArgs: [_caseRootId],
        limit: 1,
      );

      if (enrollmentRows.isNotEmpty) {
        final tei =
        (enrollmentRows.first['trackedEntityInstance'] ?? '').toString();
        if (tei.trim().isNotEmpty) {
          final helperRows = await db.query(
            'mgysd_household_member',
            columns: ['householdTei'],
            where: 'memberTei = ?',
            whereArgs: [tei],
            limit: 1,
          );

          if (helperRows.isNotEmpty) {
            final householdTei =
            (helperRows.first['householdTei'] ?? '').toString().trim();
            if (householdTei.isNotEmpty) return householdTei;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<List<_GoalSubject>> _loadSubjects(Database db) async {
    final householdTei = await _resolveHouseholdTei(db);
    final subjects = <_GoalSubject>[];

    if ((householdTei ?? '').trim().isNotEmpty) {
      subjects.add(
        _GoalSubject(
          id: 'HOUSEHOLD:${householdTei!}',
          tei: householdTei,
          name: (widget.householdName ?? '').trim().isNotEmpty
              ? widget.householdName!.trim()
              : 'Household',
          role: 'Household',
          isHousehold: true,
        ),
      );

      try {
        final rows = await db.query(
          'mgysd_household_member',
          where: 'householdTei = ?',
          whereArgs: [householdTei],
        );

        for (final row in rows) {
          final memberTei = (row['memberTei'] ?? '').toString().trim();
          if (memberTei.isEmpty) continue;

          final attrs = await _attrs(db, memberTei);
          final firstName = (attrs[attFirstName] ?? '').trim();
          final lastName = (attrs[attLastName] ?? '').trim();
          final fallbackRole = (row['memberRole'] ?? '').toString().trim();
          final relationship =
          (attrs[attRelationshipToClient] ?? fallbackRole).trim();
          final phone = (attrs[attPhone] ?? '').trim();
          final displayName = ('$firstName $lastName').trim();

          subjects.add(
            _GoalSubject(
              id: 'MEMBER:$memberTei',
              tei: memberTei,
              name: displayName.isNotEmpty
                  ? displayName
                  : phone.isNotEmpty
                  ? phone
                  : '(No name)',
              role: _prettyRole(
                relationship.isEmpty ? fallbackRole : relationship,
              ),
              isHousehold: false,
            ),
          );
        }
      } catch (_) {}
    }

    return subjects;
  }

  Future<void> _loadCarePlan(Database db) async {
    final rows = await db.query(
      tableCarePlan,
      where: 'id = ? OR carePlanId = ? OR socialInvestigationId = ?',
      whereArgs: [_carePlanId, _carePlanId, _socialInvestigationId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      _status = (rows.first['status'] ?? 'DRAFT').toString();

      final agreedPlanAction =
      (rows.first['agreedPlanAction'] ?? '').toString().trim();

      if (agreedPlanAction.isNotEmpty) {
        _agreedPlanActionController.text = agreedPlanAction;
      } else {
        final payloadJson = (rows.first['payloadJson'] ?? '').toString();

        if (payloadJson.trim().isNotEmpty) {
          try {
            final payload = jsonDecode(payloadJson);
            final savedAgreedPlanAction =
            (payload['agreedPlanAction'] ?? '').toString();

            if (savedAgreedPlanAction.trim().isNotEmpty) {
              _agreedPlanActionController.text =
                  savedAgreedPlanAction.trim();
            }
          } catch (_) {}
        }
      }

      final personsInvolvedInPlanJson =
      (rows.first['personsInvolvedInPlanJson'] ?? '').toString().trim();

      if (personsInvolvedInPlanJson.isNotEmpty) {
        _loadPlanParticipants(personsInvolvedInPlanJson);
      } else {
        final payloadJson = (rows.first['payloadJson'] ?? '').toString();

        if (payloadJson.trim().isNotEmpty) {
          try {
            final payload = jsonDecode(payloadJson);
            final savedPersonsInvolved =
            payload['personsInvolvedInMakingPlan'];

            if (savedPersonsInvolved is List) {
              _loadPlanParticipants(jsonEncode(savedPersonsInvolved));
            }
          } catch (_) {}
        }
      }

      final disagreementDetailsJson =
      (rows.first['disagreementDetailsJson'] ?? '').toString().trim();

      if (disagreementDetailsJson.isNotEmpty) {
        _loadDisagreementDetails(disagreementDetailsJson);
      } else {
        final payloadJson = (rows.first['payloadJson'] ?? '').toString();

        if (payloadJson.trim().isNotEmpty) {
          try {
            final payload = jsonDecode(payloadJson);
            final savedDisagreementDetails = payload['disagreementDetails'];

            if (savedDisagreementDetails is List) {
              _loadDisagreementDetails(jsonEncode(savedDisagreementDetails));
            }
          } catch (_) {}
        }
      }
    }

    final goalRows = await db.query(
      tableCarePlanGoals,
      where: 'carePlanId = ? OR socialInvestigationId = ?',
      whereArgs: [_carePlanId, _socialInvestigationId],
      orderBy: 'createdAt ASC',
    );

    final allGoals = goalRows.map(_CareGoal.fromRow).toList();
    _allGoals = allGoals;
    _shortGoals = allGoals.where((g) => g.term == 'SHORT_TERM').toList();
    _mediumGoals = allGoals.where((g) => g.term == 'MEDIUM_TERM').toList();
    _longGoals = allGoals.where((g) => g.term == 'LONG_TERM').toList();
  }

  Future<void> _init() async {
    try {
      final db = await _db();
      await _ensureTables(db);
      final subjects = await _loadSubjects(db);
      await _loadCarePlan(db);

      if (!mounted) return;

      setState(() {
        _subjects = subjects;
        if (_subjects.isNotEmpty) {
          _initialiseSelectedSubjects();
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Failed to load care plan: $e');
    }
  }

  _GoalSubject? _subjectById(String id) {
    for (final subject in _subjects) {
      if (subject.id == id) return subject;
    }
    return _subjects.isEmpty ? null : _subjects.first;
  }

  List<_CareGoal> _goalsByTerm(String term) {
    switch (term) {
      case 'SHORT_TERM':
        return _shortGoals;
      case 'MEDIUM_TERM':
        return _mediumGoals;
      case 'LONG_TERM':
        return _longGoals;
      default:
        return <_CareGoal>[];
    }
  }

  List<_CareGoal> _goalsByGroupAndTerm(String goalGroup, String term) {
    return _allGoals
        .where((goal) => goal.goalGroup == goalGroup && goal.term == term)
        .toList();
  }

  Future<void> _addGoal({
    required String goalGroup,
    required String term,
    required TextEditingController controller,
    required String selectedSubjectId,
  }) async {
    final goalText = controller.text.trim();

    if (goalText.isEmpty) {
      _showSnack('Please enter the goal before adding.');
      return;
    }

    final subject = _subjectById(selectedSubjectId);
    if (subject == null) {
      _showSnack('Please select who this goal is for.');
      return;
    }

    setState(() => _saving = true);

    try {
      final db = await _db();
      await _ensureTables(db);

      final id = _newId();
      final nowIso = _nowIso();
      final householdTei = (await _resolveHouseholdTei(db)) ?? '';

      final goal = _CareGoal(
        id: id,
        carePlanId: _carePlanId,
        socialInvestigationId: _socialInvestigationId,
        goalGroup: goalGroup,
        term: term,
        subjectId: subject.id,
        subjectTei: subject.tei,
        subjectName: subject.displayName,
        subjectRole: subject.displayRole,
        goal: goalText,
        goalStatus: 'open',
        createdAt: nowIso,
      );

      await db.insert(
        tableCarePlanGoals,
        {
          'id': goal.id,
          'carePlanId': goal.carePlanId,
          'socialInvestigationId': goal.socialInvestigationId,
          'caseId': _caseRootId,
          'householdTei': householdTei,
          'goalGroup': goal.goalGroup,
          'ownerType': goal.goalGroup,
          'term': goal.term,
          'goalCategory': goal.term,
          'subjectId': goal.subjectId,
          'subjectTei': goal.subjectTei,
          'subjectName': goal.subjectName,
          'subjectRole': goal.subjectRole,
          'targetType': subject.isHousehold ? 'HOUSEHOLD' : 'MEMBER',
          'targetTei': goal.subjectTei,
          'targetName': goal.subjectName,
          'goal': goal.goal,
          'goalDescription': goal.goal,
          'goalStatus': goal.goalStatus,
          'createdAt': goal.createdAt,
          'updatedAt': nowIso,
          'syncStatus': 'not-synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      controller.clear();
      await _loadCarePlan(db);
      await _saveCarePlanShell(db: db, status: _status);

      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Failed to add goal: $e');
    }
  }

  Future<void> _deleteGoal(_CareGoal goal) async {
    setState(() => _saving = true);

    try {
      final db = await _db();
      await db.delete(
        tableCarePlanGoals,
        where: 'id = ?',
        whereArgs: [goal.id],
      );

      await _loadCarePlan(db);
      await _saveCarePlanShell(db: db, status: _status);

      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Failed to delete goal: $e');
    }
  }

  Future<void> _saveCarePlanShell({
    required Database db,
    required String status,
  }) async {
    final householdTei = (await _resolveHouseholdTei(db)) ?? '';
    final nowIso = _nowIso();

    String lifecycleStatus = 'ACTIVE';
    String createdAt = nowIso;

    try {
      final existing = await db.query(
        tableCarePlan,
        where: 'id = ? OR carePlanId = ? OR socialInvestigationId = ?',
        whereArgs: [_carePlanId, _carePlanId, _socialInvestigationId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final row = existing.first;
        final existingLifecycle = (row['carePlanStatus'] ?? '').toString().trim();
        final existingCreatedAt = (row['createdAt'] ?? '').toString().trim();

        if (existingLifecycle.isNotEmpty) {
          lifecycleStatus = existingLifecycle;
        }
        if (existingCreatedAt.isNotEmpty) {
          createdAt = existingCreatedAt;
        }
      }
    } catch (_) {}

    if (lifecycleStatus.isEmpty ||
        lifecycleStatus == 'DRAFT' ||
        lifecycleStatus == 'COMPLETED') {
      lifecycleStatus = 'ACTIVE';
    }

    final payload = {
      'carePlanId': _carePlanId,
      'socialInvestigationId': _socialInvestigationId,
      'caseId': _caseRootId,
      'householdTei': householdTei,
      'householdName': widget.householdName,
      'clientName': widget.clientName,
      'status': status,
      'carePlanStatus': lifecycleStatus,
      'agreedPlanAction': _agreedPlanActionController.text.trim(),
      'personsInvolvedInMakingPlan': _planParticipantsPayload(),
      'disagreementDetails': _disagreementDetailsPayload(),
      'clientGoals': _payloadForGoalGroup(goalGroupClient),
      'parentGuardianGoals': _payloadForGoalGroup(goalGroupParentGuardian),
      'socialWorkerGoals': _payloadForGoalGroup(goalGroupSocialWorker),
      'updatedAt': nowIso,
    };

    await db.insert(
      tableCarePlan,
      {
        'id': _carePlanId,
        'carePlanId': _carePlanId,
        'socialInvestigationId': _socialInvestigationId,
        'caseId': _caseRootId,
        'householdTei': householdTei,
        'planDate': nowIso.substring(0, 10),
        'status': status,
        'carePlanStatus': lifecycleStatus,
        'agreedPlanAction': _agreedPlanActionController.text.trim(),
        'personsInvolvedInPlanJson': jsonEncode(_planParticipantsPayload()),
        'disagreementDetailsJson': jsonEncode(_disagreementDetailsPayload()),
        'payloadJson': jsonEncode(payload),
        'createdAt': createdAt,
        'updatedAt': nowIso,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);

    try {
      final db = await _db();
      await _ensureTables(db);
      await _saveCarePlanShell(db: db, status: 'DRAFT');

      if (!mounted) return;
      setState(() {
        _status = 'DRAFT';
        _saving = false;
      });
      _showSnack('Care plan draft saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Failed to save draft: $e');
    }
  }

  Future<void> _markComplete() async {
    if (_allGoals.isEmpty) {
      _showSnack('Please add at least one care plan goal.');
      return;
    }

    setState(() => _saving = true);

    try {
      final db = await _db();
      await _ensureTables(db);
      await _saveCarePlanShell(db: db, status: 'COMPLETED');

      if (!mounted) return;
      setState(() {
        _status = 'COMPLETED';
        _saving = false;
      });

      _showSnack('Care plan marked complete.');
      Navigator.pop(context, {
        'caseId': _caseRootId,
        'carePlanId': _carePlanId,
        'socialInvestigationId': _socialInvestigationId,
        'step': 'care_plan',
        'status': 'completed',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Failed to complete care plan: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _statusColor() {
    switch (_status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'DRAFT':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _termTitle(String term) {
    switch (term) {
      case 'SHORT_TERM':
        return 'Short term goals';
      case 'MEDIUM_TERM':
        return 'Medium term goals';
      case 'LONG_TERM':
        return 'Long term goals';
      default:
        return term;
    }
  }

  String _termSubtitle(String term) {
    switch (term) {
      case 'SHORT_TERM':
        return 'Immediate goals or gaps to address soon.';
      case 'MEDIUM_TERM':
        return 'Goals to support stabilisation and progress.';
      case 'LONG_TERM':
        return 'Long-term wellbeing, protection and self-sufficiency goals.';
      default:
        return '';
    }
  }

  String _goalKey(String goalGroup, String term) => '$goalGroup::$term';

  TextEditingController _controllerForGoal(String goalGroup, String term) {
    final key = _goalKey(goalGroup, term);
    return _goalControllers.putIfAbsent(key, () => TextEditingController());
  }

  String _selectedSubjectForGoal(String goalGroup, String term) {
    final key = _goalKey(goalGroup, term);
    final selected = _selectedSubjectIds[key] ?? '';

    if (_subjects.any((subject) => subject.id == selected)) {
      return selected;
    }

    final fallback = _defaultSubjectIdForGoalGroup(goalGroup);
    if (fallback.isNotEmpty) {
      _selectedSubjectIds[key] = fallback;
    }
    return fallback;
  }

  void _setSelectedSubjectForGoal(
      String goalGroup,
      String term,
      String value,
      ) {
    setState(() {
      _selectedSubjectIds[_goalKey(goalGroup, term)] = value;
    });
  }

  void _initialiseSelectedSubjects() {
    for (final goalGroup in goalGroups) {
      final fallback = _defaultSubjectIdForGoalGroup(goalGroup);
      for (final term in goalTerms) {
        _selectedSubjectIds.putIfAbsent(_goalKey(goalGroup, term), () => fallback);
      }
    }
  }

  String _defaultSubjectIdForGoalGroup(String goalGroup) {
    if (_subjects.isEmpty) return '';

    bool roleContains(_GoalSubject subject, List<String> values) {
      final role = subject.displayRole.toUpperCase();
      return values.any((value) => role.contains(value));
    }

    if (goalGroup == goalGroupClient) {
      for (final subject in _subjects) {
        if (roleContains(subject, ['CLIENT'])) return subject.id;
      }
      for (final subject in _subjects) {
        if (!subject.isHousehold) return subject.id;
      }
    }

    if (goalGroup == goalGroupParentGuardian) {
      for (final subject in _subjects) {
        if (roleContains(subject, [
          'PARENT',
          'GUARDIAN',
          'MOTHER',
          'FATHER',
          'CAREGIVER',
        ])) {
          return subject.id;
        }
      }
    }

    return _subjects.first.id;
  }

  Map<String, dynamic> _payloadForGoalGroup(String goalGroup) {
    return {
      'shortTerm': _goalsByGroupAndTerm(goalGroup, 'SHORT_TERM')
          .map((g) => g.toJson())
          .toList(),
      'mediumTerm': _goalsByGroupAndTerm(goalGroup, 'MEDIUM_TERM')
          .map((g) => g.toJson())
          .toList(),
      'longTerm': _goalsByGroupAndTerm(goalGroup, 'LONG_TERM')
          .map((g) => g.toJson())
          .toList(),
    };
  }


  List<Map<String, dynamic>> _planParticipantsPayload() {
    return _planParticipants
        .where((entry) => entry.hasValue)
        .map((entry) => entry.toJson())
        .toList();
  }

  void _loadPlanParticipants(String rawJson) {
    if (rawJson.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(rawJson);

      if (decoded is! List) return;

      final loadedEntries = decoded
          .whereType<Map>()
          .map(
            (entry) => _PlanParticipantEntry.fromJson(
          Map<String, dynamic>.from(entry),
        ),
      )
          .toList();

      if (loadedEntries.isEmpty) return;

      for (final entry in _planParticipants) {
        entry.dispose();
      }

      _planParticipants
        ..clear()
        ..addAll(loadedEntries);
    } catch (_) {}
  }

  void _addPlanParticipant() {
    setState(() {
      _planParticipants.add(_PlanParticipantEntry());
    });
  }

  void _removePlanParticipant(int index) {
    if (_planParticipants.length <= 1) return;

    setState(() {
      final removed = _planParticipants.removeAt(index);
      removed.dispose();
    });
  }

  List<Map<String, dynamic>> _disagreementDetailsPayload() {
    return _disagreementEntries
        .where((entry) => entry.hasValue)
        .map((entry) => entry.toJson())
        .toList();
  }

  void _loadDisagreementDetails(String rawJson) {
    if (rawJson.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(rawJson);

      if (decoded is! List) return;

      final loadedEntries = decoded
          .whereType<Map>()
          .map(
            (entry) => _DisagreementEntry.fromJson(
          Map<String, dynamic>.from(entry),
        ),
      )
          .toList();

      if (loadedEntries.isEmpty) return;

      for (final entry in _disagreementEntries) {
        entry.dispose();
      }

      _disagreementEntries
        ..clear()
        ..addAll(loadedEntries);
    } catch (_) {}
  }

  void _addDisagreementEntry() {
    setState(() {
      _disagreementEntries.add(_DisagreementEntry());
    });
  }

  void _removeDisagreementEntry(int index) {
    if (_disagreementEntries.length <= 1) return;

    setState(() {
      final removed = _disagreementEntries.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickDisagreementDate(_DisagreementEntry entry) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;

    entry.dateController.text =
    '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Widget _statusChip() {
    final color = _statusColor();
    final label = _status.toUpperCase() == 'COMPLETED'
        ? 'Completed'
        : _status.toUpperCase() == 'DRAFT'
        ? 'Draft'
        : _status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets? padding,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
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

  Widget _sectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: widget.color.withOpacity(0.11),
          child: Icon(icon, color: widget.color, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subjectDropdown({
    required String goalGroup,
    required String term,
  }) {
    final selected = _selectedSubjectForGoal(goalGroup, term);
    final safeValue = _subjects.any((subject) => subject.id == selected)
        ? selected
        : (_subjects.isEmpty ? null : _subjects.first.id);

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      items: _subjects.map((subject) {
        return DropdownMenuItem<String>(
          value: subject.id,
          child: Text(
            '${subject.displayName} • ${subject.displayRole}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        _setSelectedSubjectForGoal(goalGroup, term, value);
      },
      decoration: InputDecoration(
        labelText: 'Goal is for',
        prefixIcon: const Icon(Icons.person_search_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: const Color(0xFFF9FBFD),
      ),
    );
  }

  Widget _goalInputCard({
    required String goalGroup,
    required String term,
  }) {
    final controller = _controllerForGoal(goalGroup, term);
    final selectedSubject = _selectedSubjectForGoal(goalGroup, term);

    return _card(
      color: const Color(0xFFFBFCFE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subjectDropdown(goalGroup: goalGroup, term: term),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText:
              'Add ${_termTitle(term).toLowerCase().replaceAll('goals', 'goal')}',
              hintText: 'Describe the goal/gap to be addressed...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saving
                  ? null
                  : () => _addGoal(
                goalGroup: goalGroup,
                term: term,
                controller: controller,
                selectedSubjectId: selectedSubject,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add goal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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

  Widget _goalTile(_CareGoal goal) {
    final isHousehold = goal.subjectId.startsWith('HOUSEHOLD:');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHousehold
            ? widget.color.withOpacity(0.055)
            : Colors.blueGrey.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHousehold
              ? widget.color.withOpacity(0.16)
              : Colors.blueGrey.withOpacity(0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor:
            isHousehold ? widget.color.withOpacity(0.12) : Colors.white,
            child: Icon(
              isHousehold ? Icons.home_work_outlined : Icons.person_outline,
              color: isHousehold ? widget.color : Colors.blueGrey,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.subjectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  goal.subjectRole,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  goal.goal,
                  style: const TextStyle(
                    fontSize: 13.4,
                    height: 1.35,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove goal',
            onPressed: _saving ? null : () => _deleteGoal(goal),
            icon: const Icon(Icons.delete_outline),
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  String _goalGroupTitle(String goalGroup) {
    switch (goalGroup) {
      case goalGroupClient:
        return 'Client’s goals';
      case goalGroupParentGuardian:
        return 'Parent/Guardian goals (if appropriate)';
      case goalGroupSocialWorker:
        return 'Social worker goals';
      default:
        return goalGroup;
    }
  }

  String _goalGroupSubtitle(String goalGroup) {
    switch (goalGroup) {
      case goalGroupClient:
        return 'Goals agreed with or directly related to the client.';
      case goalGroupParentGuardian:
        return 'Goals for the parent, caregiver, or guardian where relevant.';
      case goalGroupSocialWorker:
        return 'Goals and actions planned by the social worker.';
      default:
        return '';
    }
  }

  IconData _goalGroupIcon(String goalGroup) {
    switch (goalGroup) {
      case goalGroupClient:
        return Icons.person_outline;
      case goalGroupParentGuardian:
        return Icons.groups_2_outlined;
      case goalGroupSocialWorker:
        return Icons.badge_outlined;
      default:
        return Icons.track_changes_outlined;
    }
  }

  Widget _goalTermSection({
    required String goalGroup,
    required String term,
  }) {
    final goals = _goalsByGroupAndTerm(goalGroup, term);

    return _card(
      color: const Color(0xFFFBFCFE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: _termTitle(term),
            subtitle: _termSubtitle(term),
            icon: term == 'SHORT_TERM'
                ? Icons.flash_on_outlined
                : term == 'MEDIUM_TERM'
                ? Icons.trending_up_outlined
                : Icons.flag_outlined,
          ),
          const SizedBox(height: 12),
          _goalInputCard(goalGroup: goalGroup, term: term),
          if (goals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.045),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No goals added yet.',
                style: TextStyle(color: Colors.blueGrey),
              ),
            )
          else
            Column(children: goals.map(_goalTile).toList()),
        ],
      ),
    );
  }

  Widget _goalGroupSection(String goalGroup) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: _goalGroupTitle(goalGroup),
            subtitle: _goalGroupSubtitle(goalGroup),
            icon: _goalGroupIcon(goalGroup),
          ),
          const SizedBox(height: 14),
          _goalTermSection(goalGroup: goalGroup, term: 'SHORT_TERM'),
          _goalTermSection(goalGroup: goalGroup, term: 'MEDIUM_TERM'),
          _goalTermSection(goalGroup: goalGroup, term: 'LONG_TERM'),
        ],
      ),
    );
  }


  Widget _agreedPlanActionSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Agreed plan of action (support plan - summary)',
            subtitle:
            'Give deliverables, milestone outcomes, and results for interval review.',
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _agreedPlanActionController,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: 'Agreed plan of action',
              hintText:
              'Give deliverables and milestone outcomes and results for interval review...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FBFD),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personsInvolvedInPlanSection() {
    const roleOptions = ['Mother', 'Father', 'Daughter'];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Persons involved in making the plan',
            subtitle: 'Record people who participated in making this care plan.',
            icon: Icons.people_alt_outlined,
          ),
          const SizedBox(height: 14),
          ..._planParticipants.asMap().entries.map((entryMap) {
            final index = entryMap.key;
            final entry = entryMap.value;
            final safeRole =
            roleOptions.contains(entry.role) ? entry.role : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFCFE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blueGrey.withOpacity(0.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Person ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: entry.lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: safeRole,
                    isExpanded: true,
                    items: roleOptions.map((role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        entry.role = value ?? '';
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Relationship to Client',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  if (_planParticipants.length > 1) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _removePlanParticipant(index),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          TextButton.icon(
            onPressed: _addPlanParticipant,
            icon: const Icon(Icons.add),
            label: const Text('Add another person'),
            style: TextButton.styleFrom(
              foregroundColor: widget.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _disagreementDetailsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Details of anyone who disagrees with the plan and why',
            subtitle:
            'Record the person, signature, date, and reasons for disagreement.',
            icon: Icons.report_problem_outlined,
          ),
          const SizedBox(height: 14),
          ..._disagreementEntries.asMap().entries.map((entryMap) {
            final index = entryMap.key;
            final entry = entryMap.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFCFE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blueGrey.withOpacity(0.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Person ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.fullNamesController,
                          decoration: InputDecoration(
                            labelText: 'First name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: entry.signatureController,
                          decoration: InputDecoration(
                            labelText: 'Last name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: entry.reasonsController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Reasons',
                      hintText:
                      'Explain why this person disagrees with the plan...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  if (_disagreementEntries.length > 1) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _removeDisagreementEntry(index),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          TextButton.icon(
            onPressed: _addDisagreementEntry,
            icon: const Icon(Icons.add),
            label: const Text('Add another person'),
            style: TextButton.styleFrom(
              foregroundColor: widget.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final title = (widget.clientName ?? '').trim().isNotEmpty
        ? widget.clientName!.trim()
        : widget.mgysdCase.fullName;

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
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      padding: const EdgeInsets.all(19),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white.withOpacity(0.16),
            child: const Icon(
              Icons.assignment_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Care Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((widget.householdName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.householdName!.trim(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Linked to investigation: $_socialInvestigationId',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          _statusChip(),
        ],
      ),
    );
  }

  Widget _emptySubjects() {
    return _card(
      child: Column(
        children: [
          Icon(Icons.groups_2_outlined, size: 44, color: widget.color),
          const SizedBox(height: 10),
          const Text(
            'No household members found',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Care plan goals need a household or household member. Please confirm that this case has household linkage.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _bottomButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color.withOpacity(0.45)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _markComplete,
            icon: _saving
                ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Saving...' : 'Mark Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalGoals = _allGoals.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Care Plan'),
        backgroundColor: widget.color,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _init,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              _card(
                child: Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        icon: Icons.track_changes_outlined,
                        label: 'Goals',
                        value: '$totalGoals',
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniStat(
                        icon: Icons.groups_outlined,
                        label: 'Selectable subjects',
                        value: '${_subjects.length}',
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              _card(
                color: Colors.amber.withOpacity(0.075),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This Care Plan is linked to a Social Investigation. Goals/gaps created here will feed Service Provision and Monitoring for the selected household member or household.',
                        style: TextStyle(
                          color: Colors.black87,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_subjects.isEmpty)
                _emptySubjects()
              else ...[
                _goalGroupSection(goalGroupClient),
                _goalGroupSection(goalGroupParentGuardian),
                _goalGroupSection(goalGroupSocialWorker),
                _agreedPlanActionSection(),
                _personsInvolvedInPlanSection(),
                _disagreementDetailsSection(),
              ],
              const SizedBox(height: 4),
              _bottomButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
