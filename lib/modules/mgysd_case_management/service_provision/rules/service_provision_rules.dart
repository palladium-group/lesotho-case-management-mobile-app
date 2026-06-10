class ServiceProvisionRules {
  static bool shouldPropagateToHouseholdMembers(String targetRole) => targetRole.toUpperCase() == 'HOUSEHOLD';
  static bool isGoalOpen(String goalStatus) => goalStatus.trim().toLowerCase() != 'achieved';
}
