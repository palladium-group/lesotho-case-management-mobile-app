import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/intervention_card_state/intervention_card_state.dart';
import 'package:lncmis_mobile_app/core/components/material_card.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/case_shell/pages/mgysd_case_list_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/enrollment/pages/mgysd_new_case_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/enrollment/pages/mgysd_report_case_page.dart';
import 'package:provider/provider.dart';

import '../../../synchronization/synchronization.dart';

class MgysdCaseManagementHome extends StatelessWidget {
  const MgysdCaseManagementHome({Key? key}) : super(key: key);

  static const Color lncmisBlue = Color(0xFF0D47A1);
  static const Color pageBackground = Color(0xFFF4F7FC);

  Color _primaryColor(BuildContext context) {
    return Provider.of<InterventionCardState>(context, listen: false)
        .currentInterventionProgram
        .primaryColor ??
        lncmisBlue;
  }

  void _openCaseList(BuildContext context, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MgysdCaseListPage(color: color),
      ),
    );
  }

  void _openIntake(BuildContext context, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MgysdNewCasePage(color: color),
      ),
    );
  }

  void _openReportCase(BuildContext context, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MgysdRecordCasePage(color: color),
      ),
    );
  }

  void _openSynchronization(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Synchronization(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _primaryColor(context);

    return Container(
      color: pageBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderPanel(color: color),
            const SizedBox(height: 14),
            _PrimaryWorkPanel(
              color: color,
              onReportCase: () => _openReportCase(context, color),
              onListCases: () => _openCaseList(context, color),
              onOpenIntake: () => _openIntake(context, color),
            ),
            const SizedBox(height: 14),
            _SyncPanel(
              color: color,
              onTap: () => _openSynchronization(context),
            ),
            const SizedBox(height: 14),
            _SupportMessagePanel(color: color),
          ],
        ),
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return MaterialCard(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              const Color(0xFF1976D2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -38,
              top: -42,
              child: _SoftCircle(size: 135),
            ),
            Positioned(
              right: 28,
              bottom: -52,
              child: _SoftCircle(size: 96),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Case Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'A focused workspace for reporting, intake and continuing LNCMIS case work.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.6,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({
    Key? key,
    required this.size,
  }) : super(key: key);

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.07),
      ),
    );
  }
}

class _PrimaryWorkPanel extends StatelessWidget {
  const _PrimaryWorkPanel({
    Key? key,
    required this.color,
    required this.onReportCase,
    required this.onListCases,
    required this.onOpenIntake,
  }) : super(key: key);

  final Color color;
  final VoidCallback onReportCase;
  final VoidCallback onListCases;
  final VoidCallback onOpenIntake;

  @override
  Widget build(BuildContext context) {
    return MaterialCard(
      body: Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelTitle(
              color: color,
              title: 'Workspace',
              subtitle: 'Choose what you want to do next.',
            ),
            const SizedBox(height: 13),
            _FeaturedAction(
              color: color,
              icon: Icons.report_problem_outlined,
              title: 'Report a Case',
              subtitle:
              'Capture a new concern quickly. Use this when a case has not yet been registered.',
              buttonLabel: 'Start report',
              onTap: onReportCase,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CompactAction(
                    color: const Color(0xFF1976D2),
                    icon: Icons.folder_open_outlined,
                    title: 'List Cases',
                    subtitle: 'Search, view and continue case work.',
                    onTap: onListCases,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactAction(
                    color: const Color(0xFF00897B),
                    icon: Icons.assignment_ind_outlined,
                    title: 'Open Intake',
                    subtitle: 'Register or complete intake details.',
                    onTap: onOpenIntake,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncPanel extends StatelessWidget {
  const _SyncPanel({
    Key? key,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MaterialCard(
      body: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.cloud_sync_outlined,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Synchronization',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.8,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload saved records and download the latest cases, metadata and user assignments.',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.1,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: color,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportMessagePanel extends StatelessWidget {
  const _SupportMessagePanel({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return MaterialCard(
      body: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.045),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: color, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Work can be captured offline. When connectivity is available, run Data Synchronization to safely upload new reports, intake records, assessments, referrals and monitoring updates.',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.2,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    Key? key,
    required this.color,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedAction extends StatelessWidget {
  const _FeaturedAction({
    Key? key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  }) : super(key: key);

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.065),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.1,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    Key? key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const Spacer(),
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.7,
                  color: Colors.blueGrey,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
