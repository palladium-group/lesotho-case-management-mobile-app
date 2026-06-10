class EnrollmentRules {
  static bool shouldEnrollHousehold(String riskLevel) {
    final risk = riskLevel.trim().toUpperCase();
    return risk.isNotEmpty && risk != 'NO_LOW' && risk != 'LOW' && risk != 'NO/LOW';
  }
}
