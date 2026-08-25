import 'package:lncmis_mobile_app/core/constants/user_account_reference.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/models/events.dart';
import 'package:sqflite/sqflite.dart';

class EventOfflineDataValueProvider extends OfflineDbProvider {
  final String table = 'event_data_value';

  // columns
  final String id = 'id';
  final String event = 'event';
  final String dataElement = 'dataElement';
  final String value = 'value';

  static const Set<String> _dhis2BooleanDataElementIds = {
    // Initial Risk Assessment
    'MueBNV7Q8Dv', // Self-Care
    'LP3qsc3lbwf', // Disability diagnosis
    'fMIT7ZRxfJa', // Assistive devices
    'aNCWaj2uiNT', // Rehabilitation services
  };

  String _normaliseEventDataValue(String dataElementId, String rawValue) {
    final cleanDataElementId = dataElementId.trim();
    final cleanValue = rawValue.trim();

    if (cleanValue.isEmpty || cleanValue == 'null') {
      return '';
    }

    if (!_dhis2BooleanDataElementIds.contains(cleanDataElementId)) {
      return cleanValue;
    }

    final upperValue = cleanValue.toUpperCase();

    switch (upperValue) {
      case 'YES':
      case 'Y':
      case 'TRUE':
      case '1':
        return 'true';

      case 'NO':
      case 'N':
      case 'FALSE':
      case '0':
        return 'false';

      default:
      // This prevents DHIS2 value_not_bool errors.
      // If this field has an unexpected value, do not upload it.
        return '';
    }
  }

  addOrUpdateEventDataValues(Events eventData) async {
    var dbClient = await db;

    try {
      List dataValues = eventData.dataValues ?? [];
      String? eventId = eventData.event;

      for (Map dataValue in dataValues) {
        final dataElementId = '${dataValue['dataElement'] ?? ''}'.trim();
        final rawValue = '${dataValue['value'] ?? ''}'.trim();

        if (dataElementId.isEmpty || eventId == null || eventId.isEmpty) {
          continue;
        }

        final normalisedValue =
        _normaliseEventDataValue(dataElementId, rawValue);

        if (normalisedValue.isEmpty || normalisedValue == 'null') {
          continue;
        }

        Map data = <String, dynamic>{};
        data['id'] = '$eventId-$dataElementId';
        data['event'] = eventId;
        data['dataElement'] = dataElementId;
        data['value'] = normalisedValue;

        await dbClient!.insert(
          table,
          data as Map<String, Object?>,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      // Saving event data values is part of the transaction from the user's
      // point of view. Do not hide write failures because that produces a
      // "saved" form that can never synchronize correctly.
      rethrow;
    }
  }

  Future<List> getEventDataValuesByEventId(
      String? eventId,
      ) async {
    List dataValues = [];

    try {
      var dbClient = await db;

      List<Map> maps = await dbClient!.query(
        table,
        columns: [dataElement, value],
        where: '$event = ?',
        whereArgs: [eventId],
      );

      if (maps.isNotEmpty) {
        for (Map map in maps) {
          final dataElementId = '${map[dataElement] ?? ''}'.trim();
          final rawValue = '${map[value] ?? ''}'.trim();

          if (dataElementId.isEmpty) {
            continue;
          }

          final normalisedValue =
          _normaliseEventDataValue(dataElementId, rawValue);

          if (normalisedValue.isEmpty || normalisedValue == 'null') {
            continue;
          }

          dataValues.add({
            'dataElement': dataElementId,
            'value': normalisedValue,
          });
        }
      }
    } catch (e) {
      //
    }

    return dataValues;
  }

  Future<void> reduceDeviceInformationDataValues() async {
    var deviceInfoId = UserAccountReference.appAndDeviceTrackingDataElement;

    try {
      var dbClient = await db;

      await dbClient!.rawUpdate(
        'UPDATE $table SET $value = SUBSTR($value, 0, 1190) WHERE $dataElement = ? AND LENGTH($value) > 1199',
        [deviceInfoId],
      );
    } catch (e) {
      rethrow;
    }
  }
}