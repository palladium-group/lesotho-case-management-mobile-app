import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/intervention_card_state/intervention_card_state.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/home/assessment/mgysd_assessment_workspace.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/home/reporting/mgysd_reporting_workspace.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/home/services/mgysd_services_workspace.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/home/monitoring/mgysd_monitoring_workspace.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/home/shared/mgysd_workspace_placeholder.dart';
import 'package:provider/provider.dart';

class MgysdCaseManagementHome extends StatefulWidget {
  const MgysdCaseManagementHome({Key? key}) : super(key: key);

  @override
  State<MgysdCaseManagementHome> createState() =>
      _MgysdCaseManagementHomeState();
}

class _MgysdCaseManagementHomeState extends State<MgysdCaseManagementHome> {
  static const Color _fallbackBlue = Color(0xFF0D47A1);

  int _selectedIndex = 0;

  Color _primaryColor(BuildContext context) {
    return Provider.of<InterventionCardState>(context, listen: false)
            .currentInterventionProgram
            .primaryColor ??
        _fallbackBlue;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _primaryColor(context);

    final List<Widget> pages = <Widget>[
      MgysdReportingWorkspace(color: color),
      MgysdAssessmentWorkspace(color: color),
      MgysdServicesWorkspace(color: color),
      MgysdMonitoringWorkspace(color: color),
      MgysdWorkspacePlaceholder(
        color: color,
        icon: Icons.handshake_outlined,
        title: 'Referral',
        message:
            'Open, pending and completed referrals will be managed from this workspace.',
      ),
      MgysdWorkspacePlaceholder(
        color: color,
        icon: Icons.task_alt_outlined,
        title: 'Closure',
        message:
            'Cases ready for review and closure will appear here with supporting checks.',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: color.withOpacity(0.12),
          labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
            (Set<MaterialState> states) => TextStyle(
              color: states.contains(MaterialState.selected)
                  ? color
                  : Colors.blueGrey,
              fontSize: 9.7,
              fontWeight: states.contains(MaterialState.selected)
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
          iconTheme: MaterialStateProperty.resolveWith<IconThemeData>(
            (Set<MaterialState> states) => IconThemeData(
              color: states.contains(MaterialState.selected)
                  ? color
                  : Colors.blueGrey,
              size: 22,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.assignment_ind_outlined),
              selectedIcon: Icon(Icons.assignment_ind),
              label: 'Intake',
            ),
            NavigationDestination(
              icon: Icon(Icons.manage_search_outlined),
              selectedIcon: Icon(Icons.manage_search),
              label: 'Investigation',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'Services',
            ),
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart),
              label: 'Monitoring',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake),
              label: 'Referral',
            ),
            NavigationDestination(
              icon: Icon(Icons.task_alt_outlined),
              selectedIcon: Icon(Icons.task_alt),
              label: 'Closure',
            ),
          ],
        ),
      ),
    );
  }
}
