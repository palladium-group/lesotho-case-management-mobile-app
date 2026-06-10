class ReferralRules {
  static bool hasValidTarget({required String householdTei, required String memberTei}) {
    return householdTei.trim().isNotEmpty || memberTei.trim().isNotEmpty;
  }
}
