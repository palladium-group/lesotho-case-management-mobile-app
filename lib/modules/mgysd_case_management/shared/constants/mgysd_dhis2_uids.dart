class MgysdDhis2Uids {
  // ---------------------------------------------------------------------------
  // PROGRAMS
  // Replace these placeholders with real DHIS2 program UIDs.
  // ---------------------------------------------------------------------------
  static const String reportedCasesEventProgram = 'TbR7dOCu5XK';
  static const String reportedCasesProgramStage = 'TybrOV3Isgz';

  // UAT household-program model.
  // All households with completed Intake + Initial Risk are enrolled here.
  static const String assessedHouseholdsProgram = 'rWvrjowCJ4f';

  // Households are enrolled here only when risk level is NOT No/Low.
  // Replace this placeholder with the real DHIS2 UID once created.
  static const String enrolledHouseholdsProgram = 'IiNM5kQkHLu';

  // Family members, including the primary client, are enrolled here only when
  // the household risk level is NOT No/Low.
  static const String familyMemberTrackerProgram = 'zDB0BXM9SWI';

  // ---------------------------------------------------------------------------
  // TRACKED ENTITY TYPES
  // ---------------------------------------------------------------------------
  static const String householdTrackedEntityType = 'ZeF8JZWAYwc';
  static const String personTrackedEntityType = 'lH6AFxcxrpl';

  // ---------------------------------------------------------------------------
  // RELATIONSHIP TYPES
  // ---------------------------------------------------------------------------
  static const String householdHasMemberRelationshipType = 'MwvYPP5TYHj';

  // ---------------------------------------------------------------------------
  // CASE MANAGEMENT PROGRAM STAGES
  // ---------------------------------------------------------------------------
  static const String initialRiskAssessmentStage = 'Yd9HAhIUdZT';
  static const String socialInvestigationStage = 'KoYx0zLUSC7';
  // Not present in the supplied metadata export. Reassessment remains local until the stage is added to DHIS2.
  static const String enrolledsocialInvestigationStage = '';
  static const String carePlanStage = 'jvfi6JnZPxU';
  static const String referralStage = 'uijeGa1d3ZW';
  // Not present in the supplied metadata export. Monitoring remains local until the stage is added to DHIS2.
  static const String monitoringStage = '';
  static const String familyServiceProvisionStage = 'JusjUjRXKCN';
  static const String familyReferralStage = 'lRLikYWFv5u';

  static const String enrolledServiceProvisionStage = 'zz2Le52Wx0w';
  static const String enrolledCaseClosureStage = 'JvJ3YxzV9GT';
  static const String familyCarePlanStage = 'cmdutyjEbKj';
  static const String familyCaseClosureStage = 'knCYcUv7MOP';

  // ---------------------------------------------------------------------------
  // PROGRAM STAGE DATA ELEMENTS
  // ---------------------------------------------------------------------------
  // Initial Risk Assessment
  static const String deRiskSocialWorker = 'x7OiQdB0z8N';
  static const String deRiskFamilyBackground = 'k0Ik2xJsHDl';
  static const String deRiskFamilyBackgroundNotes = 'rpTsXSQdCLG';
  static const String deRiskExtendedFamilyRelationships = 'IByvTnQBrZ5';
  static const String deRiskExtendedFamilyNotes = 'Ad7FrGPyNJF';
  static const String deRiskClientRelationships = 'J7Gw2WBtDdl';
  static const String deRiskClientRelationshipsNotes = 'A1FL4kEtQmF';
  static const String deRiskLivingCircumstances = 'x0aRkojnDZw';
  static const String deRiskLivingCircumstancesNotes = 'pydu54qM0c5';
  static const String deRiskHousing = 'BiNg7sCCCwj';
  static const String deRiskHousingNotes = 'Bx5q2b8SYrv';
  static const String deRiskPhysicalHealth = 't9MyIrxgRSz';
  static const String deRiskPhysicalHealthNotes = 'MLzjC3tFcw4';
  static const String deRiskNutrition = 'xcUH1xsraWJ';
  static const String deRiskNutritionNotes = 'd5oYGFPlauq';
  static const String deRiskEmotionalHealth = 'fAuuUmTMvYg';
  static const String deRiskEmotionalHealthNotes = 'l2vSjTBEKF6';
  static const String deRiskSupervision = 'MCZ0FP8pMAA';
  static const String deRiskSupervisionNotes = 'LycDSRZMPrQ';
  static const String deRiskEducation = 'nf1lUdwfGL7';
  static const String deRiskEducationNotes = 'BjWTsZspDMz';
  static const String deRiskLevel = 'npSovAKbpKJ';
  static const String deRiskReason = 'OJtTGOXdPQW';
  static const String deRiskImmediateReferrals = 'zhVMrnMScAf';
  static const String deRiskSelfCare = 'MueBNV7Q8Dv';
  static const String deRiskDisabilityDiagnosis = 'LP3qsc3lbwf';
  static const String deRiskAssistiveDevices = 'fMIT7ZRxfJa';
  static const String deRiskRehabilitationServices = 'aNCWaj2uiNT';

  // Social Investigation
  static const String deSiFirstName = 'iKnsia7KkBH';
  static const String deSiLastName = 'LJneSL7qw2j';
  static const String deSiPhone = 'btlkDoGnC6V';
  static const String deSiIncidentPattern = 'OpFRYfIY7Mg';
  static const String deSiDistrict = 'adljwftsi5a';
  static const String deSiCommunityCouncil = 'gZnegKWLd5c';
  static const String deSiVillage = 'UwebjUHdn33';
  static const String deSiAssessmentChanged = 'vPcfbHYu7Ec';
  static const String deSiChangeReason = 'ZwsovAKkbT0';
  static const String deSiAdditionalObservations = 'owwT4uo6Q1A';

  // Care Plan (shared DEs for household and family-member stages)
  static const String deCareClientLongTermGoals = 'MGcvdwB9an1';
  static const String deCareClientMediumTermGoals = 'XccSRDYOuIi';
  static const String deCareClientShortTermGoals = 'YXRW59Ix4Yo';
  static const String deCareSocialWorkerLongTermGoals = 'SmNDSnIpDZI';
  static const String deCareSocialWorkerMediumTermGoals = 'HYtAelvhmMm';
  static const String deCareSocialWorkerShortTermGoals = 'j05YMaR7nPu';
  static const String deCareGuardianLongTermGoals = 'Cd899Q0QbGN';
  static const String deCareGuardianMediumTermGoals = 'xdMgSCXyiOv';
  static const String deCareGuardianShortTermGoals = 'DCflOGcRpRf';
  static const String deCareDisagreeFirstName = 'zU38XqTkS39';
  static const String deCareDisagreeLastName = 'nZ4irElAn5H';
  static const String deCareDisagreeReason = 'LIqmToBEqln';

  // Referral
  static const String deReferralServiceCategory = 'kZTkQlqucTY';
  static const String deReferralReceivingOrganisation = 'GbUlBfHYiQW';
  static const String deReferralContactPerson = 'ZaxqcBTBZlX';
  static const String deReferralContactPhone = 'cOZ76AfIzNR';
  static const String deReferralDocuments = 'KEqZPvTrHvU';
  static const String deReferralReason = 'eNM5xzGJ1Qw';
  static const String deReferralPriority = 'kNXszeg38Iw';
  static const String deReferralRecommendations = 'o6ArGWXS4Rt';

  // Service Provision
  static const String deServiceProvided = 'zgJofqWwDkV';
  static const String deServiceProvider = 'xlrAIsW0sLp';
  static const String deServiceOutcome = 'bNRpZ7ufqy1';
  static const String deServiceGoalStatus = 'HFChYcrz4Eu';
  static const String deServiceGoalStatusNotes = 'UQc0FNIBJbq';

  // Case Closure
  static const String deClosureObjectivesMet = 'NZLHtwFJvQg';
  static const String deClosureCompletionDate = 'y6B3MP8qy9a';
  static const String deClosureOpeningDate = 'SOEcwstdK7K';
  static const String deClosureMeetingPerson = 'QqFnMiruug4';
  static const String deClosureTransferredTo = 'UqtSGmJqbE1';
  static const String deClosureCurrentAddress = 'DARyQfvE8Xf';
  static const String deClosurePreviousAddress = 'FNE7QsfJkSD';
  static const String deClosureLostToFollowUp = 'UJMn6Jpp2VY';
  static const String deClosureNoLongerNeedsCare = 'LaXNhcS3e0u';
  static const String deClosureNoLongerWilling = 'CzUzgXwT4VF';
  static const String deClosureRelationshipToClient = 'XYmD9IE4KJx';

  static String programForStage(String stage) {
    if (stage == initialRiskAssessmentStage || stage == socialInvestigationStage) {
      return assessedHouseholdsProgram;
    }
    if (stage == carePlanStage || stage == referralStage ||
        stage == enrolledServiceProvisionStage || stage == enrolledCaseClosureStage) {
      return enrolledHouseholdsProgram;
    }
    if (stage == familyCarePlanStage || stage == familyReferralStage ||
        stage == familyServiceProvisionStage || stage == familyCaseClosureStage) {
      return familyMemberTrackerProgram;
    }
    if (stage == reportedCasesProgramStage) return reportedCasesEventProgram;
    return '';
  }

  // ---------------------------------------------------------------------------
  // REPORTED CASE EVENT PROGRAM DATA ELEMENTS
  // IMPORTANT:
  // These are the latest working Event Program IDs. Do not change these unless
  // you intentionally change the DHIS2 Reported Cases event program metadata.
  // ---------------------------------------------------------------------------
  static const String deReporterFirstName = 'RWEFHH4pm27';
  static const String deReporterLastName = 'dwSkq33g4Uu';
  static const String deReporterVillage = 'NCb5dNKnqOG';
  static const String deChiefFirstName = 'Zjah90FdrwV';
  static const String deChiefLastName = 'vmVxUbkVmXN';
  static const String deReporterPhone = 'hKEJvGcXWND';
  static const String deReporterAltPhone = 'pgklc5q0r9A';
  static const String deReporterRelationship = 'vXKcqU7V0xQ';
  static const String deReporterRelationshipOther = 'wIAHzLOccWk';
  static const String deReporterAnonymous = 'gG7pCI0Ma5v';
  static const String deReporterPhysicalAddress = 'kDUkHc2D6wo';
  static const String deReporterDob = 'heErfQ9Chl3';
  static const String deReporterAge = 'NwCn5RVitx1';
  static const String deReporterSex = 'kwL1QEdrChg';
  static const String deReporterOccupation = 'TiIFI4bHP6z';

  // Local-only helper payload fields. These are kept locally for display/debug.
  // They must not be posted to DHIS2 unless you create real Data Elements for them.
  static const String deClientsJson = 'DE_CLIENTS_JSON';
  static const String dePeopleInvolvedJson = 'DE_PEOPLE_INVOLVED_JSON';
  static const String deReportPayloadJson = 'MGYSD_REPORT_PAYLOAD_JSON';


  static const String deConcernReason = 'UJIrqEgPMn1';
  static const String deConcernReasonOther = 'UJIrqEgPMn1_OTHER';
  static const String deIncidentDescription = 'rOo1QAaJ23F';
  static const String deWhenHappened = 'UImPhy5oOOq';
  static const String deIncidentLocation = 'DE_INCIDENT_LOCATION';

  static const String deFirstClientFirstName = 'wOIx1Tism5p';
  static const String deFirstClientLastName = 'mclj3oLRpiv';
  static const String deFirstClientPhone = 'fBB08qRfTCp';
  static const String deFirstClientSex = 'COIWHHGCoCl';
  static const String deFirstClientDistrict = 'MGYSD_CLIENT_DISTRICT';

  // ---------------------------------------------------------------------------
  // TRACKER ATTRIBUTES FOR HOUSEHOLD / PERSON / CASE INTAKE
  // Replace ATTR_* placeholders with real DHIS2 tracked entity attribute UIDs.
  // ---------------------------------------------------------------------------
  static const String attHouseholdFileNumber = 'EiVk93a7mZe';
  static const String attHouseholdDistrict = 'mUd3nLq2yWs';
  static const String attHouseholdCommunityCouncil = 'QEFKNkxgAPJ';
  static const String attHouseholdVillage = 'GqMwTC3d5Q3';
  static const String attHouseholdAddress = 'lX1IhhQo5xZ';

  // Generic person attributes. These are reused by Client, Father, Mother,
  // Caregiver, Personal Assistant and other household member TEIs.
  static const String attFirstName = 'pjCcbyI7FUp';
  static const String attLastName = 'esMFNbhr5HI';
  static const String attDob = 'sKxEiIxGVLU';
  static const String attAge = 'bGo4g2S56oj';
  static const String attPhone = 'a6GM7pQVd0H';
  static const String attAlternativePhone = 'ACcp6NOkLqu';
  static const String attSex = 'gm7LqHbguhI';
  static const String attClientCategory = 'E8MyhvR1ZBj';
  static const String attIsDisabled = 'qplFRHPhrMJ';
  static const String attIdentityNumber = 'G70qGpfzbSu';
  static const String attNationality = 'ATTR_NATIONALITY';
  static const String attHomeLanguage = 'UQlbGvkSBJo';
  static const String attHomeLanguageOther = 'ATTR_HOME_LANGUAGE_OTHER';
  static const String attNationalityOther = 'ATTR_NATIONALITY_OTHER';
  static const String attOccupation = 'qzPKtlcljyU';
  static const String attRelationshipToClient = 'ATTR_RELATIONSHIP_TO_CLIENT';
  static const String attRelationshipToClientOther = 'ATTR_RELATIONSHIP_TO_CLIENT_OTHER';
  static const String attHasDisability = 'ATTR_HAS_DISABILITY';
  static const String attDisabilitySpecify = 'PeuzIMl3kI9';

  static const String attIsClientInSchool = 'doT78HXVVtZ';
  static const String attSchoolName = 'N5LCEJOxGoZ';
  static const String attGrade = 'ATTR_GRADE';
  static const String attSchoolAttendanceStatus = 'SjKSZZ0A7Lm';

  static const String attIsAdultEmployed = 'jfjsu5QL6Ce';
  static const String attEmployerName = 'RIKBsXclI3i';

  static const String attNextOfKinFirstName = 'ATTR_NOK_FIRST_NAME';
  static const String attNextOfKinSurname = 'ATTR_NOK_SURNAME';
  static const String attNextOfKinPhone = 'ATTR_NOK_PHONE';
  static const String attNextOfKinPhysicalAddress = 'ATTR_NOK_PHYSICAL_ADDRESS';
  static const String attNextOfKinRelationship = 'ATTR_NOK_RELATIONSHIP';
  static const String attNextOfKinRelationshipOther = 'ATTR_NOK_RELATIONSHIP_OTHER';

  // Case-specific parent status attributes remain on the CLIENT TEI.
  static const String attFatherAlive = 'ATTR_FATHER_ALIVE';
  static const String attFatherLivingWithChild = 'ATTR_FATHER_LIVING_WITH_CHILD';
  static const String attFatherWhyNotLiving = 'ATTR_FATHER_WHY_NOT_LIVING';

  static const String attMotherAlive = 'ATTR_MOTHER_ALIVE';
  static const String attMotherLivingWithChild = 'ATTR_MOTHER_LIVING_WITH_CHILD';
  static const String attMotherWhyNotLiving = 'ATTR_MOTHER_WHY_NOT_LIVING';

  // Compatibility aliases:
  // Keep these names so older pages still compile, but point them to the generic
  // person attributes. The values are stored against different TEIs, so they do
  // not overwrite each other.
  static const String attFatherFirstName = attFirstName;
  static const String attFatherSurname = attLastName;
  static const String attFatherDob = attDob;
  static const String attFatherOccupation = attOccupation;
  static const String attFatherPhone = attPhone;

  static const String attMotherFirstName = attFirstName;
  static const String attMotherSurname = attLastName;
  static const String attMotherDob = attDob;
  static const String attMotherOccupation = attOccupation;
  static const String attMotherPhone = attPhone;

  static const String attCaregiverName = attFirstName;
  static const String attCaregiverSurname = attLastName;
  static const String attCaregiverSex = attSex;
  static const String attCaregiverRelationship = attRelationshipToClient;
  static const String attCaregiverDob = attDob;
  static const String attCaregiverOccupation = attOccupation;
  static const String attCaregiverPhone = attPhone;

  static const String attPersonalAssistantName = attFirstName;
  static const String attPersonalAssistantSurname = attLastName;
  static const String attPersonalAssistantSex = attSex;
  static const String attPersonalAssistantRelationship = attRelationshipToClient;
  static const String attPersonalAssistantDob = attDob;
  static const String attPersonalAssistantOccupation = attOccupation;
  static const String attPersonalAssistantPhone = attPhone;

  static const String attReasonForEnrolment = 'ATTR_REASON_FOR_ENROLMENT';
  static const String attReasonForEnrolmentOther = 'ATTR_REASON_FOR_ENROLMENT_OTHER';

  static const String attHasEmergencyActionTaken = 'ATTR_HAS_EMERGENCY_ACTION_TAKEN';
  static const String attEmergencyNoActionReason = 'ATTR_EMERGENCY_NO_ACTION_REASON';
  static const String attEmergencyNoActionRefusedSpecify = 'ATTR_EMERGENCY_NO_ACTION_REFUSED_SPECIFY';
  static const String attEmergencyNoActionOtherSpecify = 'ATTR_EMERGENCY_NO_ACTION_OTHER_SPECIFY';
  static const String attEmergencyActionTakenDescription = 'ATTR_EMERGENCY_ACTION_TAKEN_DESCRIPTION';
  static const String attEmergencyContactedPhoneNumbers = 'ATTR_EMERGENCY_CONTACTED_PHONE_NUMBERS';
  static const String attEmergencyServicesAlreadyProvided = 'ATTR_EMERGENCY_SERVICES_ALREADY_PROVIDED';


  // ---------------------------------------------------------------------------
  // INTAKE AND INITIAL RISK ASSESSMENT ATTRIBUTES
  // These are TRACKED ENTITY ATTRIBUTES saved on the CLIENT TEI together with
  // Intake. Replace ATTR_* placeholders with real DHIS2 TEA UIDs after creating
  // them in DHIS2.
  // ---------------------------------------------------------------------------
  static const String attRiskAssessmentDate = 'ATTR_RISK_ASSESSMENT_DATE';
  static const String attRiskAssessmentSocialWorker = 'ATTR_RISK_ASSESSMENT_SOCIAL_WORKER';
  static const String attRiskAssessmentReportSource = 'ATTR_RISK_ASSESSMENT_REPORT_SOURCE';
  static const String attRiskAssessmentHasActionTaken = 'ATTR_RISK_ASSESSMENT_HAS_ACTION_TAKEN';
  static const String attRiskAssessmentNoActionReason = 'ATTR_RISK_ASSESSMENT_NO_ACTION_REASON';
  static const String attRiskAssessmentEmergencyActionsTaken = 'ATTR_RISK_ASSESSMENT_EMERGENCY_ACTIONS_TAKEN';
  static const String attRiskAssessmentServicesAccessed = 'ATTR_RISK_ASSESSMENT_SERVICES_ACCESSED';

  static const String attRiskFamilyBackground = 'ATTR_RISK_FAMILY_BACKGROUND';
  static const String attRiskFamilyBackgroundNotes = 'ATTR_RISK_FAMILY_BACKGROUND_NOTES';
  static const String attRiskFamilyBackgroundMember = 'ATTR_RISK_FAMILY_BACKGROUND_MEMBER';
  static const String attRiskCaregiverWellbeing = 'ATTR_RISK_CAREGIVER_WELLBEING';
  static const String attRiskCaregiverWellbeingNotes = 'ATTR_RISK_CAREGIVER_WELLBEING_NOTES';
  static const String attRiskCaregiverWellbeingMember = 'ATTR_RISK_CAREGIVER_WELLBEING_MEMBER';
  static const String attRiskExtendedFamilyRelationships = 'ATTR_RISK_EXTENDED_FAMILY_RELATIONSHIPS';
  static const String attRiskExtendedFamilyNotes = 'ATTR_RISK_EXTENDED_FAMILY_NOTES';
  static const String attRiskExtendedFamilyMember = 'ATTR_RISK_EXTENDED_FAMILY_MEMBER';
  static const String attRiskClientRelationships = 'ATTR_RISK_CLIENT_RELATIONSHIPS';
  static const String attRiskClientRelationshipsNotes = 'ATTR_RISK_CLIENT_RELATIONSHIPS_NOTES';
  static const String attRiskClientRelationshipsMember = 'ATTR_RISK_CLIENT_RELATIONSHIPS_MEMBER';
  static const String attRiskLivingCircumstances = 'ATTR_RISK_LIVING_CIRCUMSTANCES';
  static const String attRiskLivingCircumstancesNotes = 'ATTR_RISK_LIVING_CIRCUMSTANCES_NOTES';
  static const String attRiskLivingCircumstancesMember = 'ATTR_RISK_LIVING_CIRCUMSTANCES_MEMBER';
  static const String attRiskHousing = 'ATTR_RISK_HOUSING';
  static const String attRiskHousingNotes = 'ATTR_RISK_HOUSING_NOTES';
  static const String attRiskHousingMember = 'ATTR_RISK_HOUSING_MEMBER';
  static const String attRiskPhysicalHealth = 'ATTR_RISK_PHYSICAL_HEALTH';
  static const String attRiskPhysicalHealthNotes = 'ATTR_RISK_PHYSICAL_HEALTH_NOTES';
  static const String attRiskPhysicalHealthMember = 'ATTR_RISK_PHYSICAL_HEALTH_MEMBER';
  static const String attRiskNutrition = 'ATTR_RISK_NUTRITION';
  static const String attRiskNutritionNotes = 'ATTR_RISK_NUTRITION_NOTES';
  static const String attRiskNutritionMember = 'ATTR_RISK_NUTRITION_MEMBER';
  static const String attRiskEmotionalHealth = 'ATTR_RISK_EMOTIONAL_HEALTH';
  static const String attRiskEmotionalHealthNotes = 'ATTR_RISK_EMOTIONAL_HEALTH_NOTES';
  static const String attRiskEmotionalHealthMember = 'ATTR_RISK_EMOTIONAL_HEALTH_MEMBER';
  static const String attRiskSupervision = 'ATTR_RISK_SUPERVISION';
  static const String attRiskSupervisionNotes = 'ATTR_RISK_SUPERVISION_NOTES';
  static const String attRiskSupervisionMember = 'ATTR_RISK_SUPERVISION_MEMBER';
  static const String attRiskEducation = 'ATTR_RISK_EDUCATION';
  static const String attRiskEducationNotes = 'ATTR_RISK_EDUCATION_NOTES';
  static const String attRiskEducationMember = 'ATTR_RISK_EDUCATION_MEMBER';

  static const String attRiskLevel = 'ATTR_RISK_LEVEL';
  static const String attRiskReason = 'ATTR_RISK_REASON';
  static const String attRiskImmediateReferrals = 'ATTR_RISK_IMMEDIATE_REFERRALS';
  static const String attRiskNextSteps = 'ATTR_RISK_NEXT_STEPS';
  static const String attRiskAdditionalNotes = 'ATTR_RISK_ADDITIONAL_NOTES';

}
