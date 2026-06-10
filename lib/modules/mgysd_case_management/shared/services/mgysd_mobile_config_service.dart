import 'dart:convert';

import 'package:lncmis_mobile_app/core/offline_db/user_access_offline/user_access_offline.dart';
import 'package:lncmis_mobile_app/core/services/http_service.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_mobile_config.dart';

class MgysdMobileConfigService {
  static const String namespace = 'lodiis-mgysd-config';
  static const String key = 'mobile-config';
  static const String offlineId = 'mgysd-mobile-config';

  String get url => 'api/dataStore/$namespace/$key';

  /// Example DHIS2 datastore location:
  /// api/dataStore/lodiis-mgysd-config/mobile-config
  Future<MgysdMobileConfig> getConfigFromServer(
    String? username,
    String? password,
  ) async {
    try {
      final http = HttpService(
        username: username,
        password: password,
      );

      final response = await http.httpGet(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final config = MgysdMobileConfig.fromJson(decoded);
        await saveConfig(config);
        return config;
      }
    } catch (_) {
      // fallback to offline config below
    }

    return getSavedConfig();
  }

  Future<void> saveConfig(MgysdMobileConfig config) async {
    await UserAccessOfflineProvider().addOrUpdateUserAccess(
      offlineId,
      json.encode(config.toJson()),
    );
  }

  Future<MgysdMobileConfig> getSavedConfig() async {
    try {
      final saved = await UserAccessOfflineProvider()
          .getAllUserAccessConfigurationById(offlineId);

      if (saved == null || saved.toString().trim().isEmpty) {
        return MgysdMobileConfig.disabled();
      }

      return MgysdMobileConfig.fromJson(json.decode(saved.toString()));
    } catch (_) {
      return MgysdMobileConfig.disabled();
    }
  }
}
