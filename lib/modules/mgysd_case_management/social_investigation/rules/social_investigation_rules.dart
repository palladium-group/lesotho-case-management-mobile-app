class SocialInvestigationRules {
  static bool canComplete({required String clientTei, required String orgUnit, required String incidentPattern}) {
    return clientTei.trim().isNotEmpty && orgUnit.trim().isNotEmpty && incidentPattern.trim().isNotEmpty;
  }
}
