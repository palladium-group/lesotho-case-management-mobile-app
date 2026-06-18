import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/intervention_card_state/intervention_card_state.dart';
import 'package:lncmis_mobile_app/app_state/language_translation_state/language_translation_state.dart';
import 'package:lncmis_mobile_app/core/components/entry_form_save_button.dart';
import 'package:lncmis_mobile_app/core/components/material_card.dart';
import 'package:lncmis_mobile_app/modules/synchronization/constants/synchronization_actions_constants.dart';
import 'package:provider/provider.dart';

class OfflineDataSummary extends StatelessWidget {
  const OfflineDataSummary({
    Key? key,
    required this.beneficiaryCount,
    required this.beneficiaryServiceCount,
    required this.onInitializeSyncAction,
    required this.syncAction,
    this.isSyncActive = false,
    this.unsyncedHouseholdCount,
    this.unsyncedClientCount,
    this.unsyncedFormCount,
    this.unsyncedAssessmentCount = 0,
    this.unsyncedInvestigationCount = 0,
    this.unsyncedCarePlanCount = 0,
    this.unsyncedServiceProvisionCount = 0,
    this.unsyncedReferralCount = 0,
    this.unsyncedMonitoringCount = 0,
    this.failedSyncCount = 0,
    this.lastSyncLabel,
  }) : super(key: key);

  final int beneficiaryCount;
  final int beneficiaryServiceCount;
  final Function(String) onInitializeSyncAction;
  final String syncAction;
  final bool isSyncActive;

  final int? unsyncedHouseholdCount;
  final int? unsyncedClientCount;
  final int? unsyncedFormCount;
  final int unsyncedAssessmentCount;
  final int unsyncedInvestigationCount;
  final int unsyncedCarePlanCount;
  final int unsyncedServiceProvisionCount;
  final int unsyncedReferralCount;
  final int unsyncedMonitoringCount;
  final int failedSyncCount;
  final String? lastSyncLabel;

  int get _hhCount => unsyncedHouseholdCount ?? beneficiaryCount;
  int get _clientCount => unsyncedClientCount ?? 0;

  int get _computedFormCount {
    final detailed = unsyncedAssessmentCount +
        unsyncedInvestigationCount +
        unsyncedCarePlanCount +
        unsyncedServiceProvisionCount +
        unsyncedReferralCount +
        unsyncedMonitoringCount;

    if (unsyncedFormCount != null) return unsyncedFormCount!;
    return detailed > 0 ? detailed : beneficiaryServiceCount;
  }

  int get _totalPending =>
      _hhCount + _clientCount + _computedFormCount + failedSyncCount;

  void _onSyncButtonPress() {
    onInitializeSyncAction(syncAction);
  }

  String _buttonLabel(String lang) {
    if (isSyncActive) {
      return lang == 'lesotho' ? 'Sync e ntse e sebetsa...' : 'Sync in progress...';
    }

    if (syncAction == SynchronizationActionsConstants.download) {
      return lang == 'lesotho' ? 'Khoasolla data' : 'Download Data';
    }

    if (syncAction == SynchronizationActionsConstants.downloadAndUpload) {
      return lang == 'lesotho' ? 'Khoasolla le ho Upload' : 'Download & Upload';
    }

    return lang == 'lesotho' ? 'Upload liphetoho' : 'Upload Changes';
  }

  String _message(String lang) {
    if (isSyncActive) {
      return lang == 'lesotho'
          ? 'Data e ntse e romelloa kapa e khoasolloa. Ka kopo se koale app.'
          : 'Data is currently being uploaded or downloaded. Please keep the app open.';
    }

    if (_totalPending == 0) {
      return lang == 'lesotho'
          ? 'Ha ho liphetoho tse emetseng ho romelloa.'
          : 'Everything looks synced. No local LNCMIS records are waiting to upload.';
    }

    if (failedSyncCount > 0) {
      return lang == 'lesotho'
          ? 'Ho na le lirekoto tse hlolehileng ho sync. Leka hape kapa hlahloba app logs.'
          : '$failedSyncCount record${failedSyncCount == 1 ? '' : 's'} failed to sync. Try again or review app logs.';
    }

    return lang == 'lesotho'
        ? 'Ho na le data ea LNCMIS e bolokiloeng fonong ena e emetseng ho upload.'
        : 'There are LNCMIS records saved on this device that still need to upload.';
  }

  Color _statusColor(Color primaryColor) {
    if (failedSyncCount > 0) return Colors.redAccent;
    if (_totalPending > 0) return Colors.deepOrange;
    return Colors.green;
  }

  IconData _statusIcon() {
    if (isSyncActive) return Icons.sync;
    if (failedSyncCount > 0) return Icons.error_outline;
    if (_totalPending > 0) return Icons.cloud_upload_outlined;
    return Icons.cloud_done_outlined;
  }

  Widget _metricCard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.075),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.14)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No pending uploads. Household records, forms and services on this device appear synced.',
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsList(Color primaryColor) {
    final rows = <Widget>[
      _detailRow(
        label: 'Unsynced households',
        count: _hhCount,
        icon: Icons.home_work_outlined,
        color: primaryColor,
      ),
      _detailRow(
        label: 'Unsynced clients / family members',
        count: _clientCount,
        icon: Icons.groups_2_outlined,
        color: Colors.indigo,
      ),
      _detailRow(
        label: 'Initial assessment / intake forms',
        count: unsyncedAssessmentCount,
        icon: Icons.fact_check_outlined,
        color: Colors.deepPurple,
      ),
      _detailRow(
        label: 'Social investigation forms',
        count: unsyncedInvestigationCount,
        icon: Icons.manage_search_outlined,
        color: Colors.blue,
      ),
      _detailRow(
        label: 'Care plan records',
        count: unsyncedCarePlanCount,
        icon: Icons.assignment_outlined,
        color: Colors.teal,
      ),
      _detailRow(
        label: 'Service provision records',
        count: unsyncedServiceProvisionCount > 0
            ? unsyncedServiceProvisionCount
            : beneficiaryServiceCount,
        icon: Icons.volunteer_activism_outlined,
        color: Colors.green,
      ),
      _detailRow(
        label: 'Referral records',
        count: unsyncedReferralCount,
        icon: Icons.handshake_outlined,
        color: Colors.orange,
      ),
      _detailRow(
        label: 'Monitoring records',
        count: unsyncedMonitoringCount,
        icon: Icons.monitor_heart_outlined,
        color: Colors.pink,
      ),
      _detailRow(
        label: 'Failed sync records',
        count: failedSyncCount,
        icon: Icons.error_outline,
        color: Colors.redAccent,
      ),
    ].where((item) => item is! SizedBox).toList();

    if (_totalPending == 0 && beneficiaryServiceCount == 0) {
      return _emptyState();
    }

    if (rows.isEmpty) {
      return _detailRow(
        label: 'Unsynced forms / services',
        count: beneficiaryServiceCount,
        icon: Icons.description_outlined,
        color: Colors.green,
      );
    }

    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageTranslationState>(
      builder: (context, languageState, child) {
        final primaryColor =
            Provider.of<InterventionCardState>(context, listen: false)
                .currentInterventionProgram
                .primaryColor;

        final statusColor = _statusColor(primaryColor!);

        final bool hasAnythingToUpload =
            _totalPending > 0 || beneficiaryServiceCount > 0;

        final bool enabledByAction =
        syncAction == SynchronizationActionsConstants.upload
            ? hasAnythingToUpload
            : true;

        final bool canPress = !isSyncActive && enabledByAction;

        return MaterialCard(
          body: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.075),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: statusColor.withOpacity(0.16)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor: statusColor.withOpacity(0.13),
                        child: isSyncActive
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: statusColor,
                          ),
                        )
                            : Icon(_statusIcon(), color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LNCMIS Sync Readiness',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _message(languageState.currentLanguage),
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                height: 1.32,
                              ),
                            ),
                            if ((lastSyncLabel ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Last sync: ${lastSyncLabel!.trim()}',
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metricCard(
                      label: 'Households',
                      value: _hhCount,
                      icon: Icons.home_work_outlined,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _metricCard(
                      label: 'Forms',
                      value: _computedFormCount,
                      icon: Icons.description_outlined,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(width: 8),
                    _metricCard(
                      label: 'Failed',
                      value: failedSyncCount,
                      icon: Icons.error_outline,
                      color: failedSyncCount > 0
                          ? Colors.redAccent
                          : Colors.blueGrey,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pending sync details',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _detailsList(primaryColor),
                const SizedBox(height: 14),
                EntryFormSaveButton(
                  marginLeft: 0,
                  marginRight: 0,
                  vertical: 6.0,
                  label: _buttonLabel(languageState.currentLanguage),
                  svgIconPath: 'assets/icons/sync.svg',
                  svgIconHeight: 15.0,
                  svgIconWidth: 15.0,
                  labelColor: Colors.white,
                  buttonColor:
                  canPress ? primaryColor : Colors.blueGrey.withOpacity(0.45),
                  fontSize: 15.0,
                  onPressButton: canPress ? _onSyncButtonPress : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
