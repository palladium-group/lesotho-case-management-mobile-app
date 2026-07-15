import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/pages/mgysd_repeatable_stage_list_page.dart';

class MgysdHouseholdMonitoringListPage extends StatelessWidget {
  const MgysdHouseholdMonitoringListPage({
    Key? key,
    required this.color,
    required this.householdCase,
    required this.householdTei,
    required this.enrollment,
    required this.householdName,
    required this.clientName,
  }) : super(key: key);

  final Color color;
  final MgysdCase householdCase;
  final String householdTei;
  final String enrollment;
  final String householdName;
  final String clientName;

  @override
  Widget build(BuildContext context) {
    return MgysdRepeatableStageListPage(
      color: color,
      parentCase: householdCase,
      stageTitle: 'Household Monitoring',
      tableName: 'mgysd_monitoring',
      stageKey: 'monitoring',
      programStage: MgysdDhis2Uids.monitoringStage,
      icon: Icons.monitor_heart_outlined,
      trackedEntityInstance: householdTei,
      enrollment: enrollment,
      householdTei: householdTei,
      householdName: householdName,
      clientName: clientName,
      subjectName: clientName,
      subjectRole: 'HOUSEHOLD',
    );
  }
}
