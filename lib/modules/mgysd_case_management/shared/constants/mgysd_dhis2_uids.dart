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
  // Repeatable Social Investigation stage in MGYSD Enrolled Households.
  static const String enrolledsocialInvestigationStage = 'WLZlhndmqDg';
  static const String carePlanStage = 'jvfi6JnZPxU';
  static const String referralStage = 'uijeGa1d3ZW';
  // Monitoring stages by program. Existing workflow code uses monitoringStage
  // for Enrolled Households.
  static const String assessedMonitoringStage = 'GxHpVfPNKfm';
  static const String monitoringStage = 'KsXYZNs9LAk';
  static const String familyMonitoringStage = 'v5jBuqKC9Aw';
  static const String familyServiceProvisionStage = 'JusjUjRXKCN';
  static const String familyReferralStage = 'lRLikYWFv5u';

  static const String enrolledServiceProvisionStage = 'zz2Le52Wx0w';
  static const String enrolledCaseClosureStage = 'JvJ3YxzV9GT';
  static const String familyCarePlanStage = 'cmdutyjEbKj';
  static const String familyCaseClosureStage = 'knCYcUv7MOP';

  // ---------------------------------------------------------------------------
  // COMPATIBILITY ALIASES
  // Keep naming consistent across older and newer MGYSD modules.
  // These aliases point to the same real DHIS2 stage UIDs.
  // ---------------------------------------------------------------------------
  static const String assessedSocialInvestigationStage =
      socialInvestigationStage;
  static const String enrolledSocialInvestigationStage =
      enrolledsocialInvestigationStage;
  static const String serviceProvisionStage =
      enrolledServiceProvisionStage;
  static const String enrolledMonitoringStage =
      monitoringStage;
  static const String familyMemberMonitoringStage =
      familyMonitoringStage;


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


  // Monitoring (shared by Assessed/Enrolled household Monitoring stages)
  static const String deMonitoringOverallChallenges = 'L46bDs7gPW8';
  static const String deMonitoringDate = 'eYj942VeEea';
  static const String deMonitoringInterviewRole = 'kfoX3fIWj2s';
  static const String deMonitoringInterviewPurpose = 'Pxi8jOv4DoS';
  static const String deMonitoringOverallProgressSummary = 'kolWzfu5OSd';
  static const String deMonitoringNextActions = 'cFBZ8IAJadF';
  static const String deMonitoringNextVisitDate = 'Dr1Dr03I8QC';
  static const String deMonitoringReassessmentReason = 'V8wey9sFdMj';
  static const String deMonitoringReassessmentFindings = 'LYeWAjxPxGQ';
  static const String deMonitoringImmediateActions = 'ZbbrRn6gaiL';
  static const String deMonitoringProgressObserved = 'Hy6RaVTthD8';
  static const String deMonitoringChallengesStillPresent = 'PIZ2usO2IlW';
  static const String deMonitoringGoalRecommendation = 'ozbMIZRNwEs';
  static const String deMonitoringInterviewFirstName = 'jB1vdGn6Eic';
  static const String deMonitoringGoalFollowupDate = 'S4J0mid39AT';

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
    if (stage == initialRiskAssessmentStage ||
        stage == socialInvestigationStage ||
        stage == assessedMonitoringStage) {
      return assessedHouseholdsProgram;
    }
    if (stage == enrolledsocialInvestigationStage ||
        stage == monitoringStage ||
        stage == carePlanStage ||
        stage == referralStage ||
        stage == enrolledServiceProvisionStage ||
        stage == enrolledCaseClosureStage) {
      return enrolledHouseholdsProgram;
    }
    if (stage == familyMonitoringStage ||
        stage == familyCarePlanStage ||
        stage == familyReferralStage ||
        stage == familyServiceProvisionStage ||
        stage == familyCaseClosureStage) {
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
  static const String deReporterCommunityCouncil = 'arawTWdOCOZ';
  static const String deReportingDate = 'EG9wNvu6kGY';
  static const String deFirstClientAge = 'NwCn5RVitx1';
  static const String deFirstClientCategory = 'hxxH8RmZrV2';
  static const String deReporterPhysicalAddress = 'LOCAL_REPORTER_ADDRESS';
  static const String deReporterDob = 'LOCAL_REPORTER_DOB';
  static const String deReporterAge = 'LOCAL_REPORTER_AGE';
  static const String deReporterSex = 'kwL1QEdrChg';
  static const String deReporterOccupation = 'LOCAL_REPORTER_OCCUPATION';

  // Local-only helper payload fields. These are kept locally for display/debug.
  // They must not be posted to DHIS2 unless you create real Data Elements for them.
  static const String deClientsJson = 'DE_CLIENTS_JSON';
  static const String dePeopleInvolvedJson = 'DE_PEOPLE_INVOLVED_JSON';
  static const String deReportPayloadJson = 'MGYSD_REPORT_PAYLOAD_JSON';


  static const String deConcernReason = 'UJIrqEgPMn1';
  static const String deConcernReasonOther = 'UlxSVhptSPi';
  static const String deIncidentDescription = 'rOo1QAaJ23F';
  static const String deWhenHappened = 'UImPhy5oOOq';
  static const String deIncidentLocation = 'mEUV26PcDKZ';

  static const String deFirstClientFirstName = 'wOIx1Tism5p';
  static const String deFirstClientLastName = 'mclj3oLRpiv';
  static const String deFirstClientPhone = 'fBB08qRfTCp';
  static const String deFirstClientSex = 'LOCAL_CLIENT_SEX';
  static const String deFirstClientDistrict = 'LOCAL_CLIENT_DISTRICT';

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
  static const String attHasDisability = 'qplFRHPhrMJ';
  static const String attDisabilitySpecify = 'PeuzIMl3kI9';

  static const String attIsClientInSchool = 'doT78HXVVtZ';
  static const String attSchoolName = 'N5LCEJOxGoZ';
  static const String attGrade = 'ATTR_GRADE';
  static const String attSchoolAttendanceStatus = 'SjKSZZ0A7Lm';

  static const String attIsAdultEmployed = 'jfjsu5QL6Ce';
  static const String attEmployerName = 'RIKBsXclI3i';

  static const String attNextOfKinFirstName = 'jneawlWhqnx';
  static const String attNextOfKinSurname = 'vWlFqdiLjG2';
  static const String attNextOfKinPhone = 'ATTR_NOK_PHONE';
  static const String attNextOfKinPhysicalAddress = 'd5DcZpk66V1';
  static const String attNextOfKinRelationship = 'z1vIT95rl44';
  static const String attNextOfKinRelationshipOther = 'ATTR_NOK_RELATIONSHIP_OTHER';

  // Case-specific parent status attributes remain on the CLIENT TEI.
  static const String attFatherAlive = 'Tt2wTRrTiIP';
  static const String attFatherLivingWithChild = 'ATTR_FATHER_LIVING_WITH_CHILD';
  static const String attFatherWhyNotLiving = 'ATTR_FATHER_WHY_NOT_LIVING';

  static const String attMotherAlive = 'TjjN3rriKRW';
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
  // INTAKE AND INITIAL RISK ASSESSMENT DATA ELEMENTS
  //
  // These fields are no longer tracked entity attributes. They must be posted
  // to DHIS2 as dataValues under:
  //   programStage: initialRiskAssessmentStage
  //
  // The constant names still start with attRisk... only to keep existing pages
  // compiling. Their values now point to Initial Risk Assessment DATA ELEMENTS.
  // Empty values mean there is no matching DHIS2 data element yet and the sync
  // mapper must skip them.
  // ---------------------------------------------------------------------------
  static const String attRiskAssessmentDate = ''; // Use the event date of initialRiskAssessmentStage.
  static const String attRiskAssessmentSocialWorker = deRiskSocialWorker;
  static const String attRiskAssessmentReportSource = '';
  static const String attRiskAssessmentHasActionTaken = '';
  static const String attRiskAssessmentNoActionReason = '';
  static const String attRiskAssessmentEmergencyActionsTaken = '';
  static const String attRiskAssessmentServicesAccessed = '';

  static const String attRiskFamilyBackground = deRiskFamilyBackground;
  static const String attRiskFamilyBackgroundNotes = deRiskFamilyBackgroundNotes;
  static const String attRiskFamilyBackgroundMember = '';

  static const String attRiskCaregiverWellbeing = '';
  static const String attRiskCaregiverWellbeingNotes = '';
  static const String attRiskCaregiverWellbeingMember = '';

  static const String attRiskExtendedFamilyRelationships = deRiskExtendedFamilyRelationships;
  static const String attRiskExtendedFamilyNotes = deRiskExtendedFamilyNotes;
  static const String attRiskExtendedFamilyMember = '';

  static const String attRiskClientRelationships = deRiskClientRelationships;
  static const String attRiskClientRelationshipsNotes = deRiskClientRelationshipsNotes;
  static const String attRiskClientRelationshipsMember = '';

  static const String attRiskLivingCircumstances = deRiskLivingCircumstances;
  static const String attRiskLivingCircumstancesNotes = deRiskLivingCircumstancesNotes;
  static const String attRiskLivingCircumstancesMember = '';

  static const String attRiskHousing = deRiskHousing;
  static const String attRiskHousingNotes = deRiskHousingNotes;
  static const String attRiskHousingMember = '';

  static const String attRiskPhysicalHealth = deRiskPhysicalHealth;
  static const String attRiskPhysicalHealthNotes = deRiskPhysicalHealthNotes;
  static const String attRiskPhysicalHealthMember = '';

  static const String attRiskNutrition = deRiskNutrition;
  static const String attRiskNutritionNotes = deRiskNutritionNotes;
  static const String attRiskNutritionMember = '';

  static const String attRiskEmotionalHealth = deRiskEmotionalHealth;
  static const String attRiskEmotionalHealthNotes = deRiskEmotionalHealthNotes;
  static const String attRiskEmotionalHealthMember = '';

  static const String attRiskSupervision = deRiskSupervision;
  static const String attRiskSupervisionNotes = deRiskSupervisionNotes;
  static const String attRiskSupervisionMember = '';

  static const String attRiskEducation = deRiskEducation;
  static const String attRiskEducationNotes = deRiskEducationNotes;
  static const String attRiskEducationMember = '';

  static const String attRiskLevel = deRiskLevel;
  static const String attRiskReason = deRiskReason;
  static const String attRiskImmediateReferrals = deRiskImmediateReferrals;
  static const String attRiskNextSteps = '';
  static const String attRiskAdditionalNotes = '';

  static const Set<String> initialRiskAssessmentDataElementIds = {
    deRiskSocialWorker,
    deRiskFamilyBackground,
    deRiskFamilyBackgroundNotes,
    deRiskExtendedFamilyRelationships,
    deRiskExtendedFamilyNotes,
    deRiskClientRelationships,
    deRiskClientRelationshipsNotes,
    deRiskLivingCircumstances,
    deRiskLivingCircumstancesNotes,
    deRiskHousing,
    deRiskHousingNotes,
    deRiskPhysicalHealth,
    deRiskPhysicalHealthNotes,
    deRiskNutrition,
    deRiskNutritionNotes,
    deRiskEmotionalHealth,
    deRiskEmotionalHealthNotes,
    deRiskSupervision,
    deRiskSupervisionNotes,
    deRiskEducation,
    deRiskEducationNotes,
    deRiskLevel,
    deRiskReason,
    deRiskImmediateReferrals,
    deRiskSelfCare,
    deRiskDisabilityDiagnosis,
    deRiskAssistiveDevices,
    deRiskRehabilitationServices,
  };

  static bool isInitialRiskAssessmentDataElement(String id) {
    return id.isNotEmpty && initialRiskAssessmentDataElementIds.contains(id);
  }


  static bool isSyncableTrackedEntityAttribute(String id) {
    final value = id.trim();
    return value.isNotEmpty &&
        !value.startsWith('ATTR_') &&
        !isInitialRiskAssessmentDataElement(value);
  }

}