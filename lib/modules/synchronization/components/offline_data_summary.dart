import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/intervention_card_state/intervention_card_state.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/app_state/synchronization_state/synchronization_status_state.dart';
import 'package:lncmis_mobile_app/core/components/entry_form_save_button.dart';
import 'package:lncmis_mobile_app/core/components/material_card.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/synchronization/constants/synchronization_actions_constants.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

class OfflineSyncIssueItem {
  const OfflineSyncIssueItem({
    required this.label,
    required this.count,
    this.description = '',
    this.icon = Icons.description_outlined,
    this.color,
  });

  final String label;
  final int count;
  final String description;
  final IconData icon;
  final Color? color;
}

class _SpecificSyncIssue {
  const _SpecificSyncIssue({
    required this.title,
    required this.subtitle,
    required this.group,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String group;
  final IconData icon;
  final Color color;
}

class _SpecificSyncDetails {
  const _SpecificSyncDetails({
    required this.households,
    required this.clients,
    required this.forms,
    required this.failed,
    required this.generic,
    required this.checkedAt,
  });

  final List<_SpecificSyncIssue> households;
  final List<_SpecificSyncIssue> clients;
  final List<_SpecificSyncIssue> forms;
  final List<_SpecificSyncIssue> failed;
  final List<_SpecificSyncIssue> generic;
  final String checkedAt;

  int get total =>
      households.length + clients.length + forms.length + failed.length + generic.length;
}

class OfflineDataSummary extends StatefulWidget {
  const OfflineDataSummary({
    Key? key,
    required this.beneficiaryCount,
    required this.beneficiaryServiceCount,
    required this.onInitializeSyncAction,
    required this.syncAction,
    this.isSyncActive = false,
    this.unsyncedHouseholdCount,
    this.unsyncedClientCount,
    this.unsyncedFormCount,
    this.unsyncedAssessmentCount,
    this.unsyncedInvestigationCount,
    this.unsyncedCarePlanCount,
    this.unsyncedServiceProvisionCount,
    this.unsyncedReferralCount,
    this.unsyncedMonitoringCount,
    this.failedSyncCount,
    this.lastSyncLabel,
    this.issueItems = const [],
  }) : super(key: key);

  final int beneficiaryCount;
  final int beneficiaryServiceCount;
  final Function(String) onInitializeSyncAction;
  final String syncAction;
  final bool isSyncActive;

  final int? unsyncedHouseholdCount;
  final int? unsyncedClientCount;
  final int? unsyncedFormCount;
  final int? unsyncedAssessmentCount;
  final int? unsyncedInvestigationCount;
  final int? unsyncedCarePlanCount;
  final int? unsyncedServiceProvisionCount;
  final int? unsyncedReferralCount;
  final int? unsyncedMonitoringCount;
  final int? failedSyncCount;
  final String? lastSyncLabel;
  final List<OfflineSyncIssueItem> issueItems;

  @override
  State<OfflineDataSummary> createState() => _OfflineDataSummaryState();
}

class _OfflineDataSummaryState extends State<OfflineDataSummary> {
  late Future<_SpecificSyncDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadSpecificSyncDetails();

    Future.microtask(() {
      if (!mounted) return;
      try {
        context.read<SynchronizationStatusState>().refreshLncmisSyncCounts();
      } catch (_) {
        // Screen can still work with direct DB inspection.
      }
    });
  }

  @override
  void didUpdateWidget(covariant OfflineDataSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSyncActive != widget.isSyncActive) {
      _refreshSpecificDetails();
    }
  }

  Future<void> _refreshSpecificDetails() async {
    if (!mounted) return;
    setState(() {
      _detailsFuture = _loadSpecificSyncDetails();
    });

    try {
      context.read<SynchronizationStatusState>().refreshLncmisSyncCounts();
    } catch (_) {}
  }

  Future<Database?> _db() async {
    try {
      return await OfflineDbProvider().db;
    } catch (_) {
      return null;
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

  Future<String?> _firstExistingTable(
      Database db,
      List<String> tableNames,
      ) async {
    for (final table in tableNames) {
      if (await _tableExists(db, table)) return table;
    }
    return null;
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

  Future<List<Map<String, Object?>>> _safeQuery(
      Database db,
      String sql, [
        List<Object?> args = const [],
      ]) async {
    try {
      return await db.rawQuery(sql, args);
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }

  String _value(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  Future<Map<String, String>> _attributesForTei(
      Database db,
      String tei,
      ) async {
    if (tei.trim().isEmpty) return <String, String>{};

    final attrTable = await _firstExistingTable(db, const [
      'tracked_entity_instance_attribute',
      'trackedEntityInstanceAttribute',
      'tei_attribute',
    ]);

    if (attrTable == null) return <String, String>{};

    final teiColumn = await _firstExistingColumn(db, attrTable, const [
      'trackedEntityInstance',
      'tracked_entity_instance',
      'tei',
    ]);

    final attrColumn = await _firstExistingColumn(db, attrTable, const [
      'attribute',
      'trackedEntityAttribute',
      'tracked_entity_attribute',
    ]);

    final valueColumn = await _firstExistingColumn(db, attrTable, const [
      'value',
      'attributeValue',
      'attribute_value',
    ]);

    if (teiColumn == null || attrColumn == null || valueColumn == null) {
      return <String, String>{};
    }

    final rows = await _safeQuery(
      db,
      'SELECT $attrColumn AS a, $valueColumn AS v FROM $attrTable WHERE $teiColumn = ?',
      [tei],
    );

    final attrs = <String, String>{};
    for (final row in rows) {
      final key = (row['a'] ?? '').toString().trim();
      final value = (row['v'] ?? '').toString().trim();
      if (key.isNotEmpty) attrs[key] = value;
    }

    return attrs;
  }

  String _nameFromAttributes(Map<String, String> attrs) {
    final firstName = _firstNonEmpty([
      attrs[MgysdDhis2Uids.attFirstName] ?? '',
      attrs['ATTR_P_FIRSTNAME'] ?? '',
      attrs['firstName'] ?? '',
      attrs['first_name'] ?? '',
    ]);

    final surname = _firstNonEmpty([
      attrs[MgysdDhis2Uids.attLastName] ?? '',
      attrs['ATTR_P_LASTNAME'] ?? '',
      attrs['lastName'] ?? '',
      attrs['surname'] ?? '',
      attrs['last_name'] ?? '',
    ]);

    final fullName = '$firstName $surname'.trim();
    if (fullName.isNotEmpty) return fullName;

    return _firstNonEmpty([
      attrs['name'] ?? '',
      attrs['fullName'] ?? '',
      attrs['full_name'] ?? '',
    ]);
  }

  String _fileNumberFromAttributes(Map<String, String> attrs) {
    return _firstNonEmpty([
      attrs[MgysdDhis2Uids.attHouseholdFileNumber] ?? '',
      attrs['ATTR_HH_FILE_NUMBER'] ?? '',
      attrs['fileNumber'] ?? '',
      attrs['file_number'] ?? '',
    ]);
  }

  String _locationFromAttributes(Map<String, String> attrs) {
    final district = _firstNonEmpty([
      attrs[MgysdDhis2Uids.attHouseholdDistrict] ?? '',
      attrs['district'] ?? '',
    ]);

    final council = _firstNonEmpty([
      attrs[MgysdDhis2Uids.attHouseholdCommunityCouncil] ?? '',
      attrs['communityCouncil'] ?? '',
      attrs['community_council'] ?? '',
    ]);

    final village = _firstNonEmpty([
      attrs[MgysdDhis2Uids.attHouseholdVillage] ?? '',
      attrs['village'] ?? '',
    ]);

    return [
      district,
      council,
      village,
    ].where((item) => item.trim().isNotEmpty).join(' • ');
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty && value.trim().toLowerCase() != 'null') {
        return value.trim();
      }
    }
    return '';
  }

  String _stageLabel(String stage) {
    final s = stage.trim();

    const known = {
      'MGYSD_PS_INITIAL_RISK_ASSESSMENT': 'Initial Risk Assessment',
      'MGYSD_INITIAL_RISK_ASSESSMENT': 'Initial Risk Assessment',
      'MGYSD_PS_INTAKE': 'Intake',
      'MGYSD_PS_SOCIAL_INVESTIGATION': 'Social Investigation',
      'MGYSD_SOCIAL_INVESTIGATION': 'Social Investigation',
      'MGYSD_PS_CARE_PLAN': 'Care Plan',
      'MGYSD_CARE_PLAN': 'Care Plan',
      'MGYSD_PS_SERVICE_PROVISION': 'Service Provision',
      'MGYSD_FAMILY_PS_SERVICE_PROVISION': 'Family Service Provision',
      'MGYSD_SERVICE_PROVISION': 'Service Provision',
      'MGYSD_PS_REFERRAL': 'Referral',
      'MGYSD_FAMILY_PS_REFERRAL': 'Family Referral',
      'MGYSD_REFERRAL': 'Referral',
      'MGYSD_PS_MONITORING': 'Monitoring',
      'MGYSD_MONITORING': 'Monitoring',
    };

    if (known.containsKey(s)) return known[s]!;

    final lower = s.toLowerCase();
    if (lower.contains('investigation')) return 'Social Investigation';
    if (lower.contains('care') && lower.contains('plan')) return 'Care Plan';
    if (lower.contains('service')) return 'Service Provision';
    if (lower.contains('referral')) return 'Referral';
    if (lower.contains('monitor')) return 'Monitoring';
    if (lower.contains('risk') || lower.contains('intake')) {
      return 'Intake / Initial Assessment';
    }

    return s.isEmpty ? 'Unknown form' : s.replaceAll('_', ' ');
  }

  Color _stageColor(String stage) {
    final label = _stageLabel(stage).toLowerCase();
    if (label.contains('investigation')) return Colors.blue;
    if (label.contains('care')) return Colors.teal;
    if (label.contains('service')) return Colors.green;
    if (label.contains('referral')) return Colors.orange;
    if (label.contains('monitor')) return Colors.pink;
    if (label.contains('intake') || label.contains('assessment')) {
      return Colors.deepPurple;
    }
    return Colors.blueGrey;
  }

  IconData _stageIcon(String stage) {
    final label = _stageLabel(stage).toLowerCase();
    if (label.contains('investigation')) return Icons.manage_search_outlined;
    if (label.contains('care')) return Icons.assignment_outlined;
    if (label.contains('service')) return Icons.volunteer_activism_outlined;
    if (label.contains('referral')) return Icons.handshake_outlined;
    if (label.contains('monitor')) return Icons.monitor_heart_outlined;
    if (label.contains('intake') || label.contains('assessment')) {
      return Icons.fact_check_outlined;
    }
    return Icons.description_outlined;
  }

  Future<String> _teiDisplay(
      Database db,
      String tei, {
        String fallback = '',
      }) async {
    final attrs = await _attributesForTei(db, tei);

    final name = _nameFromAttributes(attrs);
    final fileNo = _fileNumberFromAttributes(attrs);
    final location = _locationFromAttributes(attrs);

    final parts = <String>[
      if (name.isNotEmpty) name,
      if (fileNo.isNotEmpty) 'File $fileNo',
      if (location.isNotEmpty) location,
    ];

    if (parts.isNotEmpty) return parts.join(' • ');
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return tei.trim().isEmpty ? 'Unknown record' : 'TEI $tei';
  }

  Future<_SpecificSyncDetails> _loadSpecificSyncDetails() async {
    final db = await _db();

    if (db == null) {
      return _SpecificSyncDetails(
        households: const [],
        clients: const [],
        forms: const [],
        failed: const [],
        generic: const [],
        checkedAt: _friendlyNow(),
      );
    }

    final households = <_SpecificSyncIssue>[];
    final clients = <_SpecificSyncIssue>[];
    final forms = <_SpecificSyncIssue>[];
    final failed = <_SpecificSyncIssue>[];
    final generic = <_SpecificSyncIssue>[];

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

    if (teiTable != null) {
      final syncColumn = await _syncColumn(db, teiTable);
      final teiColumn = await _firstExistingColumn(db, teiTable, const [
        'trackedEntityInstance',
        'tracked_entity_instance',
        'tei',
        'id',
      ]);
      final typeColumn = await _firstExistingColumn(db, teiTable, const [
        'trackedEntityType',
        'tracked_entity_type',
        'trackedEntityTypeId',
        'tracked_entity_type_id',
      ]);

      if (syncColumn != null && teiColumn != null) {
        final rows = await _safeQuery(
          db,
          'SELECT * FROM $teiTable WHERE ${_unsyncedCondition(syncColumn)} LIMIT 30',
        );

        for (final row in rows) {
          final tei = _value(row, [teiColumn, 'trackedEntityInstance', 'id']);
          final type = typeColumn == null ? '' : _value(row, [typeColumn]);
          final display = await _teiDisplay(db, tei);
          final isHousehold = type == MgysdDhis2Uids.householdTrackedEntityType ||
              type.toLowerCase().contains('household');

          final issue = _SpecificSyncIssue(
            title: isHousehold ? 'Household not uploaded' : 'Person not uploaded',
            subtitle: display,
            group: isHousehold ? 'Households' : 'People',
            icon: isHousehold ? Icons.home_work_outlined : Icons.person_outline,
            color: isHousehold ? Colors.indigo : Colors.blueGrey,
          );

          if (isHousehold) {
            households.add(issue);
          } else {
            clients.add(issue);
          }
        }
      }
    }

    if (enrollmentTable != null) {
      final syncColumn = await _syncColumn(db, enrollmentTable);
      final teiColumn = await _firstExistingColumn(db, enrollmentTable, const [
        'trackedEntityInstance',
        'tracked_entity_instance',
        'tei',
      ]);
      final enrollmentColumn = await _firstExistingColumn(db, enrollmentTable, const [
        'enrollment',
        'enrollmentId',
        'id',
      ]);
      final programColumn = await _firstExistingColumn(db, enrollmentTable, const [
        'program',
        'programId',
        'program_id',
      ]);

      if (syncColumn != null) {
        final rows = await _safeQuery(
          db,
          'SELECT * FROM $enrollmentTable WHERE ${_unsyncedCondition(syncColumn)} LIMIT 30',
        );

        for (final row in rows) {
          final tei = teiColumn == null ? '' : _value(row, [teiColumn]);
          final enrollment =
          enrollmentColumn == null ? '' : _value(row, [enrollmentColumn]);
          final program = programColumn == null ? '' : _value(row, [programColumn]);
          final display = await _teiDisplay(
            db,
            tei,
            fallback: enrollment.isEmpty ? 'Enrollment pending' : 'Enrollment $enrollment',
          );

          households.add(
            _SpecificSyncIssue(
              title: 'Enrollment not uploaded',
              subtitle: [
                display,
                if (program.isNotEmpty) 'Program: ${program.replaceAll('_', ' ')}',
              ].join(' • '),
              group: 'Households',
              icon: Icons.how_to_reg_outlined,
              color: Colors.deepPurple,
            ),
          );
        }
      }
    }

    if (eventTable != null) {
      final syncColumn = await _syncColumn(db, eventTable);
      final eventColumn = await _firstExistingColumn(db, eventTable, const [
        'event',
        'eventId',
        'id',
      ]);
      final teiColumn = await _firstExistingColumn(db, eventTable, const [
        'trackedEntityInstance',
        'tracked_entity_instance',
        'tei',
      ]);
      final stageColumn = await _firstExistingColumn(db, eventTable, const [
        'programStage',
        'program_stage',
        'programStageId',
        'program_stage_id',
      ]);
      final dateColumn = await _firstExistingColumn(db, eventTable, const [
        'eventDate',
        'event_date',
        'date',
        'created',
        'createdAt',
        'updatedAt',
      ]);

      if (syncColumn != null) {
        final rows = await _safeQuery(
          db,
          'SELECT * FROM $eventTable WHERE ${_unsyncedCondition(syncColumn)} LIMIT 60',
        );

        for (final row in rows) {
          final event = eventColumn == null ? '' : _value(row, [eventColumn]);
          final tei = teiColumn == null ? '' : _value(row, [teiColumn]);
          final stage = stageColumn == null ? '' : _value(row, [stageColumn]);
          final date = dateColumn == null ? '' : _value(row, [dateColumn]);
          final display = await _teiDisplay(
            db,
            tei,
            fallback: event.isEmpty ? 'Form event pending' : 'Event $event',
          );
          final label = _stageLabel(stage);

          forms.add(
            _SpecificSyncIssue(
              title: '$label did not sync',
              subtitle: [
                display,
                if (date.isNotEmpty) 'Date: $date',
                if (event.isNotEmpty) 'Event: $event',
              ].join(' • '),
              group: label,
              icon: _stageIcon(stage),
              color: _stageColor(stage),
            ),
          );

          final status = _value(row, [syncColumn]);
          final statusLower = status.toLowerCase();
          if (statusLower.contains('fail') ||
              statusLower.contains('error') ||
              statusLower.contains('conflict')) {
            failed.add(
              _SpecificSyncIssue(
                title: '$label failed last sync',
                subtitle: [
                  display,
                  if (event.isNotEmpty) 'Event: $event',
                  'Status: $status',
                ].join(' • '),
                group: 'Failed',
                icon: Icons.error_outline,
                color: Colors.redAccent,
              ),
            );
          }
        }
      }
    }

    if (relationshipTable != null) {
      final syncColumn = await _syncColumn(db, relationshipTable);
      if (syncColumn != null) {
        final rows = await _safeQuery(
          db,
          'SELECT * FROM $relationshipTable WHERE ${_unsyncedCondition(syncColumn)} LIMIT 20',
        );

        for (final row in rows) {
          final fromTei = _value(row, [
            'from',
            'fromTei',
            'from_tracked_entity_instance',
            'trackedEntityInstanceA',
          ]);
          final toTei = _value(row, [
            'to',
            'toTei',
            'to_tracked_entity_instance',
            'trackedEntityInstanceB',
          ]);

          final fromDisplay =
          fromTei.isEmpty ? '' : await _teiDisplay(db, fromTei);
          final toDisplay = toTei.isEmpty ? '' : await _teiDisplay(db, toTei);

          generic.add(
            _SpecificSyncIssue(
              title: 'Household relationship did not sync',
              subtitle: _firstNonEmpty([
                [
                  if (fromDisplay.isNotEmpty) fromDisplay,
                  if (toDisplay.isNotEmpty) toDisplay,
                ].join(' ↔ '),
                'Relationship record pending',
              ]),
              group: 'Relationships',
              icon: Icons.link_outlined,
              color: Colors.blueGrey,
            ),
          );
        }
      }
    }

    return _SpecificSyncDetails(
      households: households,
      clients: clients,
      forms: forms,
      failed: failed,
      generic: generic,
      checkedAt: _friendlyNow(),
    );
  }

  String _friendlyNow() {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  int _issueItemsTotal(List<OfflineSyncIssueItem> items) {
    return items.fold<int>(
      0,
          (total, item) => total + (item.count > 0 ? item.count : 0),
    );
  }

  void _onSyncButtonPress() {
    widget.onInitializeSyncAction(widget.syncAction);
  }

  String _buttonLabel(String lang) {
    if (widget.isSyncActive) {
      return lang == 'lesotho'
          ? 'Sync e ntse e sebetsa...'
          : 'Sync in progress...';
    }

    if (widget.syncAction == SynchronizationActionsConstants.download) {
      return lang == 'lesotho' ? 'Khoasolla data' : 'Download Data';
    }

    if (widget.syncAction == SynchronizationActionsConstants.downloadAndUpload) {
      return lang == 'lesotho'
          ? 'Khoasolla le ho Upload'
          : 'Download & Upload';
    }

    return lang == 'lesotho' ? 'Upload liphetoho' : 'Upload Changes';
  }

  Color _statusColor({
    required Color primaryColor,
    required int failedCount,
    required int totalPending,
  }) {
    if (failedCount > 0) return Colors.redAccent;
    if (totalPending > 0) return Colors.deepOrange;
    return Colors.green;
  }

  IconData _statusIcon({
    required bool isSyncActive,
    required int failedCount,
    required int totalPending,
  }) {
    if (isSyncActive) return Icons.sync;
    if (failedCount > 0) return Icons.error_outline;
    if (totalPending > 0) return Icons.cloud_upload_outlined;
    return Icons.cloud_done_outlined;
  }

  String _statusTitle({
    required String lang,
    required bool isSyncActive,
    required int failedCount,
    required int totalPending,
  }) {
    if (isSyncActive) {
      return lang == 'lesotho' ? 'Sync e ntse e sebetsa' : 'Sync running';
    }

    if (failedCount > 0) {
      return lang == 'lesotho'
          ? 'Ho na le sync e hlolehileng'
          : 'Some records failed to sync';
    }

    if (totalPending > 0) {
      return lang == 'lesotho'
          ? 'Data e emetse ho upload'
          : 'Data waiting to upload';
    }

    return lang == 'lesotho' ? 'Data e synced' : 'Everything is synced';
  }

  String _message({
    required String lang,
    required bool isSyncActive,
    required int failedCount,
    required int totalPending,
    required int detailsTotal,
  }) {
    if (isSyncActive) {
      return lang == 'lesotho'
          ? 'Data e ntse e romelloa kapa e khoasolloa. Ka kopo se koale app.'
          : 'Data is being uploaded or downloaded. Please keep the app open until it finishes.';
    }

    if (totalPending == 0) {
      return lang == 'lesotho'
          ? 'Ha ho liphetoho tse fumanoeng fonong ena tse emetseng ho romelloa.'
          : 'No pending local changes were detected on this device.';
    }

    if (failedCount > 0) {
      return lang == 'lesotho'
          ? 'Lintho tse ling li hlolehile ho sync. Lintlha tse ka tlase li bontša hore na ke record efe.'
          : 'Some records struggled to sync. The list below shows the household, person or form affected.';
    }

    if (detailsTotal > 0) {
      return lang == 'lesotho'
          ? 'Lintlha tse ka tlase li bontša hore na ke case kapa form efe e emetseng sync.'
          : 'The list below shows the exact household, person or form waiting to sync.';
    }

    return lang == 'lesotho'
        ? 'Ho na le data e emetseng sync, empa lintlha tsa record ha li fumanehe.'
        : 'There is pending data, but exact record details are not available yet.';
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.075),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 11.2,
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

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.14)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No pending uploads detected. If you recently saved a case, refresh the sync screen or try sync again.',
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specificIssueTile(_SpecificSyncIssue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: issue.color.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(issue.icon, color: issue.color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.9,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  issue.subtitle.trim().isEmpty
                      ? 'Record details not available'
                      : issue.subtitle.trim(),
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                    fontSize: 11.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specificGroup({
    required String title,
    required List<_SpecificSyncIssue> items,
    required Color color,
    required IconData icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.14)),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          leading: Icon(icon, color: color, size: 20),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            '${items.length} record${items.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
          children: items.map(_specificIssueTile).toList(),
        ),
      ),
    );
  }

  Widget _legacyIssueItem(OfflineSyncIssueItem item) {
    if (item.count <= 0) return const SizedBox.shrink();
    final color = item.color ?? Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              item.description.trim().isEmpty
                  ? item.label
                  : '${item.label}\n${item.description}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey,
                height: 1.3,
                fontSize: 12.2,
              ),
            ),
          ),
          Text(
            '${item.count}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _detailsList({
    required _SpecificSyncDetails details,
    required int totalPending,
    required int genericCount,
  }) {
    if (totalPending == 0) return _emptyState();

    final hasSpecific = details.total > 0;

    if (!hasSpecific && widget.issueItems.isEmpty && genericCount > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.055),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
        ),
        child: Text(
          '$genericCount local record${genericCount == 1 ? '' : 's'} detected by the sync engine. Exact household/form details could not be read from the offline tables yet.',
          style: const TextStyle(
            color: Colors.blueGrey,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      );
    }

    return Column(
      children: [
        _specificGroup(
          title: 'Households / enrollments',
          items: details.households,
          color: Colors.deepPurple,
          icon: Icons.home_work_outlined,
        ),
        _specificGroup(
          title: 'People / family members',
          items: details.clients,
          color: Colors.indigo,
          icon: Icons.groups_2_outlined,
        ),
        _specificGroup(
          title: 'Forms and program stages',
          items: details.forms,
          color: Colors.deepOrange,
          icon: Icons.description_outlined,
        ),
        _specificGroup(
          title: 'Failed records',
          items: details.failed,
          color: Colors.redAccent,
          icon: Icons.error_outline,
        ),
        _specificGroup(
          title: 'Relationships / other records',
          items: details.generic,
          color: Colors.blueGrey,
          icon: Icons.link_outlined,
        ),
        ...widget.issueItems.map(_legacyIssueItem),
      ],
    );
  }

  Widget _tipBox({
    required int failedCount,
    required int genericCount,
    required int totalPending,
  }) {
    String text;

    if (failedCount > 0) {
      text =
      'Tip: Open App Logs after syncing. Failed records usually come from missing TEI/enrollment links, invalid program stage, missing required DHIS2 fields, or server validation errors.';
    } else if (totalPending > 0) {
      text =
      'Tip: Upload before logging out or changing devices. Records saved offline remain only on this phone until sync succeeds.';
    } else {
      text =
      'Tip: You can still download data to refresh households, forms, users and metadata from the server.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            size: 18,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w600,
                fontSize: 11.8,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _manualOrProvider({
    required int? manual,
    required int provider,
  }) {
    return manual ?? provider;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LanguageTranslationState, SynchronizationStatusState>(
      builder: (context, languageState, syncStatusState, child) {
        final primaryColor =
            Provider.of<InterventionCardState>(context, listen: false)
                .currentInterventionProgram
                .primaryColor ??
                Theme.of(context).primaryColor;

        return FutureBuilder<_SpecificSyncDetails>(
          future: _detailsFuture,
          builder: (context, detailsSnapshot) {
            final details = detailsSnapshot.data ??
                _SpecificSyncDetails(
                  households: const [],
                  clients: const [],
                  forms: const [],
                  failed: const [],
                  generic: const [],
                  checkedAt: '',
                );

            final householdCount = _manualOrProvider(
              manual: widget.unsyncedHouseholdCount,
              provider: syncStatusState.unsyncedHouseholds,
            );
            final clientCount = _manualOrProvider(
              manual: widget.unsyncedClientCount,
              provider: syncStatusState.unsyncedClients,
            );
            final failedCount = _manualOrProvider(
              manual: widget.failedSyncCount,
              provider: syncStatusState.failedSyncRecords,
            );

            final formCount = widget.unsyncedFormCount ??
                syncStatusState.unsyncedForms;

            final specificCount = details.total;
            final counterTotal = householdCount +
                clientCount +
                formCount +
                failedCount +
                _issueItemsTotal(widget.issueItems);

            final genericCount = specificCount == 0 && counterTotal == 0
                ? (widget.beneficiaryCount + widget.beneficiaryServiceCount)
                : 0;

            // SQLite-backed counters are authoritative after sync.
            // The detailed list can briefly hold the previous snapshot.
            final totalPending = counterTotal + genericCount;

            final statusColor = _statusColor(
              primaryColor: primaryColor,
              failedCount: failedCount + details.failed.length,
              totalPending: totalPending,
            );

            final bool enabledByAction =
            widget.syncAction == SynchronizationActionsConstants.upload
                ? totalPending > 0
                : true;

            final bool canPress = !widget.isSyncActive && enabledByAction;

            return MaterialCard(
              body: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.075),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: statusColor.withOpacity(0.16)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 23,
                            backgroundColor: statusColor.withOpacity(0.13),
                            child: widget.isSyncActive ||
                                syncStatusState.isRefreshing ||
                                detailsSnapshot.connectionState ==
                                    ConnectionState.waiting
                                ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: statusColor,
                              ),
                            )
                                : Icon(
                              _statusIcon(
                                isSyncActive: widget.isSyncActive,
                                failedCount: failedCount + details.failed.length,
                                totalPending: totalPending,
                              ),
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusTitle(
                                    lang: languageState.currentLanguage,
                                    isSyncActive: widget.isSyncActive,
                                    failedCount: failedCount + details.failed.length,
                                    totalPending: totalPending,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _message(
                                    lang: languageState.currentLanguage,
                                    isSyncActive: widget.isSyncActive,
                                    failedCount: failedCount + details.failed.length,
                                    totalPending: totalPending,
                                    detailsTotal: details.total,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    height: 1.32,
                                  ),
                                ),
                                if ((widget.lastSyncLabel ??
                                    syncStatusState.lastRefreshLabel ??
                                    details.checkedAt)
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Checked: ${(widget.lastSyncLabel ?? syncStatusState.lastRefreshLabel ?? details.checkedAt).trim()}',
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: syncStatusState.isRefreshing
                                ? null
                                : _refreshSpecificDetails,
                            icon: const Icon(Icons.refresh),
                            color: statusColor,
                            tooltip: 'Refresh details',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _metricCard(
                          label: 'Pending',
                          value: '$totalPending',
                          icon: Icons.pending_actions_outlined,
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        _metricCard(
                          label: 'Specific',
                          value: '${details.total}',
                          icon: Icons.manage_search_outlined,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _metricCard(
                          label: 'Failed',
                          value: '${failedCount + details.failed.length}',
                          icon: Icons.error_outline,
                          color: failedCount + details.failed.length > 0
                              ? Colors.redAccent
                              : Colors.blueGrey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Exactly what did not sync?',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _detailsList(
                      details: details,
                      totalPending: totalPending,
                      genericCount: genericCount,
                    ),
                    _tipBox(
                      failedCount: failedCount + details.failed.length,
                      genericCount: genericCount,
                      totalPending: totalPending,
                    ),
                    const SizedBox(height: 14),
                    EntryFormSaveButton(
                      marginLeft: 0,
                      marginRight: 0,
                      vertical: 6.0,
                      label: _buttonLabel(languageState.currentLanguage),
                      svgIconPath: 'assets/icons/sync.svg',
                      svgIconHeight: 15.0,
                      svgIconWidth: 15.0,
                      labelColor: Colors.white,
                      buttonColor: canPress
                          ? primaryColor
                          : Colors.blueGrey.withOpacity(0.45),
                      fontSize: 15.0,
                      onPressButton: canPress ? _onSyncButtonPress : null,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
