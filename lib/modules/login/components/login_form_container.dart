import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/app_state/login_form_state/login_form_state.dart';
import 'package:lncmis_mobile_app/modules/login/components/login_form.dart';
import 'package:lncmis_mobile_app/modules/login/constants/login_page_style.dart';
import 'package:provider/provider.dart';

class LoginFormContainer extends StatelessWidget {
  const LoginFormContainer({
    Key? key,
    required this.currentLanguage,
    required this.appLabel,
  }) : super(key: key);

  final String? currentLanguage;
  final String appLabel;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageTranslationState>(
      builder: (context, languageState, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: LoginPageStyles.lncmisBlue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.lock_person_outlined,
                        color: LoginPageStyles.lncmisBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageState.currentLanguage == 'lesotho'
                                ? 'Kena ho LNCMIS'
                                : 'Welcome Back',
                            style: const TextStyle(
                              color: LoginPageStyles.lncmisText,
                              fontSize: 21.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            languageState.currentLanguage == 'lesotho'
                                ? 'Kena ka akhaonte ea hau ea DHIS2.'
                                : 'Sign in using your DHIS2 account.',
                            style: const TextStyle(
                              color: LoginPageStyles.lncmisMuted,
                              fontSize: 12.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LoginForm(currentLanguage: currentLanguage),
                const SizedBox(height: 12),
                Consumer<LoginFormState>(builder: (context, loginFormState, child) {
                  final message = loginFormState.currentLoginProcessMessage.trim();
                  if (message.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: LoginPageStyles.lncmisBlue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: LoginPageStyles.lncmisBlue.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: LoginPageStyles.lncmisBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: LoginPageStyles.lncmisMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (appLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      languageState.currentLanguage == 'lesotho'
                          ? 'Ela Hloko: Ena ke $appLabel'
                          : 'NB: This is $appLabel',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
