import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/app_info_state/app_info_state.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/modules/about_app/utils/about_page_util.dart';
import 'package:provider/provider.dart';

class AppInfoContainer extends StatelessWidget {
  const AppInfoContainer({
    Key? key,
    required this.currentLanguage,
  }) : super(key: key);

  final String currentLanguage;

  static const Color lncmisBlue = Color(0xFF0D47A1);

  String _display(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty ? 'Not captured' : v;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageTranslationState>(
      builder: (context, languageState, child) {
        final bool isSesotho = languageState.currentLanguage == 'lesotho';

        return Consumer<AppInfoState>(
          builder: (context, appInfoState, child) {
            return AboutPageUtil.collapsibleSectionCard(
              initiallyExpanded: true,
              title: isSesotho ? 'Lintlha tsa App' : 'Application Information',
              subtitle: isSesotho
                  ? 'Version, package, server le boemo ba app.'
                  : 'Version, package, server and application status.',
              icon: Icons.phone_android_outlined,
              color: lncmisBlue,
              children: [
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          lncmisBlue.withOpacity(0.12),
                          const Color(0xFF1976D2).withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: lncmisBlue.withOpacity(0.12)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/logos/app-logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.health_and_safety_outlined,
                            color: lncmisBlue,
                            size: 46,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Lebitso la App' : 'App Name',
                  value: _display(appInfoState.currentAppName),
                  icon: Icons.apps_outlined,
                  color: lncmisBlue,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Mofuta oa App' : 'App Version',
                  value: _display(appInfoState.currentAppVersion),
                  icon: Icons.new_releases_outlined,
                  color: Colors.deepPurple,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'ID ea App' : 'App ID',
                  value: _display(appInfoState.currentAppId),
                  icon: Icons.fingerprint_outlined,
                  color: Colors.indigo,
                ),
                AboutPageUtil.infoTile(
                  label: isSesotho ? 'Server URL' : 'Server URL',
                  value: _display(appInfoState.serverUrl),
                  icon: Icons.cloud_outlined,
                  color: Colors.teal,
                ),
                const SizedBox(height: 4),
                AboutPageUtil.statusBanner(
                  icon: Icons.verified_outlined,
                  title: 'LNCMIS Mobile',
                  message: isSesotho
                      ? 'E etselitsoe ho sebetsa offline le online bakeng sa case management.'
                      : 'Designed for offline and online case-management work.',
                  color: Colors.green,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
