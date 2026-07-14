import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/intervention_card_state/intervention_card_state.dart';
import 'package:lncmis_mobile_app/core/utils/app_bar_util.dart';
import 'package:lncmis_mobile_app/models/intervention_card.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/case_shell/pages/mgysd_case_management_home.dart';
import 'package:provider/provider.dart';

class MgysdCaseManagement extends StatefulWidget {
  const MgysdCaseManagement({Key? key}) : super(key: key);

  @override
  State<MgysdCaseManagement> createState() => _MgysdCaseManagementState();
}

class _MgysdCaseManagementState extends State<MgysdCaseManagement> {
  InterventionCard? interventionCard;

  @override
  void initState() {
    super.initState();
    interventionCard =
        Provider.of<InterventionCardState>(context, listen: false)
            .currentInterventionProgram;
  }

  @override
  Widget build(BuildContext context) {
    final InterventionCard current = interventionCard ??
        InterventionCard(
          id: 'mgysd',
          name: 'LNCMIS Case Management',
          primaryColor: const Color(0xFF0D47A1),
          secondaryColor: const Color(0xFF1976D2),
        );

    final Color themeColor =
        current.primaryColor ?? const Color(0xFF0D47A1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        title: Text(
          current.name ?? 'LNCMIS Case Management',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              AppBarUtil.onOpenMoreMenu(
                context,
                current,
                true,
              );
            },
          ),
        ],
      ),
      body: const MgysdCaseManagementHome(),
    );
  }
}
