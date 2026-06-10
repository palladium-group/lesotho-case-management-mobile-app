class CarePlanRules {
  static bool canCreateForInvestigation({required bool investigationExists, required bool carePlanExists}) {
    return investigationExists && !carePlanExists;
  }
  static bool isActivePlan(String status) {
    final value = status.trim().toUpperCase();
    return value == 'ACTIVE' || value.isEmpty;
  }
}
