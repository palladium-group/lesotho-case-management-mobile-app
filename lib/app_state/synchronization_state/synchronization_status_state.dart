import 'package:flutter/foundation.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/event_offline/event_offline_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/tracked_entity_instance_offline/tracked_entity_instance_offline_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:sqflite/sqflite.dart';

class SynchronizationStatusState with ChangeNotifier {
  List<String> _unsyncedTeiReferences = [];
  List<String> get unsyncedTeiReferences => _unsyncedTeiReferences;

  int _unsyncedHouseholds = 0;
  int _unsyncedClients = 0;
  int _unsyncedRelationships = 0;
  int _unsyncedAssessments = 0;
  int _unsyncedInvestigations = 0;
  int _unsyncedCarePlans = 0;
  int _unsyncedServiceProvisions = 0;
  int _unsyncedReferrals = 0;
  int _unsyncedMonitoring = 0;
  int _unsyncedOtherEvents = 0;
  int _failedSyncRecords = 0;

  bool _isRefreshing = false;
  String _lastRefreshLabel = '';

  int get unsyncedHouseholds => _unsyncedHouseholds;
  int get unsyncedClients => _unsyncedClients;
  int get unsyncedRelationships => _unsyncedRelationships;
  int get unsyncedAssessments => _unsyncedAssessments;
  int get unsyncedInvestigations => _unsyncedInvestigations;
  int get unsyncedCarePlans => _unsyncedCarePlans;
  int get unsyncedServiceProvisions => _unsyncedServiceProvisions;
  int get unsyncedReferrals => _unsyncedReferrals;
  int get unsyncedMonitoring => _unsyncedMonitoring;
  int get unsyncedOtherEvents => _unsyncedOtherEvents;
  int get failedSyncRecords => _failedSyncRecords;

  bool get isRefreshing => _isRefreshing;
  String get lastRefreshLabel => _lastRefreshLabel;

  int get unsyncedForms =>
      _unsyncedAssessments +
          _unsyncedInvestigations +
          _unsyncedCarePlans +
          _unsyncedServiceProvisions +
          _unsyncedReferrals +
          _unsyncedMonitoring +
          _unsyncedOtherEvents;

  int get totalUnsynced =>
      _unsyncedHouseholds +
          _unsyncedClients +
          _unsyncedRelationships +
          unsyncedForms +
          _failedSyncRecords;

  bool get hasUnsyncedData => totalUnsynced > 0;

  static const List<String> _assessmentStages = [
    MgysdDhis2Uids.initialRiskAssessmentStage,
  ];

  static const List<String> _investigationStages = [
    MgysdDhis2Uids.socialInvestigationStage,
    MgysdDhis2Uids.enrolledsocialInvestigationStage,
  ];

  static const List<String> _carePlanStages = [
    MgysdDhis2Uids.carePlanStage,
  ];

  static const List<String> _serviceProvisionStages = [
    MgysdDhis2Uids.enrolledServiceProvisionStage,
  ];

  static const List<String> _referralStages = [
    MgysdDhis2Uids.referralStage,
  ];

  static const List<String> _monitoringStages = [
    MgysdDhis2Uids.assessedMonitoringStage,
    MgysdDhis2Uids.monitoringStage,
    MgysdDhis2Uids.familyMonitoringStage,
  ];

  Future<void> resetSyncStatusReferences() async {
    await refreshLncmisSyncCounts();
  }

  Future<void> refreshLncmisSyncCounts() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();

    try {
      await _refreshUnsyncedTeiReferences();

      final db = await OfflineDbProvider().db;
      if (db == null) {
        _resetCounts();
        return;
      }

      final teiTable = await _firstExistingTable(db, const [
        'tracked_entity_instance',
        'trackedEntityInstance',
        'tracked_entity_instances',
      ]);

      final eventTable = await _firstExistingTable(db, const [
        'events',
        'event',
        'tei_event',
      ]);

      final enrollmentTable = await _firstExistingTable(db, const [
        'enrollment',
        'enrollments',
        'tracked_entity_instance_enrollment',
      ]);

      final relationshipTable = await _firstExistingTable(db, const [
        'relationship',
        'relationships',
        'tracked_entity_instance_relationship',
      ]);

      _unsyncedHouseholds = teiTable == null
          ? 0
          : await _countUnsyncedTeisByType(
        db,
        teiTable,
        MgysdDhis2Uids.householdTrackedEntityType,
      );

      _unsyncedClients = teiTable == null
          ? 0
          : await _countUnsyncedTeisByType(
        db,
        teiTable,
        MgysdDhis2Uids.personTrackedEntityType,
      );

      if (enrollmentTable != null) {
        final programWhere = await _programWhere(
          db,
          enrollmentTable,
          const [
            MgysdDhis2Uids.assessedHouseholdsProgram,
            MgysdDhis2Uids.enrolledHouseholdsProgram,
          ],
        );

        final programArgs = <Object?>[
          MgysdDhis2Uids.assessedHouseholdsProgram,
          MgysdDhis2Uids.enrolledHouseholdsProgram,
        ];

        _unsyncedHouseholds += await _countUnsyncedRows(
          db,
          enrollmentTable,
          extraWhere: programWhere,
          extraArgs: programWhere == null ? const [] : programArgs,
        );

        final familyProgramWhere = await _programWhere(
          db,
          enrollmentTable,
          const [MgysdDhis2Uids.familyMemberTrackerProgram],
        );
        _unsyncedClients += await _countUnsyncedRows(
          db,
          enrollmentTable,
          extraWhere: familyProgramWhere,
          extraArgs: familyProgramWhere == null
              ? const []
              : const [MgysdDhis2Uids.familyMemberTrackerProgram],
        );
      }

      _unsyncedRelationships = relationshipTable == null
          ? 0
          : await _countUnsyncedRows(db, relationshipTable);

      if (eventTable == null) {
        _unsyncedAssessments = 0;
        _unsyncedInvestigations = 0;
        _unsyncedCarePlans = 0;
        _unsyncedServiceProvisions = 0;
        _unsyncedReferrals = 0;
        _unsyncedMonitoring = 0;
        _unsyncedOtherEvents = 0;
      } else {
        _unsyncedAssessments = await _countUnsyncedEventsByStages(
          db,
          eventTable,
          _assessmentStages,
        );

        _unsyncedInvestigations = await _countUnsyncedEventsByStages(
          db,
          eventTable,
          _investigationStages,
        );

        _unsyncedCarePlans = await _countUnsyncedEventsByStages(
          db,
          eventTable,
          _carePlanStages,
        );

        _unsyncedServiceProvisions = await _countUnsyncedEventsByStages(
          db,
          eventTable,
          _serviceProvisionStages,
        );

        _unsyncedReferrals = await _countUnsyncedEventsByStages(
          db,
          eventTable,
          _referralStages,
        );

        _unsyncedMonitoring = await _countUnsyncedEventsByStages(
          db,
          eventTable,
          _monitoringStages,
        );

        final categorized =
            _unsyncedAssessments +
                _unsyncedInvestigations +
                _unsyncedCarePlans +
                _unsyncedServiceProvisions +
                _unsyncedReferrals +
                _unsyncedMonitoring;

        final allUnsyncedEvents = await _countUnsyncedRows(db, eventTable);
        _unsyncedOtherEvents =
        allUnsyncedEvents > categorized ? allUnsyncedEvents - categorized : 0;
      }

      _failedSyncRecords = await _countFailedRecords(db, [
        if (teiTable != null) teiTable,
        if (eventTable != null) eventTable,
        if (enrollmentTable != null) enrollmentTable,
        if (relationshipTable != null) relationshipTable,
      ]);

      _lastRefreshLabel = _friendlyNow();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshUnsyncedTeiReferences() async {
    try {
      final teiWithUnsyncedEvents = await EventOfflineProvider()
          .getTrackedEntityInstanceReferenceByEventSyncStatus();

      final teiWithUnsyncedAttributes =
      await TrackedEntityInstanceOfflineProvider()
          .getTrackedEntitiyInstanceReferencesBySyncStatus();

      _unsyncedTeiReferences =
          (teiWithUnsyncedEvents + teiWithUnsyncedAttributes).toSet().toList();
    } catch (_) {
      _unsyncedTeiReferences = [];
    }
  }

  void _resetCounts() {
    _unsyncedHouseholds = 0;
    _unsyncedClients = 0;
    _unsyncedRelationships = 0;
    _unsyncedAssessments = 0;
    _unsyncedInvestigations = 0;
    _unsyncedCarePlans = 0;
    _unsyncedServiceProvisions = 0;
    _unsyncedReferrals = 0;
    _unsyncedMonitoring = 0;
    _unsyncedOtherEvents = 0;
    _failedSyncRecords = 0;
  }

  Future<String?> _firstExistingTable(
      Database db,
      List<String> tableNames,
      ) async {
    for (final table in tableNames) {
      if (await _tableExists(db, table)) return table;
    }
    return null;
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
      return rows.any((row) => '${row['name']}' == columnName);
    } catch (_) {
      return false;
    }
  }

  Future<String?> _firstExistingColumn(
      Database db,
      String tableName,
      List<String> columnNames,
      ) async {
    for (final column in columnNames) {
      if (await _columnExists(db, tableName, column)) return column;
    }
    return null;
  }

  Future<String?> _syncColumn(Database db, String tableName) {
    return _firstExistingColumn(db, tableName, const [
      'syncStatus',
      'sync_status',
      'synced',
      'isSynced',
      'is_synced',
      'dirty',
      'isDirty',
      'is_dirty',
      'uploadStatus',
      'upload_status',
    ]);
  }

  String _unsyncedCondition(String column) {
    return [
      '(',
      '$column IS NULL',
      "OR LOWER(CAST($column AS TEXT)) IN (",
      "'',",
      "'0',",
      "'false',",
      "'no',",
      "'n',",
      "'unsynced',",
      "'not_synced',",
      "'not-synced',",
      "'not synced',",
      "'pending',",
      "'pending_upload',",
      "'pending upload',",
      "'to_upload',",
      "'to upload',",
      "'dirty',",
      "'created',",
      "'updated',",
      "'error',",
      "'failed',",
      "'conflict'",
      ')',
      ')',
    ].join(' ');
  }

  String _failedCondition(String column) {
    return [
      "LOWER(CAST($column AS TEXT)) IN (",
      "'error',",
      "'failed',",
      "'conflict',",
      "'import_error',",
      "'import error',",
      "'sync_error',",
      "'sync error'",
      ')',
    ].join(' ');
  }

  Future<int> _safeRawCount(
      Database db,
      String sql, [
        List<Object?> args = const [],
      ]) async {
    try {
      final rows = await db.rawQuery(sql, args);
      if (rows.isEmpty) return 0;
      return int.tryParse('${rows.first['c'] ?? 0}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countUnsyncedRows(
      Database db,
      String tableName, {
        String? extraWhere,
        List<Object?> extraArgs = const [],
      }) async {
    final syncColumn = await _syncColumn(db, tableName);
    if (syncColumn == null) return 0;

    final whereParts = <String>[
      _unsyncedCondition(syncColumn),
      if ((extraWhere ?? '').trim().isNotEmpty) '($extraWhere)',
    ];

    return _safeRawCount(
      db,
      'SELECT COUNT(*) AS c FROM $tableName WHERE ${whereParts.join(' AND ')}',
      extraArgs,
    );
  }

  Future<int> _countUnsyncedTeisByType(
      Database db,
      String tableName,
      String trackedEntityType,
      ) async {
    final typeColumn = await _firstExistingColumn(db, tableName, const [
      'trackedEntityType',
      'tracked_entity_type',
      'trackedEntityTypeId',
      'tracked_entity_type_id',
    ]);

    if (typeColumn == null || trackedEntityType.trim().isEmpty) return 0;

    return _countUnsyncedRows(
      db,
      tableName,
      extraWhere: '$typeColumn = ?',
      extraArgs: [trackedEntityType],
    );
  }

  Future<String?> _programWhere(
      Database db,
      String tableName,
      List<String> programs,
      ) async {
    final programColumn = await _firstExistingColumn(db, tableName, const [
      'program',
      'programId',
      'program_id',
    ]);

    final validPrograms =
    programs.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    if (programColumn == null || validPrograms.isEmpty) return null;

    final placeholders = List.filled(validPrograms.length, '?').join(',');
    return '$programColumn IN ($placeholders)';
  }

  Future<int> _countUnsyncedEventsByStages(
      Database db,
      String tableName,
      List<String> stages,
      ) async {
    final stageColumn = await _firstExistingColumn(db, tableName, const [
      'programStage',
      'program_stage',
      'programStageId',
      'program_stage_id',
    ]);

    final validStages =
    stages.map((stage) => stage.trim()).where((stage) => stage.isNotEmpty).toList();

    if (stageColumn == null || validStages.isEmpty) return 0;

    final placeholders = List.filled(validStages.length, '?').join(',');

    return _countUnsyncedRows(
      db,
      tableName,
      extraWhere: '$stageColumn IN ($placeholders)',
      extraArgs: validStages,
    );
  }

  Future<int> _countFailedRecords(Database db, List<String> tableNames) async {
    int total = 0;

    for (final table in tableNames.toSet()) {
      final syncColumn = await _syncColumn(db, table);
      if (syncColumn == null) continue;

      total += await _safeRawCount(
        db,
        'SELECT COUNT(*) AS c FROM $table WHERE ${_failedCondition(syncColumn)}',
      );
    }

    return total;
  }

  String _friendlyNow() {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
