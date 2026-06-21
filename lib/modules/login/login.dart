import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/core/services/device_connectivity_provider.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/modules/login/components/login_form_container.dart';
import 'package:lncmis_mobile_app/modules/login/components/login_top_icon.dart';
import 'package:lncmis_mobile_app/modules/login/constants/login_page_style.dart';
import 'package:provider/provider.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final String appLabel = "";
  final String translatedAppLabel = "";
  late StreamSubscription connectionSubscription;

  @override
  void initState() {
    super.initState();
    connectionSubscription = DeviceConnectivityProvider()
        .checkChangeOfDeviceConnectionStatus(context);
    AppUtil.setStatusBarColor(LoginPageStyles.lncmisBlueDark);
  }

  @override
  void dispose() {
    connectionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: LoginPageStyles.lncmisBlue,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LoginPageStyles.lncmisBlueDark,
                LoginPageStyles.lncmisBlue,
                LoginPageStyles.lncmisBlueLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -80,
                right: -70,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Consumer<LanguageTranslationState>(
                  builder: (context, languageTranslationState, child) {
                    String? currentLanguage = languageTranslationState.currentLanguage;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          LoginTopIcon(
                            appLabel: currentLanguage == 'lesotho'
                                ? translatedAppLabel
                                : appLabel,
                          ),
                          LoginFormContainer(
                            currentLanguage: currentLanguage,
                            appLabel: currentLanguage == 'lesotho'
                                ? translatedAppLabel
                                : appLabel,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            currentLanguage == 'lesotho'
                                ? 'Ministry of Gender, Youth and Social Development'
                                : 'Ministry of Gender, Youth and Social Development',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.86),
                              fontSize: 12.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'LNCMIS v1.0.0',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
