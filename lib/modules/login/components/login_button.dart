import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/modules/login/constants/login_page_style.dart';
import 'package:provider/provider.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({
    Key? key,
    required this.isLoginProcessActive,
    this.onLogin,
    required this.currentLanguage,
  }) : super(key: key);

  final bool isLoginProcessActive;
  final VoidCallback? onLogin;
  final String? currentLanguage;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageTranslationState>(
      builder: (context, languageState, child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 20.0),
        child: TextButton.icon(
          onPressed: isLoginProcessActive ? null : onLogin,
          icon: isLoginProcessActive
              ? const SizedBox.shrink()
              : const Icon(Icons.login_rounded, color: Colors.white, size: 20),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            backgroundColor: isLoginProcessActive
                ? LoginPageStyles.lncmisBlue.withOpacity(0.70)
                : LoginPageStyles.lncmisBlue,
            foregroundColor: Colors.white,
            shadowColor: LoginPageStyles.lncmisBlue.withOpacity(0.30),
          ),
          label: isLoginProcessActive
              ? const SizedBox(
                  height: 21.0,
                  width: 21.0,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                    strokeWidth: 2.0,
                  ),
                )
              : Text(
                  languageState.currentLanguage == 'lesotho' ? 'Kena' : 'Sign In',
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
