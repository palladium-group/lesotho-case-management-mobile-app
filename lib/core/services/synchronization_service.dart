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

class SynchronizationService {
  late HttpService httpClient;

  final List? programs;
  final List? orgUnitIds;

  final String offlineSyncStatus = 'not-synced';
  final String onlineSyncStatus = 'synced';

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
          "event,program,programStage,trackedEntityInstance,status,orgUnit,dataValues[dataElement,value,displayName],eventDate",
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
            LocalNotificationService.show(
              message:
              "Failed to upload some Beneficiaries service data. Check app logs for more information",
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
      for (Enrollment teiEnrollment in teiEnrollments) {
        if (syncedIds.contains(teiEnrollment.enrollment)) {
          teiEnrollment.syncStatus = onlineSyncStatus;
          await FormUtil.savingEnrollment(teiEnrollment);
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

  Future<bool> uploadTeisToTheServer(
      List<TrackedEntityInstance> teis,
      ) async {
    List<String?>? syncedIds = [];
    String url = 'api/trackedEntityInstances';
    bool conflictOnImport = false;
    Map body = {};
    body['trackedEntityInstances'] = teis.map((tei) {
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
      for (TrackedEntityInstance tei in teis) {
        if (syncedIds.contains(tei.trackedEntityInstance)) {
          tei.syncStatus = onlineSyncStatus;
          await FormUtil.savingTrackedEntityInstance(tei);
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


  Future<bool> uploadTeiEventsToTheServer(
      List<Events> teiEvents, {
        bool checkEnrollments = true,
      }) async {
    List<String?> syncedIds = [];
    String url = 'api/events';
    bool conflictOnImport = false;

    bool isPlaceholder(String value) {
      final v = value.trim();
      return v.isEmpty ||
          v.startsWith('DE_') ||
          v.startsWith('MGYSD_') ||
          v.contains('_UID');
    }

    if (checkEnrollments && teiEvents.isNotEmpty) {
      await _uploadBeneficiariesAndEnrollmentsForEventBatch(teiEvents);
    }

    Map body = {};

    body['events'] = teiEvents.map((Events event) {
      var data = event.toOffline(event);

      data.remove('syncStatus');

      if (isPlaceholder((data['programStage'] ?? '').toString())) {
        data.remove('programStage');
      }

      if (data['trackedEntityInstance'] == null ||
          data['trackedEntityInstance'].toString().trim().isEmpty) {
        data.remove('trackedEntityInstance');
      }

      if (data['enrollment'] == null ||
          data['enrollment'].toString().trim().isEmpty) {
        data.remove('enrollment');
      }

      if (data['dataValues'] != null) {
        data['dataValues'].removeWhere((item) {
          final dataElement = (item['dataElement'] ?? '').toString();
          final value = (item['value'] ?? '').toString();

          return dataElement == 'eventDate' ||
              isPlaceholder(dataElement) ||
              value.trim().isEmpty ||
              value.trim() == 'null';
        });
      }

      return data;
    }).toList();

    try {
      print('======================================');
      print('EVENT SYNC START');
      print('EVENT COUNT: ${teiEvents.length}');
      print('REQUEST BODY:');
      print(const JsonEncoder.withIndent('  ').convert(body));
      print('======================================');

      var response = await httpClient.httpPost(
        url,
        json.encode(body),
        queryParameters: {
          "strategy": "CREATE_AND_UPDATE",
        },
      );

      print('======================================');
      print('DHIS2 EVENT RESPONSE STATUS: ${response.statusCode}');
      print('DHIS2 EVENT RESPONSE BODY:');
      print(response.body);
      print('======================================');

      await AppLogsOfflineProvider().addLogs(
        AppLogs(
          type: AppLogsConstants.errorLogType,
          message: 'EVENT SYNC RESPONSE ${response.statusCode}: ${response.body}',
        ),
      );

      if (response.statusCode >= 400 && response.statusCode != 409) {
        return true;
      }

      final Map<String, dynamic> responseJson = json.decode(response.body);
      final Map<String, dynamic> referenceIds =
      await _getReferenceIds(responseJson);

      syncedIds = (referenceIds['syncedIds'] ?? []).cast<String?>();
      conflictOnImport = referenceIds['conflictOnImport'] == true;

      await reUploadBeneficiariesWithUnsyncedServices(
        referenceIds,
        checkEnrollments,
        teiEvents,
      );

      if (syncedIds.isNotEmpty) {
        for (Events event in teiEvents) {
          if (syncedIds.contains(event.event)) {
            event.syncStatus = onlineSyncStatus;
            await FormUtil.savingEvent(event);
          }
        }
      }

      return conflictOnImport;
    } catch (error, stackTrace) {
      print('EVENT SYNC EXCEPTION');
      print(error);
      print(stackTrace);

      await AppLogsOfflineProvider().addLogs(
        AppLogs(
          type: AppLogsConstants.errorLogType,
          message: 'uploadTeiEventsToTheServer EXCEPTION: $error',
        ),
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

  Future<bool> uploadTeiRelationToTheServer(
      List<TeiRelationship> teiRelationShips,
      ) async {
    Map body = <String, dynamic>{};
    List<String?>? syncedIds = [];
    String url = 'api/relationships';
    bool conflictOnImport = false;
    body['relationships'] = teiRelationShips
        .map((relationship) => relationship.toOnline())
        .toList();
    try {
      var queryParameters = {
        "strategy": "CREATE_AND_UPDATE",
      };
      var response = await httpClient.httpPost(
        url,
        json.encode(body),
        queryParameters: queryParameters,
      );
      var referenceIds = await _getReferenceIds(
        json.decode(response.body),
        skipErrorLogs: true,
      );
      syncedIds = referenceIds['syncedIds'];
      conflictOnImport = conflictOnImport || referenceIds['conflictOnImport'];
    } catch (error) {
      //
    }
    if (syncedIds!.isNotEmpty) {
      for (TeiRelationship teiRelationship in teiRelationShips) {
        if (syncedIds.contains(teiRelationship.id)) {
          teiRelationship.syncStatus = onlineSyncStatus;
          await FormUtil.savingTeiRelationship(teiRelationship);
        }
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