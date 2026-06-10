class WorkflowRules {
  static bool isDraft(String status) => status.toUpperCase() == 'DRAFT';
  static bool isCompleted(String status) => status.toUpperCase() == 'COMPLETED';
}
