class MonitoringSkipLogic {
  static bool showRoutineMonitoring(String reason) => reason.toUpperCase() == 'ROUTINE_MONITORING';
  static bool showReassessment(String reason) => reason.toUpperCase() == 'REASSESSMENT';
}
