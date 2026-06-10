class MonitoringRules {
  static bool shouldCreateNewCycle(String reason) => reason.toUpperCase() == 'REASSESSMENT';
}
