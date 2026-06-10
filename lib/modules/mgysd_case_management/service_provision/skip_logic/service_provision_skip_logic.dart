class ServiceProvisionSkipLogic {
  static bool showHouseholdService(String role) => role.toUpperCase() == 'HOUSEHOLD';
  static bool canProvideService(String planStatus) => planStatus.trim().toUpperCase() == 'ACTIVE';
}
