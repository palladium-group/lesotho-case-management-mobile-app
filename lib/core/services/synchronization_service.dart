// ============================
// SynchronizationService.dart
// ============================

import 'dart:convert';

import 'package:http/http.dart';
import 'package:lncmis_mobile_app/core/constants/app_logs_constants.dart';
import 'package:lncmis_mobile_app/core/constants/pagination.dart';
import 'package:lncmis_mobile_app/core/offline_db/app_logs_offline/app_logs_offline_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/enrollment_offline/enrollment_offline_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/event_offline/event_offline_data_value_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/event_offline/event_offline_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/tei_relationship_offline/tei_relationship_offline_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/tracked_entity_instance_offline/tracked_entity_instance_offline_attribute_provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/tracked_entity_instance_offline/tracked_entity_instance_offline_provider.dart';
import 'package:lncmis_mobile_app/core/services/http_service.dart';
import 'package:lncmis_mobile_app/core/services/local_notification_service.dart';
import 'package:lncmis_mobile_app/core/utils/form_util.dart';
import 'package:lncmis_mobile_app/core/utils/tracked_entity_instance_util.dart';
import 'package:lncmis_mobile_app/models/app_logs.dart';
import 'package:lncmis_mobile_app/models/current_user.dart';
import 'package:lncmis_mobile_app/models/enrollment.dart';
import 'package:lncmis_mobile_app/models/events.dart';
import 'package:lncmis_mobile_app/models/tei_relationship.dart';
import 'package:lncmis_mobile_app/models/tracked_entity_instance.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:sqflite/sqflite.dart';

class SynchronizationService {
  late HttpService httpClient;

  final List? programs;
  final List? orgUnitIds;

  final String offlineSyncStatus = 'not-synced';
  final String onlineSyncStatus = 'synced';

  String _lastEventSyncError = '';

  SynchronizationService(
      String? username,
      String? password,
      this.programs,
      this.orgUnitIds,
      ) {
    httpClient = HttpService(
      username: username,
      password: password,
    );
  }

  Future<List> getDataPaginationFilters(
      String url, {
        required Map<String, dynamic> queryParameters,
      }) async {
    List paginationFilter = [];
    try {
      Response response = await httpClient.httpGetPagination(
        url,
        queryParameters,
      );
      if (response.statusCode == 200) {
        Map<String, dynamic> pager = json.decode(response.body)['pager'];
        int pageTotal = pager['total'];
        int pageSize = 1000;
        int total = pageTotal >= pageSize ? pageTotal : pageSize;
        for (int page = 1; page <= (total / pageSize).ceil(); page++) {
          paginationFilter.add({
            "totalPages": "true",
            "page": "$page",
            "pageSize": "$pageSize",
          });
        }
      } else {
        String errorMessage = await _getHttpResponseAppLogs(response.body);
        if (errorMessage.isNotEmpty) {
          AppLogs log = AppLogs(
              type: AppLogsConstants.errorLogType, message: errorMessage);
          await AppLogsOfflineProvider().addLogs(log);
        }
      }
    } catch (error) {
      AppLogs log = AppLogs(
          type: AppLogsConstants.errorLogType,
          message: '(getDataPaginationFilters) ${error.toString()}');
      await AppLogsOfflineProvider().addLogs(log);
    }
    return paginationFilter;
  }

  Future<void> getAndSaveEventsFromServer(
      String? program,
      String? userOrgId,
      String lastSyncDate,
      ) async {
    try {
      var queryParameters = {
        "program": program,
        "orgUnit": userOrgId,
        "ouMode": "DESCENDANTS",
        "lastUpdatedStartDate": lastSyncDate,
      };
      List pageFilters = await getDataPaginationFilters(
        "api/events.json",
        queryParameters: queryParameters,
      );
      for (var pageFilter in pageFilters) {
        Map<String, String?> dataQueryParameters = {
          "fields":
          "event,program,programStage,trackedEntityInstance,enrollment,status,orgUnit,dataValues[dataElement,value,displayName],eventDate",
        };
        dataQueryParameters.addAll(queryParameters);
        dataQueryParameters.addAll(pageFilter);
        String newTrackedInstanceUrl = "api/events.json";
        Response response = await httpClient.httpGet(
          newTrackedInstanceUrl,
          queryParameters: dataQueryParameters,
        );
        if (response.statusCode == 200) {
          var responseData = json.decode(response.body);
          List<Events> events = responseData['events']
              ?.map<Events>((event) => Events().fromJson(event))
              ?.toList();
          saveEventsToOffline(events);
        } else {
          String errorMessage = await _getHttpResponseAppLogs(response.body);
          if (errorMessage.isNotEmpty) {
            AppLogs log = AppLogs(
                type: AppLogsConstants.errorLogType, message: errorMessage);
            await AppLogsOfflineProvider().addLogs(log);
          }
        }
      }
    } catch (error) {
      AppLogs log = AppLogs(
          type: AppLogsConstants.errorLogType, message: error.toString());
      await AppLogsOfflineProvider().addLogs(log);
      rethrow;
    }
  }


  Future<Map<String, String>> _downloadedAttributes(
      Database db,
      String tei,
      ) async {
    final values = <String, String>{};
    if (tei.trim().isEmpty) return values;
    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        columns: ['attribute', 'value'],
        where: 'trackedEntityInstance = ?',
        whereArgs: [tei.trim()],
      );
      for (final row in rows) {
        final attribute = (row['attribute'] ?? '').toString().trim();
        if (attribute.isEmpty) continue;
        values[attribute] = (row['value'] ?? '').toString();
      }
    } catch (_) {}
    return values;
  }

  Future<bool> _localTeiExists(Database db, String tei) async {
    if (tei.trim().isEmpty) return false;
    final rows = await db.query(
      'tracked_entity_instance',
      columns: ['trackedEntityInstance'],
      where: 'trackedEntityInstance = ?',
      whereArgs: [tei.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _downloadSingleTrackedEntity(String tei) async {
    final cleanTei = tei.trim();
    if (cleanTei.isEmpty) return;
    try {
      final response = await httpClient.httpGet(
        'api/trackedEntityInstances/$cleanTei.json',
        queryParameters: {
          'fields':
          'trackedEntityInstance,trackedEntityType,orgUnit,'
              'attributes[attribute,value,displayName],'
              'enrollments[enrollment,enrollmentDate,incidentDate,orgUnit,program,trackedEntityInstance,status],'
              'relationships[relationshipType,relationship,from[trackedEntityInstance[trackedEntityInstance]],to[trackedEntityInstance[trackedEntityInstance]]]',
        },
      );
      if (response.statusCode != 200) {
        await _addSyncLog(
          'MGYSD MEMBER DOWNLOAD [$cleanTei] ${response.statusCode}: ${response.body}',
        );
        return;
      }
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      await saveTeis({'trackedEntityInstances': [decoded]});
    } catch (error) {
      await _addSyncLog('MGYSD MEMBER DOWNLOAD ERROR [$cleanTei]: $error');
    }
  }

  Future<void> _downloadMissingLinkedMembers() async {
    final db = await OfflineDbProvider().db;
    if (db == null) return;
    final relationships = await db.query(
      'tei_relationships',
      columns: ['fromTei', 'toTei'],
      where: 'relationshipType = ?',
      whereArgs: [MgysdDhis2Uids.householdHasMemberRelationshipType],
    );
    final memberIds = <String>{};
    for (final row in relationships) {
      final member = (row['toTei'] ?? '').toString().trim();
      if (member.isNotEmpty) memberIds.add(member);
    }
    for (final memberTei in memberIds) {
      if (!await _localTeiExists(db, memberTei)) {
        await _downloadSingleTrackedEntity(memberTei);
      }
    }
  }

  Future<String> _downloadedMemberRole(Database db, String memberTei) async {
    final attrs = await _downloadedAttributes(db, memberTei);
    final hasNextOfKinMetadata =
        (attrs[MgysdDhis2Uids.attNextOfKinFirstName] ?? '').trim().isNotEmpty ||
            (attrs[MgysdDhis2Uids.attNextOfKinSurname] ?? '').trim().isNotEmpty ||
            (attrs[MgysdDhis2Uids.attNextOfKinPhysicalAddress] ?? '').trim().isNotEmpty ||
            (attrs[MgysdDhis2Uids.attNextOfKinRelationship] ?? '').trim().isNotEmpty;
    if (hasNextOfKinMetadata) return 'NEXT_OF_KIN';
    if ((attrs[MgysdDhis2Uids.attClientCategory] ?? '').trim().isNotEmpty) {
      return 'CLIENT';
    }
    return 'HOUSEHOLD_MEMBER';
  }

  Future<void> _rebuildMgysdHouseholdMemberLinks() async {
    final db = await OfflineDbProvider().db;
    if (db == null) return;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS mgysd_household_member ('
          'id TEXT PRIMARY KEY, householdTei TEXT, memberTei TEXT, '
          'memberRole TEXT, isPrimaryClient TEXT, syncStatus TEXT)',
    );
    final relationships = await db.query(
      'tei_relationships',
      columns: ['id', 'fromTei', 'toTei'],
      where: 'relationshipType = ?',
      whereArgs: [MgysdDhis2Uids.householdHasMemberRelationshipType],
    );
    for (final row in relationships) {
      final household = (row['fromTei'] ?? '').toString().trim();
      final member = (row['toTei'] ?? '').toString().trim();
      if (household.isEmpty || member.isEmpty) continue;
      final householdEnrollments = await db.query(
        'enrollment',
        columns: ['enrollment'],
        where: 'trackedEntityInstance = ? AND (program = ? OR program = ?)',
        whereArgs: [
          household,
          MgysdDhis2Uids.assessedHouseholdsProgram,
          MgysdDhis2Uids.enrolledHouseholdsProgram,
        ],
        limit: 1,
      );
      if (householdEnrollments.isEmpty) continue;
      final existing = await db.query(
        'mgysd_household_member',
        columns: ['id', 'memberRole', 'isPrimaryClient'],
        where: 'householdTei = ? AND memberTei = ?',
        whereArgs: [household, member],
        limit: 1,
      );
      var role = existing.isNotEmpty
          ? (existing.first['memberRole'] ?? '').toString().trim()
          : '';
      if (role.isEmpty || role == 'HOUSEHOLD_MEMBER') {
        role = await _downloadedMemberRole(db, member);
      }
      final values = <String, dynamic>{
        'householdTei': household,
        'memberTei': member,
        'memberRole': role,
        'isPrimaryClient': role == 'CLIENT' ? 'true' : 'false',
        'syncStatus': 'synced',
      };
      if (existing.isNotEmpty) {
        await db.update(
          'mgysd_household_member',
          values,
          where: 'householdTei = ? AND memberTei = ?',
          whereArgs: [household, member],
        );
      } else {
        final relationshipId = (row['id'] ?? '').toString().trim();
        await db.insert(
          'mgysd_household_member',
          {
            'id': relationshipId.isNotEmpty
                ? 'HHM_$relationshipId'
                : 'HHM_${household}_$member',
            ...values,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<Map<String, String>> _eventValues(Database db, String eventId) async {
    final values = <String, String>{};
    final rows = await db.query(
      'event_data_value',
      columns: ['dataElement', 'value'],
      where: 'event = ?',
      whereArgs: [eventId],
    );
    for (final row in rows) {
      final de = (row['dataElement'] ?? '').toString().trim();
      if (de.isEmpty) continue;
      values[de] = (row['value'] ?? '').toString();
    }
    return values;
  }

  Map<String, dynamic> _downloadedSocialInvestigationPayload({
    required Map<String, dynamic> event,
    required Map<String, String> values,
  }) {
    String v(String id) => values[id] ?? '';
    Map<String, dynamic> domain({
      String rating = '',
      String observations = '',
      String strengths = '',
      String challenges = '',
    }) => {
      'rating': rating,
      'ratingOther': '',
      'observations': observations,
      'strengths': strengths,
      'challenges': challenges,
    };

    return {
      'eventId': event['event'] ?? '',
      'parentCaseId': event['enrollment'] ?? '',
      'eventDate': event['eventDate'] ?? '',
      'status': event['status'] ?? '',
      'clientTei': '',
      'householdTei': event['trackedEntityInstance'] ?? '',
      'part1': {
        'socialWorkerFirstName': v(MgysdDhis2Uids.deSiFirstName),
        'socialWorkerSurname': v(MgysdDhis2Uids.deSiLastName),
        'socialWorkerPhone': v(MgysdDhis2Uids.deSiPhone),
        'supervisorFirstName': '',
        'supervisorSurname': '',
        'supervisorPhone': '',
        'householdSummary': <String, dynamic>{},
        'clientAndFamilySummary': <dynamic>[],
      },
      'supervisorReview': <String, dynamic>{},
      'part2': {
        'incidentPattern': v(MgysdDhis2Uids.deSiIncidentPattern),
        'specificIncidentDate': '',
        'ongoingStartDate': '',
        'incidentDistrict': v(MgysdDhis2Uids.deSiDistrict),
        'incidentCommunityCouncil': v(MgysdDhis2Uids.deSiCommunityCouncil),
        'village': v(MgysdDhis2Uids.deSiVillage),
        'notes': '',
      },
      'part3': {
        'changedSinceInitialAssessment': v(MgysdDhis2Uids.deSiAssessmentChanged),
        'changeReason': v(MgysdDhis2Uids.deSiChangeReason),
        'additionalObservations': v(MgysdDhis2Uids.deSiAdditionalObservations),
        'physicalHealth': domain(rating: v('t9MyIrxgRSz'), observations: v('oaDTx4J5EyB'), strengths: v('RCTqBWPBcI9'), challenges: v('PxvNJZWAcPD')),
        'emotionalHealth': domain(rating: v('fAuuUmTMvYg'), observations: v('o78KTEXhQiy'), strengths: v('YpARuE6Y2Pl'), challenges: v('bmdBWMDIXtQ')),
        'education': domain(rating: v('nf1lUdwfGL7'), observations: v('bIByy8RBVnQ'), strengths: v('b4wSLDq0vhM'), challenges: v('nWsaaSe1klU')),
        'behaviouralDevelopment': domain(observations: v('bKTTC1xxL3t'), strengths: v('dU3jIu08ryu'), challenges: v('IZ5DnHuu3pN')),
        'identity': domain(observations: v('Z0z38RYjy77'), strengths: v('PdrvYognd7y'), challenges: v('ZEAYs0Fnzvb')),
        'familyBackground': domain(rating: v('k0Ik2xJsHDl'), observations: v('XB7RLLQgU1F'), strengths: v('ysY9wKRU5fE'), challenges: v('a02A4U9BQQ0')),
        'caregiverWellbeing': domain(rating: v('mQayWci59n4'), observations: v('WqLgxEDZtfP'), challenges: v('SgB7LzfM3kt')),
        'extendedFamily': domain(rating: v('IByvTnQBrZ5'), observations: v('Ad7FrGPyNJF'), strengths: v('yxzYAjiktVi'), challenges: v('FE5I7XVQ2J3')),
        'parentSiblingRelationship': domain(rating: v('KeiF3aK0QNI'), observations: v('z69fmJ4GRHc'), strengths: v('CgoAckfgdUN'), challenges: v('ajrgDRw1rhN')),
        'peerRelationship': domain(observations: v('nS5KHNR8E91'), strengths: v('lrFCxTYisBG'), challenges: v('kqgvL8SfunA')),
        'alternativeCare': domain(observations: v('Ictu4p4iFND'), strengths: v('uzblliQBYz6'), challenges: v('C5pbISpAWry')),
        'housing': domain(rating: v('gBd1mT2jaaP'), observations: v('G9sfhJ6Ks1M'), strengths: v('ezeEaqAi3CF'), challenges: v('qygp5C0xDR8')),
        'socialInclusion': domain(rating: v('wkvOsAGK1iD'), observations: v('BzTphSnSjuK'), strengths: v('GHT32pRIRSJ'), challenges: v('wj0g8OuClZK')),
      },
      'part4': {
        'externalInformants': <dynamic>[],
        'caseConferences': <dynamic>[],
        'courtReports': <dynamic>[],
      },
    };
  }

  Future<void> _rebuildMgysdWorkflowRowsFromDownloadedEvents() async {
    final db = await OfflineDbProvider().db;
    if (db == null) return;
    await db.execute(
      "CREATE TABLE IF NOT EXISTS mgysd_initial_risk_assessment ("
          "id TEXT PRIMARY KEY, caseId TEXT, householdTei TEXT, assessmentDate TEXT, "
          "riskLevel TEXT, status TEXT, payloadJson TEXT, updatedAt TEXT, "
          "syncStatus TEXT DEFAULT 'not-synced')",
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS mgysd_social_investigation ("
          "id TEXT PRIMARY KEY, caseId TEXT, householdTei TEXT, investigationDate TEXT, "
          "status TEXT, payloadJson TEXT, updatedAt TEXT, parentCaseId TEXT DEFAULT '', "
          "rootCaseId TEXT DEFAULT '', stageKey TEXT DEFAULT 'social_investigation', "
          "syncStatus TEXT DEFAULT 'not-synced')",
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS mgysd_stage_event_context ("
          "eventId TEXT PRIMARY KEY, parentCaseId TEXT, stageKey TEXT, tableName TEXT, "
          "programStage TEXT, trackedEntityInstance TEXT, enrollment TEXT, householdTei TEXT, "
          "householdName TEXT, clientName TEXT, subjectName TEXT, subjectRole TEXT, "
          "createdAt TEXT, updatedAt TEXT)",
    );

    final eventRows = await db.query(
      'events',
      where: 'programStage IN (?, ?, ?)',
      whereArgs: [
        MgysdDhis2Uids.initialRiskAssessmentStage,
        MgysdDhis2Uids.socialInvestigationStage,
        MgysdDhis2Uids.enrolledsocialInvestigationStage,
      ],
    );
    final now = DateTime.now().toIso8601String();
    for (final raw in eventRows) {
      final event = Map<String, dynamic>.from(raw);
      final eventId = (event['event'] ?? '').toString().trim();
      final stage = (event['programStage'] ?? '').toString().trim();
      final household = (event['trackedEntityInstance'] ?? '').toString().trim();
      final enrollment = (event['enrollment'] ?? '').toString().trim();
      final eventDate = (event['eventDate'] ?? '').toString().trim();
      final status = (event['status'] ?? 'ACTIVE').toString().trim();
      if (eventId.isEmpty || household.isEmpty) continue;
      final values = await _eventValues(db, eventId);

      if (stage == MgysdDhis2Uids.initialRiskAssessmentStage) {
        final riskLevel = values[MgysdDhis2Uids.deRiskLevel] ?? '';
        await db.insert(
          'mgysd_initial_risk_assessment',
          {
            'id': eventId,
            'caseId': enrollment.isNotEmpty ? enrollment : household,
            'householdTei': household,
            'assessmentDate': eventDate,
            'riskLevel': riskLevel,
            'status': status,
            'payloadJson': json.encode({
              'eventId': eventId,
              'enrollment': enrollment,
              'householdTei': household,
              'eventDate': eventDate,
              'riskLevel': riskLevel,
              'dataValues': values,
            }),
            'updatedAt': now,
            'syncStatus': 'synced',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        continue;
      }

      if (stage != MgysdDhis2Uids.socialInvestigationStage &&
          stage != MgysdDhis2Uids.enrolledsocialInvestigationStage) {
        continue;
      }
      final payload = _downloadedSocialInvestigationPayload(event: event, values: values);
      await db.insert(
        'mgysd_social_investigation',
        {
          'id': eventId,
          'caseId': eventId,
          'parentCaseId': enrollment.isNotEmpty ? enrollment : household,
          'rootCaseId': enrollment.isNotEmpty ? enrollment : household,
          'householdTei': household,
          'investigationDate': eventDate,
          'stageKey': 'social_investigation',
          'status': status,
          'payloadJson': json.encode(payload),
          'syncStatus': 'synced',
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'mgysd_stage_event_context',
        {
          'eventId': eventId,
          'parentCaseId': enrollment.isNotEmpty ? enrollment : household,
          'stageKey': 'social_investigation',
          'tableName': 'mgysd_social_investigation',
          'programStage': stage,
          'trackedEntityInstance': household,
          'enrollment': enrollment,
          'householdTei': household,
          'householdName': '',
          'clientName': '',
          'subjectName': '',
          'subjectRole': 'Primary client',
          'createdAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }


  Map<String, String> _serverTeiAttributes(Map<String, dynamic> tei) {
    final result = <String, String>{};
    final attributes = tei['attributes'];
    if (attributes is! List) return result;

    for (final item in attributes) {
      if (item is! Map) continue;
      final attribute = (item['attribute'] ?? '').toString().trim();
      if (attribute.isEmpty) continue;
      result[attribute] = (item['value'] ?? '').toString();
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> searchMgysdHouseholds(
      CurrentUser currentUser,
      String searchText,
      ) async {
    final query = searchText.trim();
    if (query.isEmpty) return [];

    final programs = <String>[
      MgysdDhis2Uids.assessedHouseholdsProgram,
      MgysdDhis2Uids.enrolledHouseholdsProgram,
    ];

    final results = <String, Map<String, dynamic>>{};

    void addResult(
        Map<String, dynamic> tei, {
          String? program,
        }) {
      final teiId =
      (tei['trackedEntityInstance'] ?? '').toString().trim();
      if (teiId.isEmpty) return;

      final attrs = _serverTeiAttributes(tei);
      final existing = results[teiId];

      final programSet = <String>{
        ...((existing?['programs'] as List?) ?? const <dynamic>[])
            .map((value) => value.toString()),
        if (program != null && program.trim().isNotEmpty) program.trim(),
      };

      final enrollments = tei['enrollments'];
      if (enrollments is List) {
        for (final item in enrollments) {
          if (item is! Map) continue;
          final enrolledProgram =
          (item['program'] ?? '').toString().trim();
          if (programs.contains(enrolledProgram)) {
            programSet.add(enrolledProgram);
          }
        }
      }

      results[teiId] = {
        'trackedEntityInstance': teiId,
        'orgUnit': (tei['orgUnit'] ?? '').toString(),
        'fileNumber':
        attrs[MgysdDhis2Uids.attHouseholdFileNumber] ?? '',
        'district':
        attrs[MgysdDhis2Uids.attHouseholdDistrict] ?? '',
        'communityCouncil':
        attrs[MgysdDhis2Uids.attHouseholdCommunityCouncil] ?? '',
        'village':
        attrs[MgysdDhis2Uids.attHouseholdVillage] ?? '',
        'address':
        attrs[MgysdDhis2Uids.attHouseholdAddress] ?? '',
        'programs': programSet.toList(),
      };
    }

    Future<void> searchEndpoint({
      required String program,
      String? textQuery,
      String? filter,
    }) async {
      try {
        final params = <String, dynamic>{
          'program': program,
          // ACCESSIBLE gives a true online/global search within the logged-in
          // user's DHIS2 data-capture scope. It does not require one local OU.
          'ouMode': 'ACCESSIBLE',
          'pageSize': '50',
          'fields':
          'trackedEntityInstance,trackedEntityType,orgUnit,'
              'attributes[attribute,value,displayName],'
              'enrollments[enrollment,program,status,orgUnit,enrollmentDate]',
        };

        if (textQuery != null && textQuery.trim().isNotEmpty) {
          params['query'] = textQuery.trim();
        }
        if (filter != null && filter.trim().isNotEmpty) {
          params['filter'] = filter.trim();
        }

        final response = await httpClient.httpGet(
          'api/trackedEntityInstances.json',
          queryParameters: params,
        );

        await _addSyncLog(
          'MGYSD INVESTIGATION ONLINE SEARCH '
              '[$program] ${response.statusCode}: ${response.body}',
        );

        if (response.statusCode != 200) return;

        final decoded = json.decode(response.body);
        if (decoded is! Map) return;

        final teis = decoded['trackedEntityInstances'];
        if (teis is! List) return;

        for (final raw in teis) {
          if (raw is! Map) continue;
          addResult(
            Map<String, dynamic>.from(raw),
            program: program,
          );
        }
      } catch (error) {
        await _addSyncLog(
          'MGYSD INVESTIGATION ONLINE SEARCH ERROR [$program]: $error',
        );
      }
    }

    // 1. Exact TEI UID.
    if (RegExp(r'^[A-Za-z][A-Za-z0-9]{10}$').hasMatch(query)) {
      try {
        final response = await httpClient.httpGet(
          'api/trackedEntityInstances/$query.json',
          queryParameters: {
            'fields':
            'trackedEntityInstance,trackedEntityType,orgUnit,'
                'attributes[attribute,value,displayName],'
                'enrollments[enrollment,program,status,orgUnit,enrollmentDate]',
          },
        );

        await _addSyncLog(
          'MGYSD INVESTIGATION UID SEARCH [$query] '
              '${response.statusCode}: ${response.body}',
        );

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            final enrollments = decoded['enrollments'];
            var householdProgram = '';
            if (enrollments is List) {
              for (final item in enrollments) {
                if (item is! Map) continue;
                final program =
                (item['program'] ?? '').toString().trim();
                if (programs.contains(program)) {
                  householdProgram = program;
                  break;
                }
              }
            }
            if (householdProgram.isNotEmpty) {
              addResult(decoded, program: householdProgram);
            }
          }
        }
      } catch (error) {
        await _addSyncLog(
          'MGYSD INVESTIGATION UID SEARCH ERROR [$query]: $error',
        );
      }
    }

    // 2. DHIS2's tracker text query. This searches searchable attributes.
    for (final program in programs) {
      await searchEndpoint(
        program: program,
        textQuery: query,
      );
    }

    // 3. Explicit attribute filters are the reliable fallback for household
    // file/location searches when the DHIS2 "query" endpoint has not indexed
    // those attributes as searchable.
    final searchableAttributes = <String>[
      MgysdDhis2Uids.attHouseholdFileNumber,
      MgysdDhis2Uids.attHouseholdDistrict,
      MgysdDhis2Uids.attHouseholdCommunityCouncil,
      MgysdDhis2Uids.attHouseholdVillage,
      MgysdDhis2Uids.attHouseholdAddress,
    ].where((uid) =>
        RegExp(r'^[A-Za-z][A-Za-z0-9]{10}$').hasMatch(uid.trim()))
        .toSet()
        .toList();

    for (final program in programs) {
      for (final attribute in searchableAttributes) {
        await searchEndpoint(
          program: program,
          filter: '$attribute:LIKE:$query',
        );
      }
    }

    final values = results.values.toList();

    String sortKey(Map<String, dynamic> item) {
      final file = (item['fileNumber'] ?? '').toString().trim();
      if (file.isNotEmpty) return file.toLowerCase();
      return (item['trackedEntityInstance'] ?? '')
          .toString()
          .toLowerCase();
    }

    values.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
    return values;
  }

  Future<int> _downloadEventsForSingleHousehold({
    required String program,
    required String householdTei,
  }) async {
    final response = await httpClient.httpGet(
      'api/events.json',
      queryParameters: {
        'program': program,
        'trackedEntityInstance': householdTei,
        'pageSize': '500',
        'fields':
        'event,program,programStage,trackedEntityInstance,enrollment,'
            'status,orgUnit,dataValues[dataElement,value,displayName],eventDate',
      },
    );

    await _addSyncLog(
      'MGYSD SINGLE HH EVENT DOWNLOAD '
          '[$householdTei][$program] ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode != 200) {
      return 0;
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) return 0;

    final rawEvents = decoded['events'];
    if (rawEvents is! List) return 0;

    final events = rawEvents
        .whereType<Map>()
        .map<Events>(
          (event) => Events().fromJson(
        Map<String, dynamic>.from(event),
      ),
    )
        .toList();

    if (events.isNotEmpty) {
      await saveEventsToOffline(events);
    }
    return events.length;
  }

  Future<Map<String, int>> downloadMgysdHouseholdBundle(
      String householdTei,
      ) async {
    final household = householdTei.trim();
    if (household.isEmpty) {
      throw ArgumentError('Household TEI is required.');
    }

    // 1. Download exactly the selected household.
    await _downloadSingleTrackedEntity(household);

    final db = await OfflineDbProvider().db;
    if (db == null) {
      throw StateError('Offline database is not available.');
    }

    // 2. Read only this household's relationships and download only its members.
    final relationships = await db.query(
      'tei_relationships',
      columns: ['toTei'],
      where: 'relationshipType = ? AND fromTei = ?',
      whereArgs: [
        MgysdDhis2Uids.householdHasMemberRelationshipType,
        household,
      ],
    );

    final memberIds = <String>{};
    for (final row in relationships) {
      final memberTei = (row['toTei'] ?? '').toString().trim();
      if (memberTei.isNotEmpty) memberIds.add(memberTei);
    }

    for (final memberTei in memberIds) {
      // Always refresh the selected household's linked member because this
      // action is an explicit user-requested download, not background sync.
      await _downloadSingleTrackedEntity(memberTei);
    }

    // 3. Download only this household's events from the two relevant programs.
    await _downloadEventsForSingleHousehold(
      program: MgysdDhis2Uids.assessedHouseholdsProgram,
      householdTei: household,
    );
    await _downloadEventsForSingleHousehold(
      program: MgysdDhis2Uids.enrolledHouseholdsProgram,
      householdTei: household,
    );

    // 4. Rebuild local helper structures used by the MGYSD screens.
    await _rebuildMgysdHouseholdMemberLinks();
    await _rebuildMgysdWorkflowRowsFromDownloadedEvents();

    // 5. Return counts scoped ONLY to this household.
    final linkedMembers = await db.rawQuery(
      'SELECT COUNT(DISTINCT memberTei) AS total '
          'FROM mgysd_household_member WHERE householdTei = ?',
      [household],
    );

    final initialRisk = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM events '
          'WHERE trackedEntityInstance = ? AND programStage = ?',
      [household, MgysdDhis2Uids.initialRiskAssessmentStage],
    );

    final investigations = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM events '
          'WHERE trackedEntityInstance = ? AND programStage IN (?, ?)',
      [
        household,
        MgysdDhis2Uids.socialInvestigationStage,
        MgysdDhis2Uids.enrolledsocialInvestigationStage,
      ],
    );

    final memberCount =
        (linkedMembers.first['total'] as int?) ?? 0;
    final initialRiskCount =
        (initialRisk.first['total'] as int?) ?? 0;
    final socialInvestigationCount =
        (investigations.first['total'] as int?) ?? 0;

    await _addSyncLog(
      'MGYSD SINGLE HOUSEHOLD DOWNLOAD COMPLETE: '
          'household=$household, members=$memberCount, '
          'initialRisk=$initialRiskCount, '
          'socialInvestigations=$socialInvestigationCount',
    );

    return {
      'households': 1,
      'members': memberCount,
      'initialRisk': initialRiskCount,
      'socialInvestigations': socialInvestigationCount,
    };
  }

  Future<Map<String, int>> downloadMgysdCaseManagementData(
      CurrentUser currentUser,
      String lastSyncDate,
      ) async {
    final orgUnits = (currentUser.userOrgUnitIds ?? [])
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    for (final orgUnit in orgUnits) {
      await getAndSaveTrackedInstanceFromServer(MgysdDhis2Uids.assessedHouseholdsProgram, orgUnit, lastSyncDate);
      await getAndSaveTrackedInstanceFromServer(MgysdDhis2Uids.enrolledHouseholdsProgram, orgUnit, lastSyncDate);
      await getAndSaveTrackedInstanceFromServer(MgysdDhis2Uids.familyMemberTrackerProgram, orgUnit, lastSyncDate);
      await getAndSaveEventsFromServer(MgysdDhis2Uids.assessedHouseholdsProgram, orgUnit, lastSyncDate);
      await getAndSaveEventsFromServer(MgysdDhis2Uids.enrolledHouseholdsProgram, orgUnit, lastSyncDate);
    }
    await _downloadMissingLinkedMembers();
    await _rebuildMgysdHouseholdMemberLinks();
    await _rebuildMgysdWorkflowRowsFromDownloadedEvents();

    var householdCount = 0;
    var memberCount = 0;
    var initialRiskCount = 0;
    var socialInvestigationCount = 0;
    final db = await OfflineDbProvider().db;
    if (db != null) {
      final households = await db.rawQuery(
        'SELECT COUNT(DISTINCT trackedEntityInstance) AS total FROM enrollment WHERE program IN (?, ?)',
        [MgysdDhis2Uids.assessedHouseholdsProgram, MgysdDhis2Uids.enrolledHouseholdsProgram],
      );
      householdCount = (households.first['total'] as int?) ?? 0;
      final members = await db.rawQuery('SELECT COUNT(DISTINCT memberTei) AS total FROM mgysd_household_member');
      memberCount = (members.first['total'] as int?) ?? 0;
      final risk = await db.rawQuery('SELECT COUNT(*) AS total FROM events WHERE programStage = ?', [MgysdDhis2Uids.initialRiskAssessmentStage]);
      initialRiskCount = (risk.first['total'] as int?) ?? 0;
      final investigations = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM events WHERE programStage IN (?, ?)',
        [MgysdDhis2Uids.socialInvestigationStage, MgysdDhis2Uids.enrolledsocialInvestigationStage],
      );
      socialInvestigationCount = (investigations.first['total'] as int?) ?? 0;
    }
    await _addSyncLog(
      'MGYSD DOWNLOAD COMPLETE: households=$householdCount, members=$memberCount, initialRisk=$initialRiskCount, socialInvestigations=$socialInvestigationCount',
    );
    return {
      'households': householdCount,
      'members': memberCount,
      'initialRisk': initialRiskCount,
      'socialInvestigations': socialInvestigationCount,
    };
  }

  Future<List<TeiRelationship>?> getTeiRelationshipsfromServer(
      String program,
      String userOrgId,
      ) async {
    List<TeiRelationship> teiRelationshipsFromServer = [];
    try {
      var queryParameters = {
        "program": program,
        "orgUnit": userOrgId,
        "ouMode": "DESCENDANTS"
      };
      List pageFilters = await getDataPaginationFilters(
        "api/relationships.json",
        queryParameters: queryParameters,
      );
      for (var pageFilter in pageFilters) {
        var dataQueryParameters = {
          "fields":
          "relationships[relationshipType,relationship,from[trackedEntityInstance[trackedEntityInstance]],to[trackedEntityInstance[trackedEntityInstance]]]",
        };
        String newTeiRelationshipsUrl = "api/relationships.json";
        dataQueryParameters.addAll(queryParameters);
        dataQueryParameters.addAll(pageFilter);
        Response response = await httpClient.httpGet(
          newTeiRelationshipsUrl,
          queryParameters: dataQueryParameters,
        );
        if (response.statusCode == 200) {
          var responseData = json.decode(response.body);
          for (var teiRelationship in responseData["relationships"]) {
            teiRelationshipsFromServer
                .add(TeiRelationship().fromOnline(teiRelationship));
          }
        } else {
          String errorMessage = await _getHttpResponseAppLogs(response.body);
          if (errorMessage.isNotEmpty) {
            AppLogs log = AppLogs(
                type: AppLogsConstants.errorLogType, message: errorMessage);
            await AppLogsOfflineProvider().addLogs(log);
          }
          return null;
        }
      }
    } catch (error) {
      AppLogs log = AppLogs(
          type: AppLogsConstants.errorLogType, message: error.toString());
      await AppLogsOfflineProvider().addLogs(log);
      rethrow;
    }
    return teiRelationshipsFromServer;
  }

  Future saveEventsToOffline(List<Events> events) async {
    try {
      await EventOfflineProvider().addOrUpdateMultipleEvents(events);
    } catch (error) {
      rethrow;
    }
  }

  Future saveTeiRelationshipToOffline(TeiRelationship relationship) async {
    await TeiRelationshipOfflineProvider()
        .addOrUpdateTeiRelationship(relationship);
  }

  Future saveRelationshipsToOffline(List<dynamic> relationships) async {
    for (var relationship in relationships) {
      await saveTeiRelationshipToOffline(
          TeiRelationship().fromOnline(relationship));
    }
  }

  Future<List> getOfflineEventsAttributesValuesById(String eventIds) async {
    List entityInstanceAttributes = await EventOfflineDataValueProvider()
        .getEventDataValuesByEventId(eventIds);
    return entityInstanceAttributes;
  }

  List<TrackedEntityInstance>? getTeiFromResponse(responseData) {
    return responseData['trackedEntityInstances']
        ?.map<TrackedEntityInstance>(
            (instance) => TrackedEntityInstance().fromJson(instance))
        ?.toList();
  }

  Map<String, List> getEnrollmentsAndRelationshipsFromResponse(responseData) {
    List<Enrollment> enrollments = [];
    List<TeiRelationship> relationships = [];
    for (var tei in responseData['trackedEntityInstances']) {
      String searchableValue =
      TrackedEntityInstanceUtil.getEnrollmentSearchableValue(tei);
      enrollments.addAll(tei['enrollments']?.map<Enrollment>((enrollment) {
        enrollment['searchableValue'] = searchableValue;
        return Enrollment().fromJson(enrollment);
      })?.toList());
      relationships.addAll(tei['relationships']
          ?.map<TeiRelationship>((t) => TeiRelationship().fromOnline(t))
          ?.toList());
    }
    return {'enrollments': enrollments, 'relationships': relationships};
  }

  Future<void> saveTeis(var responseData) async {
    try {
      Map enrollmentsAndRelationships =
      getEnrollmentsAndRelationshipsFromResponse(responseData);
      TrackedEntityInstanceOfflineProvider()
          .addOrUpdateMultipleTrackedEntityInstance(
          getTeiFromResponse(responseData)!);
      EnrollmentOfflineProvider().addOrUpdateMultipleEnrollments(
          enrollmentsAndRelationships['enrollments']);
      TeiRelationshipOfflineProvider().addOrUpdateMultipleTeiRelationships(
          enrollmentsAndRelationships['relationships']);
    } catch (error) {
      rethrow;
    }
  }

  Future<void> getAndSaveTrackedInstanceFromServer(
      String? program, String? userOrgId, String lastSyncDate) async {
    var queryParameters = {
      "program": program,
      "ou": userOrgId,
      "ouMode": "DESCENDANTS",
      "lastUpdatedStartDate": lastSyncDate,
    };
    List pageFilters = await getDataPaginationFilters(
      "api/trackedEntityInstances.json",
      queryParameters: queryParameters,
    );
    for (var pageFilter in pageFilters) {
      try {
        Map<String, String?> dataQueryParameters = {
          "fields":
          "trackedEntityInstance,trackedEntityType,orgUnit,attributes[attribute,value,displayName],enrollments[enrollment,enrollmentDate,incidentDate,orgUnit,program,trackedEntityInstance,status],relationships[relationshipType,relationship,from[trackedEntityInstance[trackedEntityInstance]],to[trackedEntityInstance[trackedEntityInstance]]]",
        };
        String newTrackedInstanceUrl = "api/trackedEntityInstances.json";
        dataQueryParameters.addAll(queryParameters);
        dataQueryParameters.addAll(pageFilter);
        Response response = await httpClient.httpGet(
          newTrackedInstanceUrl,
          queryParameters: dataQueryParameters,
        );
        if (response.statusCode == 200) {
          var responseData = json.decode(response.body);
          await saveTeis(responseData);
        } else {
          String errorMessage = await _getHttpResponseAppLogs(response.body);
          if (errorMessage.isNotEmpty) {
            AppLogs log = AppLogs(
                type: AppLogsConstants.errorLogType, message: errorMessage);
            await AppLogsOfflineProvider().addLogs(log);
          }
          return;
        }
      } catch (error) {
        AppLogs log = AppLogs(
            type: AppLogsConstants.errorLogType, message: error.toString());
        await AppLogsOfflineProvider().addLogs(log);
        rethrow;
      }
    }
  }

  Future saveEnrollmentToOffline(dynamic enrollments) async {
    for (var enrollment in enrollments) {
      EnrollmentOfflineProvider()
          .addOrUpdateEnrollment(Enrollment().fromJson(enrollment));
    }
  }

  Future<List> getOfflineTrackedEntityAttributesValuesById(
      List<String> attributeIds) async {
    List entityInstanceAttributes =
    await TrackedEntityInstanceOfflineAttributeProvider()
        .getTrackedEntityAttributesValuesById(attributeIds);
    return entityInstanceAttributes;
  }

  Future<List<TrackedEntityInstance>> getTeisFromOfflineDb({
    int? page,
  }) async {
    return await TrackedEntityInstanceOfflineProvider()
        .getTrackedEntityInstanceByStatus(
      offlineSyncStatus,
      page: page,
    );
  }

  Future<int> getUnsyncedTeiCount() async {
    return await TrackedEntityInstanceOfflineProvider()
        .getTeiCountBySyncStatus(offlineSyncStatus);
  }

  Future<List<Enrollment>> getTeiEnrollmentFromOfflineDb({
    int? page,
  }) async {
    return await EnrollmentOfflineProvider().getEnrollmentByStatus(
      offlineSyncStatus,
      page: page,
    );
  }

  Future<List<TeiRelationship>> getTeiRelationShipFromOfflineDb({
    int? page,
  }) async {
    return await TeiRelationshipOfflineProvider().getAllTeiRelationShips(
      offlineSyncStatus,
      page: page,
    );
  }

  Future<int> getOfflineTrackedEntityInstanceCount() async {
    var count = await TrackedEntityInstanceOfflineProvider()
        .getTeiCountBySyncStatus(offlineSyncStatus);
    return count;
  }

  Future<int> getOfflineRelationshipCount() async {
    return await TeiRelationshipOfflineProvider()
        .getRelationshipCountBySyncStatus(offlineSyncStatus);
  }

  Future<int> getOfflineEnrollmentCount(CurrentUser currentUser) async {
    int enrollmentsCount = 0;
    for (String? orgUnit in currentUser.userOrgUnitIds ?? []) {
      for (String? program in currentUser.programs ?? []) {
        int count = await EnrollmentOfflineProvider()
            .getOfflineEnrollmentsCount(program, orgUnit);
        enrollmentsCount += count;
      }
    }
    return enrollmentsCount;
  }

  Future<int> getTotalFromPaginator(String url,
      {required Map<String, dynamic> queryParameters}) async {
    Response response = await httpClient.httpGetPagination(
      url,
      queryParameters,
    );
    Map<String, dynamic> pager = json.decode(response.body)['pager'];
    int pageTotal = pager['total'] ?? 0;
    return pageTotal;
  }

  Future<int> getOnlineEnrollmentsCount(
      CurrentUser currentUser, String lastSyncDate) async {
    int enrollmentsCount = 0;
    String url = 'api/trackedEntityInstances';
    try {
      for (String? orgUnit in currentUser.userOrgUnitIds ?? []) {
        for (String? program in currentUser.programs ?? []) {
          var queryParameters = {
            "program": program,
            "ou": orgUnit,
            "ouMode": "DESCENDANTS",
            "fields": "none",
            "pageSize": "1",
            "totalPages": "true",
            "lastUpdatedStartDate": lastSyncDate,
          };
          int count = await getTotalFromPaginator(url,
              queryParameters: queryParameters);
          enrollmentsCount += count;
        }
      }
    } catch (error) {
      rethrow;
    }
    return enrollmentsCount;
  }

  Future<int> getOnlineEventsCount(
      CurrentUser currentUser, String lastSyncDate) async {
    int eventsCount = 0;
    String url = 'api/events';
    try {
      for (String? orgUnit in currentUser.userOrgUnitIds ?? []) {
        for (String? program in currentUser.programs ?? []) {
          var queryParameters = {
            "program": program,
            "orgUnit": orgUnit,
            "ouMode": "DESCENDANTS",
            "fields": "none",
            "pageSize": "1",
            "totalPages": "true",
            "lastUpdatedStartDate": lastSyncDate,
          };
          int count = await getTotalFromPaginator(url,
              queryParameters: queryParameters);
          eventsCount += count;
        }
      }
    } catch (error) {
      rethrow;
    }
    return eventsCount;
  }

  Future<List<Events>> getTeiEventsFromOfflineDb({
    int? page,
  }) async {
    return await EventOfflineProvider().getTrackedEntityInstanceEventsByStatus(
      offlineSyncStatus,
      page: page,
    );
  }

  Future<int> getUnsyncedEventsCount() async {
    return await EventOfflineProvider()
        .getEventsCountBySyncStatus(offlineSyncStatus);
  }

  Future<void> initiateBackgroundDataSync(
      CurrentUser currentUser,
      ) async {
    try {
      var hasUploadedTeiData =
      await initiateBackgroundTrackedEntityInstanceDataUpload();
      var hasUploadedEnrollmentData =
      await initiateBackgroundEnrollmentDataUpload(currentUser);
      var hasUploadedRelationshipData =
      await initiateBackgroundTrackedEntityInstanceRelationshipDataUpload();
      var hasUploadedEventsData =
      await initiateBackgroundEventDataUpload(currentUser);

      if (hasUploadedTeiData ||
          hasUploadedEnrollmentData ||
          hasUploadedRelationshipData ||
          hasUploadedEventsData) {
        LocalNotificationService.show(
          message: "Successfully uploaded the offline data.",
          title: "Automatic sync finished",
        );
      }
    } catch (error) {
      LocalNotificationService.show(
        message:
        "Failed to upload visits. Check the application logs for more information.",
        title: "Automatic sync failed",
      );
      AppLogs log = AppLogs(
        type: AppLogsConstants.errorLogType,
        message: '(initiateBackgroundDataSync): ${error.toString()}',
      );
      await AppLogsOfflineProvider().addLogs(log);
    }
  }

  Future<bool> initiateBackgroundTrackedEntityInstanceDataUpload() async {
    try {
      var teiCount = await getUnsyncedTeiCount();
      bool hasDataToUpload = teiCount > 0;
      if (hasDataToUpload) {
        int totalPages =
        (teiCount / PaginationConstants.dataUploadPaginationLimit).ceil();
        for (int page = 0; page <= totalPages; page++) {
          LocalNotificationService.show(
            message:
            "Uploading Beneficiaries profile data ${((page / teiCount) * 100).ceil()}%.",
            title: "Automatic sync in progress",
          );
          var teiChunk = await getTeisFromOfflineDb(page: page);
          var conflicts = await uploadTeisToTheServer(teiChunk);
          if (conflicts) {
            LocalNotificationService.show(
              message:
              "Failed to upload Beneficiaries profile data. Check app logs for more information",
              title: "Automatic sync in progress",
            );
            hasDataToUpload = hasDataToUpload && conflicts;
          }
        }
      }
      return hasDataToUpload;
    } catch (error) {
      rethrow;
    }
  }

  Future<bool> initiateBackgroundEnrollmentDataUpload(
      CurrentUser currentUser) async {
    try {
      var enrollmentCount = await getOfflineEnrollmentCount(currentUser);
      bool hasDataToUpload = enrollmentCount > 0;
      if (hasDataToUpload) {
        int totalPages =
        (enrollmentCount / PaginationConstants.dataUploadPaginationLimit)
            .ceil();
        for (int page = 0; page <= totalPages; page++) {
          LocalNotificationService.show(
            message:
            "Uploading Beneficiaries enrollment data ${((page / enrollmentCount) * 100).ceil()}%.",
            title: "Automatic sync in progress",
          );
          var enrollmentChunk = await getTeiEnrollmentFromOfflineDb(page: page);
          var conflicts = await uploadEnrollmentsToTheServer(enrollmentChunk);
          if (conflicts) {
            LocalNotificationService.show(
              message:
              "Failed to upload some Beneficiaries enrollment data. Check app logs for more information",
              title: "Automatic sync in progress",
            );
            hasDataToUpload = hasDataToUpload && conflicts;
          }
        }
      }

      return hasDataToUpload;
    } catch (error) {
      rethrow;
    }
  }

  Future<bool>
  initiateBackgroundTrackedEntityInstanceRelationshipDataUpload() async {
    try {
      var teiRelationshipCount = await getOfflineRelationshipCount();
      bool hasDataToUpload = teiRelationshipCount > 0;
      if (hasDataToUpload) {
        int totalPages = (teiRelationshipCount /
            PaginationConstants.dataUploadPaginationLimit)
            .ceil();
        for (int page = 0; page <= totalPages; page++) {
          LocalNotificationService.show(
            message:
            "Uploading Beneficiaries relationships data ${((page / teiRelationshipCount) * 100).ceil()}%.",
            title: "Automatic sync in progress",
          );
          var teiRelationshipChunk =
          await getTeiRelationShipFromOfflineDb(page: page);
          var conflicts =
          await uploadTeiRelationToTheServer(teiRelationshipChunk);
          if (conflicts) {
            LocalNotificationService.show(
              message:
              "Failed to upload some Beneficiaries relationships data. Check app logs for more information",
              title: "Automatic sync in progress",
            );
            hasDataToUpload = hasDataToUpload && conflicts;
          }
        }
      }

      return hasDataToUpload;
    } catch (error) {
      rethrow;
    }
  }

  Future<bool> initiateBackgroundEventDataUpload(CurrentUser currentUser) async {
    try {
      var offlineEventCount = await getUnsyncedEventsCount();
      var hasDataToUpload = offlineEventCount > 0;
      if (hasDataToUpload) {
        int totalPages =
        (offlineEventCount / PaginationConstants.dataUploadPaginationLimit)
            .ceil();
        for (int page = 0; page <= totalPages; page++) {
          LocalNotificationService.show(
            message:
            "Uploading Beneficiaries service data ${((page / offlineEventCount) * 100).ceil()}%.",
            title: "Automatic sync in progress",
          );
          var teiEventChunk = await getTeiEventsFromOfflineDb(page: page);
          var conflicts = await uploadTeiEventsToTheServer(teiEventChunk);
          if (conflicts) {
            final detail = _lastEventSyncError.trim();
            LocalNotificationService.show(
              message: detail.isNotEmpty
                  ? 'Event sync failed: $detail'
                  : 'Failed to upload some service/event data. Check app logs for more information.',
              title: 'Synchronization issue',
            );
            hasDataToUpload = hasDataToUpload && conflicts;
          }
        }
      }
      return hasDataToUpload;
    } catch (error) {
      rethrow;
    }
  }

  Future<bool> uploadEnrollmentsToTheServer(
      List<Enrollment> teiEnrollments, {
        bool ignoreUnsyncedTeiFilter = false,
      }) async {
    List<String?>? syncedIds = [];
    String url = 'api/enrollments';
    bool conflictOnImport = false;
    List<TrackedEntityInstance> unsyncedTeis = await getTeisFromOfflineDb();
    var enrollments = ignoreUnsyncedTeiFilter
        ? teiEnrollments
        : teiEnrollments
        .where((enrollment) =>
    unsyncedTeis.indexWhere((tei) =>
    tei.trackedEntityInstance ==
        enrollment.trackedEntityInstance) ==
        -1)
        .toList();

    enrollments = _deduplicateEnrollments(enrollments);

    if (enrollments.isEmpty) {
      return false;
    }

    Map body = {};
    body['enrollments'] = enrollments
        .map((enrollment) => enrollment.toOffline(enrollment))
        .toList();
    try {
      var queryParameters = {
        "strategy": "CREATE_AND_UPDATE",
        "mergeMode": "MERGE",
      };
      var response = await httpClient.httpPost(
        url,
        json.encode(body),
        queryParameters: queryParameters,
      );
      if (response.statusCode >= 400 && response.statusCode != 409) {
        var message = await _getHttpResponseAppLogs(response.body);
        AppLogs log = AppLogs(
            type: AppLogsConstants.errorLogType,
            message: 'uploadEnrollmentsToTheServer: $message');
        await AppLogsOfflineProvider().addLogs(log);
        conflictOnImport = true;
      }
      var referenceIds = await _getReferenceIds(json.decode(response.body));
      conflictOnImport = conflictOnImport || referenceIds['conflictOnImport'];
      syncedIds = referenceIds['syncedIds'];
    } catch (error) {
      AppLogs log = AppLogs(
          type: AppLogsConstants.errorLogType,
          message: 'uploadEnrollmentsToTheServer: ${error.toString()}');
      await AppLogsOfflineProvider().addLogs(log);
      rethrow;
    }
    if (syncedIds!.isNotEmpty) {
      for (final enrollment in enrollments) {
        final enrollmentId = (enrollment.enrollment ?? '').trim();
        if (enrollmentId.isNotEmpty && syncedIds.contains(enrollmentId)) {
          await _markEnrollmentSynced(enrollmentId);
        }
      }
    }

    return conflictOnImport;
  }


  static const Set<String> _dhis2BooleanAttributeIds = {
    'qplFRHPhrMJ',
    'doT78HXVVtZ',
    'jfjsu5QL6Ce',
  };

  static const Set<String> _organisationUnitAttributeIds = {
    'mUd3nLq2yWs',
    'QEFKNkxgAPJ',
  };

  bool _looksLikeDhis2Uid(String value) {
    return RegExp(r'^[A-Za-z][A-Za-z0-9]{10}$').hasMatch(value.trim());
  }

  String _normaliseTrackedEntityAttributeValue(
      String attribute,
      String value,
      ) {
    final cleanValue = value.trim();

    if (!_dhis2BooleanAttributeIds.contains(attribute)) {
      return cleanValue;
    }

    switch (cleanValue.toUpperCase()) {
      case 'YES':
      case 'TRUE':
        return 'true';
      case 'NO':
      case 'FALSE':
        return 'false';
      default:
        return cleanValue;
    }
  }

  bool _canUploadTrackedEntityAttribute(
      String attribute,
      String value,
      ) {
    final cleanAttribute = attribute.trim();
    final cleanValue = value.trim();

    if (cleanAttribute.isEmpty || cleanAttribute.startsWith('ATTR_')) {
      return false;
    }

    if (cleanValue.isEmpty ||
        cleanValue == 'null' ||
        cleanValue == '[]' ||
        cleanValue == '{}') {
      return false;
    }

    if (_organisationUnitAttributeIds.contains(cleanAttribute) &&
        !_looksLikeDhis2Uid(cleanValue)) {
      return false;
    }

    return true;
  }

  List _cleanTrackedEntityAttributes(
      dynamic attributes, {
        String? orgUnit,
      }) {
    if (attributes is! List) return [];

    return attributes
        .map((dynamic rawAttribute) {
      if (rawAttribute is! Map) return null;

      final attribute =
      (rawAttribute['attribute'] ?? '').toString().trim();
      var value = (rawAttribute['value'] ?? '').toString().trim();

      if (attribute == 'QEFKNkxgAPJ' &&
          !_looksLikeDhis2Uid(value) &&
          _looksLikeDhis2Uid((orgUnit ?? '').trim())) {
        value = orgUnit!.trim();
      }

      value = _normaliseTrackedEntityAttributeValue(attribute, value);

      if (!_canUploadTrackedEntityAttribute(attribute, value)) {
        return null;
      }

      return {
        ...rawAttribute,
        'attribute': attribute,
        'value': value,
      };
    })
        .where((attribute) => attribute != null)
        .cast<Map>()
        .toList();
  }


  Future<void> _markTrackedEntitySynced(String teiId) async {
    final cleanId = teiId.trim();
    if (cleanId.isEmpty) return;

    final db = await OfflineDbProvider().db;
    if (db == null) return;

    await db.update(
      'tracked_entity_instance',
      {'syncStatus': onlineSyncStatus},
      where: 'trackedEntityInstance = ?',
      whereArgs: [cleanId],
    );

    try {
      await db.rawDelete(
        'DELETE FROM tracked_entity_instance '
            'WHERE trackedEntityInstance = ? '
            'AND rowid NOT IN ('
            'SELECT MIN(rowid) FROM tracked_entity_instance '
            'WHERE trackedEntityInstance = ?'
            ')',
        [cleanId, cleanId],
      );
    } catch (_) {}
  }

  Future<void> _markEnrollmentSynced(String enrollmentId) async {
    final cleanId = enrollmentId.trim();
    if (cleanId.isEmpty) return;

    final db = await OfflineDbProvider().db;
    if (db == null) return;

    await db.update(
      'enrollment',
      {'syncStatus': onlineSyncStatus},
      where: 'enrollment = ?',
      whereArgs: [cleanId],
    );

    try {
      await db.rawDelete(
        'DELETE FROM enrollment '
            'WHERE enrollment = ? '
            'AND rowid NOT IN ('
            'SELECT MIN(rowid) FROM enrollment '
            'WHERE enrollment = ?'
            ')',
        [cleanId, cleanId],
      );
    } catch (_) {}
  }

  Future<void> _markEventSyncedDirectly(String eventId) async {
    final cleanId = eventId.trim();
    if (cleanId.isEmpty) return;

    final db = await OfflineDbProvider().db;
    if (db == null) return;

    await db.update(
      'events',
      {'syncStatus': onlineSyncStatus},
      where: 'event = ?',
      whereArgs: [cleanId],
    );
  }

  List<TrackedEntityInstance> _deduplicateTeis(
      List<TrackedEntityInstance> teis,
      ) {
    final byId = <String, TrackedEntityInstance>{};
    for (final tei in teis) {
      final id = (tei.trackedEntityInstance ?? '').trim();
      if (id.isEmpty) continue;
      byId[id] = tei;
    }
    return byId.values.toList();
  }

  List<Enrollment> _deduplicateEnrollments(List<Enrollment> enrollments) {
    final byId = <String, Enrollment>{};
    for (final enrollment in enrollments) {
      final id = (enrollment.enrollment ?? '').trim();
      if (id.isEmpty) continue;
      byId[id] = enrollment;
    }
    return byId.values.toList();
  }

  List<Events> _deduplicateEvents(List<Events> events) {
    final byId = <String, Events>{};
    for (final event in events) {
      final id = (event.event ?? '').trim();
      if (id.isEmpty) continue;
      byId[id] = event;
    }
    return byId.values.toList();
  }

  Future<bool> uploadTeisToTheServer(
      List<TrackedEntityInstance> teis,
      ) async {
    final uniqueTeis = _deduplicateTeis(teis);
    List<String?>? syncedIds = [];
    String url = 'api/trackedEntityInstances';
    bool conflictOnImport = false;
    Map body = {};
    body['trackedEntityInstances'] = uniqueTeis.map((tei) {
      var data = tei.toOffline(tei);
      data['attributes'] = _cleanTrackedEntityAttributes(
        data['attributes'],
        orgUnit: (data['orgUnit'] ?? '').toString(),
      );
      return data;
    }).toList();

    try {
      var queryParameters = {
        "strategy": "CREATE_AND_UPDATE",
        "mergeMode": "MERGE",
      };
      var response = await httpClient.httpPost(
        url,
        json.encode(body),
        queryParameters: queryParameters,
      );
      if (response.statusCode >= 400 && response.statusCode != 409) {
        var message = await _getHttpResponseAppLogs(response.body);
        if (message.isNotEmpty) {
          AppLogs log = AppLogs(
              type: AppLogsConstants.errorLogType,
              message: 'uploadTeisToTheServer: $message');
          await AppLogsOfflineProvider().addLogs(log);
          conflictOnImport = true;
        }
      }
      var referenceIds = await _getReferenceIds(json.decode(response.body));
      syncedIds = referenceIds['syncedIds'];
      conflictOnImport = conflictOnImport || referenceIds['conflictOnImport'];
    } catch (error) {
      AppLogs log = AppLogs(
          type: AppLogsConstants.errorLogType,
          message: 'uploadTeisToTheServer: ${error.toString()}');
      await AppLogsOfflineProvider().addLogs(log);
      rethrow;
    }
    if (syncedIds!.isNotEmpty) {
      for (final tei in uniqueTeis) {
        final teiId = (tei.trackedEntityInstance ?? '').trim();
        if (teiId.isNotEmpty && syncedIds.contains(teiId)) {
          await _markTrackedEntitySynced(teiId);
        }
      }
    }

    return conflictOnImport;
  }



  Future<List<String>> _getEventBatchTrackedEntityIds(
      List<Events> teiEvents,
      ) async {
    final directTeiIds = teiEvents
        .map((event) => (event.trackedEntityInstance ?? '').toString().trim())
        .where((teiId) => teiId.isNotEmpty)
        .toList();

    final eventIds = teiEvents
        .map((event) => (event.event ?? '').toString().trim())
        .where((eventId) => eventId.isNotEmpty)
        .toList();

    List<String> storedTeiIds = [];
    if (eventIds.isNotEmpty) {
      storedTeiIds = await EventOfflineProvider()
          .getTrackedEntityInstanceIdsByIds(eventIds);
    }

    return <String>{
      ...directTeiIds,
      ...storedTeiIds.map((teiId) => teiId.toString().trim()),
    }.where((teiId) => teiId.isNotEmpty).toList();
  }

  Future<void> _uploadBeneficiariesAndEnrollmentsForEventBatch(
      List<Events> teiEvents,
      ) async {
    final cleanTeiIds = await _getEventBatchTrackedEntityIds(teiEvents);

    if (cleanTeiIds.isEmpty) return;

    final relatedTeis = await TrackedEntityInstanceOfflineProvider()
        .getTrackedEntityInstanceByIds(cleanTeiIds);

    if (relatedTeis.isNotEmpty) {
      await uploadTeisToTheServer(relatedTeis);
    }

    final relatedEnrollments = await EnrollmentOfflineProvider()
        .getEnrollmentsFromTeiList(cleanTeiIds);

    if (relatedEnrollments.isNotEmpty) {
      await uploadEnrollmentsToTheServer(
        relatedEnrollments,
        ignoreUnsyncedTeiFilter: true,
      );
    }
  }


  bool _isInvalidDhis2Uid(String value) {
    final v = value.trim();
    return v.isEmpty ||
        v.startsWith('DE_') ||
        v.startsWith('ATTR_') ||
        v.startsWith('MGYSD_') ||
        v.contains('_UID') ||
        v.length != 11;
  }

  Future<void> _addSyncLog(String message) async {
    await AppLogsOfflineProvider().addLogs(
      AppLogs(
        type: AppLogsConstants.errorLogType,
        message: message,
      ),
    );
  }

  Future<void> _markMgysdSourceRecordSynced(String eventId) async {
    try {
      final db = await OfflineDbProvider().db;
      if (db == null) return;

      final contextTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        ['mgysd_stage_event_context'],
      );
      if (contextTable.isEmpty) return;

      final rows = await db.query(
        'mgysd_stage_event_context',
        columns: ['tableName'],
        where: 'eventId = ?',
        whereArgs: [eventId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final tableName = (rows.first['tableName'] ?? '').toString().trim();
      const allowedTables = <String>{
        'mgysd_initial_risk_assessment',
        'mgysd_social_investigation',
        'mgysd_care_plan',
        'mgysd_referral',
        'mgysd_monitoring',
        'mgysd_case_closure',
        'mgysd_service_provision',
      };

      if (!allowedTables.contains(tableName)) return;

      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      if (tableExists.isEmpty) return;

      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final names = columns
          .map((column) => (column['name'] ?? '').toString())
          .toSet();
      if (!names.contains('syncStatus')) return;

      // Workflow tables such as Care Plan have their own local IDs
      // (for example CP_<social-investigation>) and a separate DHIS2 eventId.
      // Prefer eventId when it exists; fall back to id for older tables.
      var updated = 0;

      if (names.contains('eventId')) {
        updated = await db.update(
          tableName,
          {'syncStatus': onlineSyncStatus},
          where: 'eventId = ?',
          whereArgs: [eventId],
        );
      }

      if (updated == 0 && names.contains('id')) {
        await db.update(
          tableName,
          {'syncStatus': onlineSyncStatus},
          where: 'id = ?',
          whereArgs: [eventId],
        );
      }
    } catch (error) {
      await _addSyncLog(
        'MGYSD SOURCE SYNC STATUS UPDATE FAILED for $eventId: $error',
      );
    }
  }

  static const String _mgysdReportedCasesProgram = 'TbR7dOCu5XK';
  static const String _mgysdReportedCasesStage = 'TybrOV3Isgz';

  static const Set<String> _mgysdReportedCaseDataElements = {
    'Zjah90FdrwV', // Reporter Area Chief First Name
    'vmVxUbkVmXN', // Reporter Area Chief Last Name
    'arawTWdOCOZ', // Reporter Community Council
    'UJIrqEgPMn1', // Reporter Concern Reason
    'UlxSVhptSPi', // Reporter Concern Reason - other
    'hKEJvGcXWND', // Reporter Contact Number
    'pgklc5q0r9A', // Reporter Contact Number - other
    'RWEFHH4pm27', // Reporter First Name
    'dwSkq33g4Uu', // Reporter Last Name
    'vXKcqU7V0xQ', // Reporter Relationship with Client
    'wIAHzLOccWk', // Reporter Relationship with Client - other
    'NCb5dNKnqOG', // Reporter Village
    'NwCn5RVitx1', // Client Age
    'hxxH8RmZrV2', // Client Category
    'wOIx1Tism5p', // Client First Name
    'mclj3oLRpiv', // Client Last Name
    'UImPhy5oOOq', // Incident date
    'rOo1QAaJ23F', // Incident description
    'mEUV26PcDKZ', // Incident location
    'UwebjUHdn33', // Incident location - Village
    'LsdeO9mllih', // Remarks
    'EG9wNvu6kGY', // Reporting date
    'kwL1QEdrChg', // Reporter Sex
    'fBB08qRfTCp', // Client Contact Number
    'cq6CCF80ToK', // Witness First Name
    'QxbYDX4Bnr2', // Witness Last Name
    'g2kqM2Db2WU', // Other
    'gG7pCI0Ma5v', // Reporter Anonymous
  };

  bool _eventRequiresTrackedEntity(String program) {
    // MGYSD Reported Cases is a DHIS2 WITHOUT_REGISTRATION event program.
    return program.trim() != _mgysdReportedCasesProgram;
  }

  bool _isAllowedDataElementForEvent({
    required String program,
    required String programStage,
    required String dataElement,
  }) {
    if (program == _mgysdReportedCasesProgram &&
        programStage == _mgysdReportedCasesStage) {
      return _mgysdReportedCaseDataElements.contains(dataElement);
    }
    return true;
  }


  String _eventImportErrorSummary(Map<String, dynamic> body) {
    final messages = <String>[];
    try {
      final response = body['response'];
      if (response is! Map) return '';

      final summaries = response['importSummaries'];
      if (summaries is! List) return '';

      for (final summary in summaries) {
        if (summary is! Map) continue;
        final status = (summary['status'] ?? '').toString().trim();
        if (status.toUpperCase() == 'SUCCESS') continue;

        final reference = (summary['reference'] ?? '').toString().trim();
        final description =
        (summary['description'] ?? '').toString().trim();

        final conflicts = summary['conflicts'];
        if (conflicts is List && conflicts.isNotEmpty) {
          for (final conflict in conflicts) {
            if (conflict is! Map) continue;
            final object = (conflict['object'] ?? '').toString().trim();
            final value = (conflict['value'] ?? '').toString().trim();
            final detail = [
              if (object.isNotEmpty) object,
              if (value.isNotEmpty) value,
            ].join(': ');
            if (detail.isNotEmpty) {
              messages.add(
                reference.isEmpty ? detail : '$reference - $detail',
              );
            }
          }
        } else if (description.isNotEmpty) {
          messages.add(
            reference.isEmpty ? description : '$reference - $description',
          );
        }
      }
    } catch (_) {}

    return messages.toSet().join(' | ');
  }


  bool _isInitialRiskAssessmentEvent(Events event) {
    return (event.program ?? '').trim() ==
        MgysdDhis2Uids.assessedHouseholdsProgram &&
        (event.programStage ?? '').trim() ==
            MgysdDhis2Uids.initialRiskAssessmentStage;
  }


  Future<String> _resolveInitialRiskServerEventId(Events event) async {
    final enrollment = (event.enrollment ?? '').trim();
    final tei = (event.trackedEntityInstance ?? '').trim();
    final program = (event.program ?? '').trim();
    final stage = (event.programStage ?? '').trim();
    final orgUnit = (event.orgUnit ?? '').trim();

    Future<String> query(Map<String, dynamic> params) async {
      try {
        final response = await httpClient.httpGet(
          'api/events.json',
          queryParameters: {
            'fields':
            'event,enrollment,program,programStage,trackedEntityInstance,orgUnit,status,eventDate',
            'pageSize': '50',
            ...params,
          },
        );

        await _addSyncLog(
          'INITIAL RISK EVENT LOOKUP ${response.statusCode}: ${response.body}',
        );

        if (response.statusCode != 200) return '';

        final decoded = json.decode(response.body);
        if (decoded is! Map) return '';

        final events = decoded['events'];
        if (events is! List || events.isEmpty) return '';

        for (final item in events) {
          if (item is! Map) continue;

          final itemStage = (item['programStage'] ?? '').toString().trim();
          final itemProgram = (item['program'] ?? '').toString().trim();
          final itemEnrollment =
          (item['enrollment'] ?? '').toString().trim();
          final itemTei =
          (item['trackedEntityInstance'] ?? '').toString().trim();

          if (itemStage != stage || itemProgram != program) continue;
          if (enrollment.isNotEmpty &&
              itemEnrollment.isNotEmpty &&
              itemEnrollment != enrollment) {
            continue;
          }
          if (tei.isNotEmpty && itemTei.isNotEmpty && itemTei != tei) {
            continue;
          }

          final id = (item['event'] ?? '').toString().trim();
          if (id.isNotEmpty) return id;
        }
      } catch (error) {
        await _addSyncLog(
          'INITIAL RISK EVENT LOOKUP ERROR: $error',
        );
      }
      return '';
    }

    // Best lookup: the non-repeatable event belongs to one enrollment.
    if (enrollment.isNotEmpty) {
      final found = await query({
        'program': program,
        'programStage': stage,
        'enrollment': enrollment,
      });
      if (found.isNotEmpty) return found;
    }

    // Compatibility fallback for DHIS2 versions that do not filter event
    // queries by enrollment.
    if (tei.isNotEmpty) {
      final found = await query({
        'program': program,
        'programStage': stage,
        'trackedEntityInstance': tei,
        if (orgUnit.isNotEmpty) 'orgUnit': orgUnit,
      });
      if (found.isNotEmpty) return found;
    }

    return '';
  }

  Future<void> _reconcileLocalEventUid({
    required String localEventId,
    required String serverEventId,
  }) async {
    final localId = localEventId.trim();
    final serverId = serverEventId.trim();

    if (localId.isEmpty || serverId.isEmpty || localId == serverId) return;

    final db = await OfflineDbProvider().db;
    if (db == null) return;

    await db.transaction((txn) async {
      // If the same server event was already downloaded, remove that stale
      // local copy first. We are keeping the edited local values.
      final existingServerRows = await txn.query(
        'events',
        where: 'event = ?',
        whereArgs: [serverId],
        limit: 1,
      );

      if (existingServerRows.isNotEmpty) {
        await txn.delete(
          'event_data_value',
          where: 'event = ?',
          whereArgs: [serverId],
        );
        await txn.delete(
          'events',
          where: 'event = ?',
          whereArgs: [serverId],
        );
      }

      await txn.update(
        'event_data_value',
        {'event': serverId},
        where: 'event = ?',
        whereArgs: [localId],
      );

      await txn.update(
        'events',
        {
          'id': serverId,
          'event': serverId,
        },
        where: 'event = ?',
        whereArgs: [localId],
      );

      try {
        await txn.update(
          'mgysd_stage_event_context',
          {'eventId': serverId},
          where: 'eventId = ?',
          whereArgs: [localId],
        );
      } catch (_) {}
    });
  }

  Future<Map<String, List<String>>> _getServerRelationshipIdsForFromTei(
      String fromTei,
      ) async {
    final result = <String, List<String>>{};
    final from = fromTei.trim();
    if (from.isEmpty) return result;

    try {
      final response = await httpClient.httpGet(
        'api/trackedEntityInstances/$from.json',
        queryParameters: {
          'fields':
          'relationships[relationship,relationshipType,from[trackedEntityInstance[trackedEntityInstance]],to[trackedEntityInstance[trackedEntityInstance]]]',
        },
      );

      if (response.statusCode != 200) return result;

      final decoded = json.decode(response.body);
      if (decoded is! Map) return result;

      final relationships = decoded['relationships'];
      if (relationships is! List) return result;

      for (final item in relationships) {
        if (item is! Map) continue;

        final type = (item['relationshipType'] ?? '').toString().trim();
        final relationshipId =
        (item['relationship'] ?? '').toString().trim();

        final fromBlock = item['from'];
        final toBlock = item['to'];

        String serverFrom = '';
        String serverTo = '';

        if (fromBlock is Map) {
          final teiBlock = fromBlock['trackedEntityInstance'];
          if (teiBlock is Map) {
            serverFrom =
                (teiBlock['trackedEntityInstance'] ?? '').toString().trim();
          }
        }

        if (toBlock is Map) {
          final teiBlock = toBlock['trackedEntityInstance'];
          if (teiBlock is Map) {
            serverTo =
                (teiBlock['trackedEntityInstance'] ?? '').toString().trim();
          }
        }

        if (type.isEmpty ||
            serverFrom.isEmpty ||
            serverTo.isEmpty ||
            relationshipId.isEmpty) {
          continue;
        }

        final key = '$type|$serverFrom|$serverTo';
        result.putIfAbsent(key, () => <String>[]).add(relationshipId);
      }
    } catch (error) {
      await _addSyncLog(
        'RELATIONSHIP LOOKUP ERROR [$from]: $error',
      );
    }

    return result;
  }

  Future<bool> _putExistingInitialRiskEvent({
    required Events event,
    required String serverEventId,
    required Map<String, dynamic> payload,
  }) async {
    final localEventId = (event.event ?? '').trim();
    final eventId = serverEventId.trim();
    if (localEventId.isEmpty || eventId.isEmpty) return false;

    final updatePayload = Map<String, dynamic>.from(payload);
    updatePayload['event'] = eventId;

    try {
      print('======================================');
      print('INITIAL RISK EVENT UPDATE START');
      print('LOCAL EVENT: $localEventId');
      print('SERVER EVENT: $eventId');
      print(const JsonEncoder.withIndent('  ').convert(updatePayload));
      print('======================================');

      final response = await httpClient.httpPut(
        'api/events/$eventId',
        json.encode(updatePayload),
        queryParameters: {
          'mergeMode': 'MERGE',
        },
      );

      print('======================================');
      print(
        'DHIS2 INITIAL RISK UPDATE STATUS: ${response.statusCode}',
      );
      print('DHIS2 INITIAL RISK UPDATE BODY:');
      print(response.body);
      print('======================================');

      await _addSyncLog(
        'INITIAL RISK UPDATE RESPONSE ${response.statusCode}: '
            '${response.body}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _reconcileLocalEventUid(
          localEventId: localEventId,
          serverEventId: eventId,
        );
        await _markEventSyncedDirectly(eventId);
        await _markMgysdSourceRecordSynced(eventId);
        return true;
      }

      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final summary = _eventImportErrorSummary(decoded);
          _lastEventSyncError =
          summary.isNotEmpty ? summary : response.body;
        } else {
          _lastEventSyncError = response.body;
        }
      } catch (_) {
        _lastEventSyncError = response.body;
      }

      print(
        'DHIS2 INITIAL RISK UPDATE ERROR: $_lastEventSyncError',
      );
      await _addSyncLog(
        'DHIS2 INITIAL RISK UPDATE ERROR [$eventId]: '
            '$_lastEventSyncError',
      );
      return false;
    } catch (error, stackTrace) {
      _lastEventSyncError = error.toString();
      print('INITIAL RISK UPDATE EXCEPTION: $error');
      print(stackTrace);
      await _addSyncLog(
        'INITIAL RISK UPDATE EXCEPTION [$eventId]: $error',
      );
      return false;
    }
  }

  Future<bool> uploadTeiEventsToTheServer(
      List<Events> teiEvents, {
        bool checkEnrollments = true,
      }) async {
    List<String?> syncedIds = [];
    const String url = 'api/events';
    bool conflictOnImport = false;
    _lastEventSyncError = '';

    if (teiEvents.isEmpty) return false;

    if (checkEnrollments) {
      await _uploadBeneficiariesAndEnrollmentsForEventBatch(teiEvents);
    }

    final List<Events> validEvents = [];
    final List<Map<String, dynamic>> payloadEvents = [];
    var initialRiskUpdateFailed = false;

    for (final event in teiEvents) {
      final eventId = (event.event ?? '').trim();
      final program = (event.program ?? '').trim();
      final programStage = (event.programStage ?? '').trim();
      final trackedEntityInstance =
      (event.trackedEntityInstance ?? '').trim();
      final orgUnit = (event.orgUnit ?? '').trim();

      final validationErrors = <String>[];

      if (_isInvalidDhis2Uid(eventId)) {
        validationErrors.add('event UID is missing/invalid: "$eventId"');
      }
      if (_isInvalidDhis2Uid(program)) {
        validationErrors.add('program UID is missing/invalid: "$program"');
      }
      if (_isInvalidDhis2Uid(programStage)) {
        validationErrors
            .add('programStage UID is missing/invalid: "$programStage"');
      }
      final requiresTrackedEntity = _eventRequiresTrackedEntity(program);
      if (requiresTrackedEntity && _isInvalidDhis2Uid(trackedEntityInstance)) {
        validationErrors.add(
          'trackedEntityInstance UID is missing/invalid: '
              '"$trackedEntityInstance"',
        );
      }
      if (_isInvalidDhis2Uid(orgUnit)) {
        validationErrors.add('orgUnit UID is missing/invalid: "$orgUnit"');
      }

      if (validationErrors.isNotEmpty) {
        await _addSyncLog(
          'EVENT NOT SYNCHRONIZED [$eventId]: ${validationErrors.join('; ')}',
        );
        continue;
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(event.toOffline(event));
      data.remove('syncStatus');

      if (!requiresTrackedEntity) {
        data.remove('trackedEntityInstance');
        data.remove('enrollment');
      }

      final enrollment = (data['enrollment'] ?? '').toString().trim();
      if (enrollment.isEmpty) {
        data.remove('enrollment');
      } else if (_isInvalidDhis2Uid(enrollment)) {
        await _addSyncLog(
          'EVENT [$eventId]: enrollment UID "$enrollment" is invalid; '
              'the enrollment reference was omitted from the event payload.',
        );
        data.remove('enrollment');
      }

      final rawDataValues = data['dataValues'];
      final List<Map<String, dynamic>> cleanDataValues = [];

      if (rawDataValues is List) {
        for (final item in rawDataValues) {
          if (item is! Map) continue;

          final dataElement =
          (item['dataElement'] ?? '').toString().trim();
          final value = (item['value'] ?? '').toString().trim();

          if (dataElement == 'eventDate') continue;
          if (value.isEmpty || value == 'null') continue;

          if (_isInvalidDhis2Uid(dataElement)) {
            await _addSyncLog(
              'EVENT [$eventId]: skipped invalid dataElement '
                  '"$dataElement" with value "$value".',
            );
            continue;
          }

          if (!_isAllowedDataElementForEvent(
            program: program,
            programStage: programStage,
            dataElement: dataElement,
          )) {
            await _addSyncLog(
              'EVENT [$eventId]: skipped dataElement "$dataElement" because '
                  'it is not assigned to program stage "$programStage".',
            );
            continue;
          }

          cleanDataValues.add({
            'dataElement': dataElement,
            'value': value,
          });
        }
      }

      data['dataValues'] = cleanDataValues;

      if (_isInitialRiskAssessmentEvent(event)) {
        final serverEventId =
        await _resolveInitialRiskServerEventId(event);

        if (serverEventId.isNotEmpty) {
          final updated = await _putExistingInitialRiskEvent(
            event: event,
            serverEventId: serverEventId,
            payload: data,
          );
          if (!updated) {
            initialRiskUpdateFailed = true;
          }
          continue;
        }

        // No server event exists yet: this is the first synchronization of
        // the non-repeatable stage, so create it once through normal import.
        validEvents.add(event);
        payloadEvents.add(data);
        continue;
      }

      validEvents.add(event);
      payloadEvents.add(data);
    }

    // If this batch only contained Initial Risk updates, we are done.
    if (payloadEvents.isEmpty) {
      if (initialRiskUpdateFailed) {
        return true;
      }

      await _addSyncLog(
        'EVENT SYNC COMPLETE: all pending non-repeatable Initial Risk events '
            'were updated successfully.',
      );
      return false;
    }

    final Map<String, dynamic> body = {
      'events': payloadEvents,
    };

    try {
      print('======================================');
      print('EVENT SYNC START');
      print('EVENT COUNT: ${payloadEvents.length}');
      print('REQUEST BODY:');
      print(const JsonEncoder.withIndent('  ').convert(body));
      print('======================================');

      final response = await httpClient.httpPost(
        url,
        json.encode(body),
        queryParameters: {
          'strategy': 'CREATE_AND_UPDATE',
          'mergeMode': 'MERGE',
        },
      );

      print('======================================');
      print('DHIS2 EVENT RESPONSE STATUS: ${response.statusCode}');
      print('DHIS2 EVENT RESPONSE BODY:');
      print(response.body);
      print('======================================');

      await _addSyncLog(
        'EVENT SYNC RESPONSE ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode >= 400 && response.statusCode != 409) {
        return true;
      }

      final Map<String, dynamic> responseJson = json.decode(response.body);

      _lastEventSyncError = _eventImportErrorSummary(responseJson);
      if (_lastEventSyncError.isNotEmpty) {
        print('DHIS2 EVENT IMPORT ERROR: $_lastEventSyncError');
        await _addSyncLog(
          'DHIS2 EVENT IMPORT ERROR: $_lastEventSyncError',
        );
      }

      final Map<String, dynamic> referenceIds =
      await _getReferenceIds(responseJson);

      syncedIds = (referenceIds['syncedIds'] ?? []).cast<String?>();
      conflictOnImport = referenceIds['conflictOnImport'] == true;

      await reUploadBeneficiariesWithUnsyncedServices(
        referenceIds,
        checkEnrollments,
        validEvents,
      );

      if (syncedIds.isNotEmpty) {
        for (final event in validEvents) {
          final eventId = (event.event ?? '').trim();
          if (syncedIds.contains(event.event)) {
            if (eventId.isNotEmpty) {
              await _markEventSyncedDirectly(eventId);
              await _markMgysdSourceRecordSynced(eventId);
            }
          }
        }
      }

      return conflictOnImport || initialRiskUpdateFailed;
    } catch (error, stackTrace) {
      print('EVENT SYNC EXCEPTION');
      print(error);
      print(stackTrace);

      await _addSyncLog(
        'uploadTeiEventsToTheServer EXCEPTION: $error',
      );

      rethrow;
    }
  }



  Future<void> reUploadBeneficiariesWithUnsyncedServices(
      Map referenceIds,
      bool checkEnrollments,
      List<Events> teiEvents,
      ) async {
    List<String?> unsyncedDueToEnrollment =
        referenceIds['unsyncedDueToEnrollment'] ?? [];
    List<String?> unsyncedDueMissingBeneficiary =
        referenceIds['unsyncedDueMissingBeneficiary'] ?? [];
    List<String?> unsyncedEventIds = [
      ...unsyncedDueMissingBeneficiary,
      ...unsyncedDueToEnrollment
    ];

    if (unsyncedEventIds.isEmpty &&
        referenceIds['hasEnrollmentConflict'] == true) {
      unsyncedEventIds = teiEvents
          .map((event) => event.event)
          .where((eventId) => eventId != null && eventId.trim().isNotEmpty)
          .toList();
    }

    if (unsyncedEventIds.isNotEmpty && checkEnrollments) {
      final unsyncedTeiEvents = teiEvents
          .where((Events eventData) =>
          unsyncedEventIds.contains(eventData.event ?? ""))
          .toList();

      final teiIds = await _getEventBatchTrackedEntityIds(unsyncedTeiEvents);

      List<Enrollment> unsyncedTeiEnrollments =
      await EnrollmentOfflineProvider().getEnrollmentsFromTeiList(teiIds);
      List<TrackedEntityInstance> unsyncedTeis =
      await TrackedEntityInstanceOfflineProvider()
          .getTrackedEntityInstanceByIds(teiIds);

      if (unsyncedTeis.isNotEmpty) {
        await uploadTeisToTheServer(unsyncedTeis);
      }
      if (unsyncedTeiEnrollments.isNotEmpty) {
        await uploadEnrollmentsToTheServer(
          unsyncedTeiEnrollments,
          ignoreUnsyncedTeiFilter: true,
        );
      }
      if (unsyncedTeiEvents.isNotEmpty) {
        await uploadTeiEventsToTheServer(
          unsyncedTeiEvents,
          checkEnrollments: false,
        );
      }
    }
  }


  Future<List<TeiRelationship>> _deduplicateRelationshipsForUpload(
      List<TeiRelationship> relationships,
      ) async {
    final db = await OfflineDbProvider().db;
    final byNaturalKey = <String, TeiRelationship>{};

    for (final relationship in relationships) {
      final type = (relationship.relationshipType ?? '').trim();
      final from = (relationship.fromTei ?? '').trim();
      final to = (relationship.toTei ?? '').trim();
      if (type.isEmpty || from.isEmpty || to.isEmpty) continue;

      final key = '$type|$from|$to';
      byNaturalKey.putIfAbsent(key, () => relationship);
    }

    if (db != null) {
      // Clean historical duplicates locally so the same household/member
      // relationship cannot be posted again with another relationship UID.
      for (final relationship in byNaturalKey.values) {
        final type = (relationship.relationshipType ?? '').trim();
        final from = (relationship.fromTei ?? '').trim();
        final to = (relationship.toTei ?? '').trim();
        final keepId = (relationship.id ?? '').trim();
        if (keepId.isEmpty) continue;

        try {
          await db.delete(
            'tei_relationships',
            where:
            'relationshipType = ? AND fromTei = ? AND toTei = ? AND id <> ?',
            whereArgs: [type, from, to, keepId],
          );
        } catch (_) {}
      }
    }

    return byNaturalKey.values.toList();
  }

  Future<void> _markRelationshipSyncedByNaturalKey(
      TeiRelationship relationship,
      ) async {
    final db = await OfflineDbProvider().db;
    if (db == null) return;

    final type = (relationship.relationshipType ?? '').trim();
    final from = (relationship.fromTei ?? '').trim();
    final to = (relationship.toTei ?? '').trim();
    if (type.isEmpty || from.isEmpty || to.isEmpty) return;

    await db.update(
      'tei_relationships',
      {'syncStatus': onlineSyncStatus},
      where: 'relationshipType = ? AND fromTei = ? AND toTei = ?',
      whereArgs: [type, from, to],
    );
  }

  Future<bool> uploadTeiRelationToTheServer(
      List<TeiRelationship> teiRelationShips,
      ) async {
    final relationships =
    await _deduplicateRelationshipsForUpload(teiRelationShips);

    if (relationships.isEmpty) return false;

    final toUpload = <TeiRelationship>[];
    final relationshipsByFrom = <String, List<TeiRelationship>>{};

    for (final relationship in relationships) {
      final from = (relationship.fromTei ?? '').trim();
      if (from.isEmpty) continue;
      relationshipsByFrom.putIfAbsent(from, () => <TeiRelationship>[])
          .add(relationship);
    }

    // Before POSTing, ask DHIS2 whether the exact natural relationship
    // already exists. This is critical for old local databases where the
    // same Household->Member link may have been given a different local UID.
    for (final entry in relationshipsByFrom.entries) {
      final serverRelationships =
      await _getServerRelationshipIdsForFromTei(entry.key);

      for (final relationship in entry.value) {
        final type = (relationship.relationshipType ?? '').trim();
        final from = (relationship.fromTei ?? '').trim();
        final to = (relationship.toTei ?? '').trim();
        final key = '$type|$from|$to';

        final serverIds = serverRelationships[key] ?? const <String>[];

        if (serverIds.isNotEmpty) {
          // The link already exists on DHIS2. Do not POST another one.
          await _markRelationshipSyncedByNaturalKey(relationship);

          // Same pair/type can only represent one logical relationship.
          // Clean exact duplicate relationship records created by older builds.
          if (serverIds.length > 1) {
            for (final duplicateId in serverIds.skip(1)) {
              try {
                final deleteResponse = await httpClient.httpDelete(
                  'api/relationships/$duplicateId',
                );
                await _addSyncLog(
                  'DUPLICATE RELATIONSHIP CLEANUP [$duplicateId] '
                      'STATUS ${deleteResponse.statusCode}: ${deleteResponse.body}',
                );
              } catch (error) {
                await _addSyncLog(
                  'DUPLICATE RELATIONSHIP CLEANUP ERROR '
                      '[$duplicateId]: $error',
                );
              }
            }
          }

          continue;
        }

        toUpload.add(relationship);
      }
    }

    if (toUpload.isEmpty) return false;

    final Map<String, dynamic> body = {
      'relationships':
      toUpload.map((relationship) => relationship.toOnline()).toList(),
    };

    List<String?> syncedIds = [];
    bool conflictOnImport = false;
    var responseSucceeded = false;

    try {
      final response = await httpClient.httpPost(
        'api/relationships',
        json.encode(body),
        queryParameters: {
          'strategy': 'CREATE_AND_UPDATE',
          'mergeMode': 'MERGE',
        },
      );

      responseSucceeded =
          response.statusCode >= 200 && response.statusCode < 300;

      await _addSyncLog(
        'RELATIONSHIP SYNC RESPONSE ${response.statusCode}: ${response.body}',
      );

      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final referenceIds = await _getReferenceIds(
          decoded,
          skipErrorLogs: true,
        );
        syncedIds = (referenceIds['syncedIds'] ?? []).cast<String?>();
        conflictOnImport = referenceIds['conflictOnImport'] == true;
      }
    } catch (error) {
      conflictOnImport = true;
      await _addSyncLog('RELATIONSHIP SYNC ERROR: $error');
    }

    for (final relationship in toUpload) {
      final relationshipId = (relationship.id ?? '').trim();

      if ((relationshipId.isNotEmpty &&
          syncedIds.contains(relationshipId)) ||
          (responseSucceeded && !conflictOnImport)) {
        await _markRelationshipSyncedByNaturalKey(relationship);
      }
    }

    return conflictOnImport;
  }

  String getNginxErrorMessage(String responseBody) {
    String errorMessage = '';
    try {
      int errorMessageStart = responseBody.lastIndexOf('<h1>');
      int errorMessageEnd = responseBody.lastIndexOf('</h1>');
      if (errorMessageStart != -1 && errorMessageEnd != -1) {
        errorMessage = responseBody
            .substring(errorMessageStart, errorMessageEnd)
            .replaceAll(RegExp('<h1>'), '')
            .trim();
      }
    } catch (error) {
      rethrow;
    }
    return errorMessage;
  }

  String getDhis2TomcatErrorMessage(String responseBody) {
    String errorMessage = '';
    try {
      String status = '';
      String description = '';
      if (responseBody.toLowerCase().contains("<body")) {
        int descriptionStart = responseBody.lastIndexOf('<b>Description</b> ');
        int descriptionEnd = responseBody.lastIndexOf('</p>');
        int httpStatusStart = responseBody.lastIndexOf('<h1>HTTP');
        int httpStatusEnd = responseBody.lastIndexOf('</h1>');
        if (descriptionStart != -1 &&
            descriptionEnd != -1 &&
            httpStatusStart != -1 &&
            httpStatusEnd != -1) {
          description = responseBody
              .substring(descriptionStart, descriptionEnd)
              .replaceAll(RegExp('<b>Description</b>'), '')
              .trim();
          status = responseBody
              .substring(httpStatusStart, httpStatusEnd)
              .replaceAll(RegExp('<h1>'), '')
              .trim();
        } else {
          errorMessage = responseBody;
        }
      } else {
        Map body = json.decode(responseBody);
        status = body["httpStatus"] ?? "Error";
        description = body["message"] ?? responseBody;
      }
      errorMessage = '$status : $description';
    } catch (error) {
      rethrow;
    }
    return errorMessage;
  }

  Future<String> _getHttpResponseAppLogs(String responseBody) async {
    String logMessage = responseBody;
    try {
      if (responseBody.toLowerCase().contains('nginx')) {
        logMessage = getNginxErrorMessage(responseBody);
      } else {
        logMessage = getDhis2TomcatErrorMessage(responseBody);
      }
    } catch (error) {
      AppLogs log = AppLogs(
          type: AppLogsConstants.errorLogType,
          message: '_getHttpResponseAppLogs: ${error.toString()}');
      await AppLogsOfflineProvider().addLogs(log);
    }
    return logMessage;
  }

  Future<Map<String, dynamic>> _getReferenceIds(
      Map body, {
        bool skipErrorLogs = false,
      }) async {
    List<String?> syncedIds = [];
    List<String?> unsyncedDueToEnrollment = [];
    List<String?> unsyncedDueMissingBeneficiary = [];
    bool conflictOnImport = false;
    bool hasEnrollmentConflict = false;

    bool isNotEnrolledMessage(String? message) {
      final text = (message ?? '').toLowerCase();
      return text.contains('is not enrolled') ||
          text.contains('not enrolled to intervention') ||
          text.contains('beneficiaries not enrolled');
    }

    bool isMissingTrackedEntityMessage(String? message) {
      final text = (message ?? '').toLowerCase();
      return text.contains(
        'event.trackedentityinstance does not point to a valid tracked entity instance',
      );
    }

    void addUnique(List<String?> list, String? value) {
      if (value == null || value.trim().isEmpty) return;
      if (!list.contains(value)) list.add(value);
    }

    try {
      var bodyResponse = body['response'] ?? {};
      var importSummaries = bodyResponse['importSummaries'] ?? [];
      for (var importSummary in importSummaries) {
        if (importSummary['status'] == 'SUCCESS' &&
            importSummary['reference'] != null) {
          syncedIds.add(importSummary['reference']);
        } else if (!skipErrorLogs) {
          final reference = importSummary['reference']?.toString();
          final description = importSummary['description']?.toString();

          if (isNotEnrolledMessage(description)) {
            hasEnrollmentConflict = true;
            addUnique(unsyncedDueToEnrollment, reference);
          } else if (isMissingTrackedEntityMessage(description)) {
            addUnique(unsyncedDueMissingBeneficiary, reference);
          }

          if (importSummary['conflicts'] != null) {
            for (var conflict in importSummary['conflicts']) {
              final object = conflict['object']?.toString() ?? '';
              final value = conflict['value']?.toString() ?? '';
              final message = '$object: $value'.trim();

              if (isNotEnrolledMessage(message)) {
                hasEnrollmentConflict = true;
                addUnique(unsyncedDueToEnrollment, reference);
              } else if (isMissingTrackedEntityMessage(message)) {
                addUnique(unsyncedDueMissingBeneficiary, reference);
              }

              AppLogs log = AppLogs(
                type: AppLogsConstants.errorLogType,
                message: message,
              );
              await AppLogsOfflineProvider().addLogs(log);
            }
            conflictOnImport = true;
          } else if (description != null) {
            AppLogs log = AppLogs(
              type: AppLogsConstants.errorLogType,
              message: description,
            );
            await AppLogsOfflineProvider().addLogs(log);
            conflictOnImport = true;
          }
        }
      }
    } catch (error) {
      AppLogs log = AppLogs(
          type: AppLogsConstants.errorLogType,
          message: '_getReferenceIds: ${error.toString()}');
      await AppLogsOfflineProvider().addLogs(log);
    }

    Map<String, dynamic> referenceIds = {};
    referenceIds['syncedIds'] = syncedIds;
    referenceIds['unsyncedDueToEnrollment'] = unsyncedDueToEnrollment;
    referenceIds['unsyncedDueMissingBeneficiary'] =
        unsyncedDueMissingBeneficiary;
    referenceIds['conflictOnImport'] = conflictOnImport;
    referenceIds['hasEnrollmentConflict'] = hasEnrollmentConflict;
    return referenceIds;
  }
}