class EnrollmentSkipLogic {
  static bool showEducationSection(String clientCategory) => clientCategory.toUpperCase() == 'CHILD';
  static bool showEmploymentSection(String clientCategory) => clientCategory.toUpperCase() != 'CHILD';
  static bool showPersonalAssistantSection(String isDisabled) => isDisabled.toUpperCase() == 'YES';
}
