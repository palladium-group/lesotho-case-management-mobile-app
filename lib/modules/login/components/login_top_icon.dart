import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/modules/login/constants/login_page_style.dart';

class LoginTopIcon extends StatelessWidget {
  final String appLabel;

  const LoginTopIcon({
    Key? key,
    required this.appLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30, bottom: 18),
      child: Column(
        children: [
          if (appLabel.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
              ),
              child: Text(
                appLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              size: 42,
              color: LoginPageStyles.lncmisBlue,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'LNCMIS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Lesotho National Case Management\nInformation System',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: 13.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  LoginPageStyles.lncmisBlueLight.withOpacity(0.95),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
