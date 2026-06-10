class ReferralSkipLogic {
  static bool showIndividualReferral(String targetType) => targetType.toUpperCase() == 'PERSON';
  static bool showHouseholdReferral(String targetType) => targetType.toUpperCase() == 'HOUSEHOLD';
}
