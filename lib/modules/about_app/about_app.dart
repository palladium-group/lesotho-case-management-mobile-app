import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/intervention_card_state/intervention_card_state.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/core/components/sub_page_app_bar.dart';
import 'package:lncmis_mobile_app/core/components/sup_page_body.dart';
import 'package:lncmis_mobile_app/models/intervention_card.dart';
import 'package:lncmis_mobile_app/modules/about_app/components/app_info_container.dart';
import 'package:lncmis_mobile_app/modules/about_app/components/user_info_container.dart';
import 'package:provider/provider.dart';

class AboutApp extends StatefulWidget {
  const AboutApp({Key? key}) : super(key: key);

  @override
  State<AboutApp> createState() => _AboutAppState();
}

class _AboutAppState extends State<AboutApp> {
  final String label = 'About App';
  final String translatedName = 'Mabapi le App';

  static const Color lncmisBlue = Color(0xFF0D47A1);
  static const Color lncmisLightBlue = Color(0xFF1976D2);
  static const Color pageBackground = Color(0xFFF4F7FC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65.0),
        child: Consumer<InterventionCardState>(
          builder: (context, interventionCardState, child) {
            InterventionCard activeInterventionProgram =
                interventionCardState.currentInterventionProgram;

            return SubPageAppBar(
              label: label,
              translatedName: translatedName,
              activeInterventionProgram: activeInterventionProgram,
              disableSelectionOfActiveIntervention: false,
            );
          },
        ),
      ),
      body: SubPageBody(
        body: Consumer<LanguageTranslationState>(
          builder: (context, languageTranslationState, child) {
            final String currentLanguage =
                languageTranslationState.currentLanguage;

            return Container(
              width: double.infinity,
              color: pageBackground,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeroHeader(currentLanguage: currentLanguage),
                  const SizedBox(height: 14),
                  AppInfoContainer(currentLanguage: currentLanguage),
                  const SizedBox(height: 14),
                  UserInfoContainer(currentLanguage: currentLanguage),
                  const SizedBox(height: 14),
                  _SystemNote(currentLanguage: currentLanguage),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    Key? key,
    required this.currentLanguage,
  }) : super(key: key);

  final String currentLanguage;

  static const Color lncmisBlue = Color(0xFF0D47A1);
  static const Color lncmisLightBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final bool isSesotho = currentLanguage == 'lesotho';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [lncmisBlue, lncmisLightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: lncmisBlue.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -22,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: -36,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/logos/app-logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.health_and_safety_outlined,
                        color: Colors.white,
                        size: 38,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LNCMIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lesotho National Case Management Information System',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.94),
                        fontSize: 13.2,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSesotho
                          ? 'Ministry of Gender, Youth and Social Development'
                          : 'Ministry of Gender, Youth and Social Development',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 11.8,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _HeroChip(
                          icon: Icons.cloud_sync_outlined,
                          label: 'Offline Ready',
                        ),
                        _HeroChip(
                          icon: Icons.security_outlined,
                          label: 'Secure Case Work',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    Key? key,
    required this.icon,
    required this.label,
  }) : super(key: key);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({
    Key? key,
    required this.currentLanguage,
  }) : super(key: key);

  final String currentLanguage;

  @override
  Widget build(BuildContext context) {
    final bool isSesotho = currentLanguage == 'lesotho';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSesotho
                  ? 'LNCMIS e thusa basebetsi ba sechaba ka case management, offline data capture le synchronization.'
                  : 'LNCMIS supports case management, offline data capture and synchronization for social workers.',
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 12.2,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
