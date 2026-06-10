
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/intervention_card_state/intervention_card_state.dart';
import 'package:lncmis_mobile_app/core/components/entry_form_save_button.dart';
import 'package:lncmis_mobile_app/core/components/material_card.dart';
import 'package:lncmis_mobile_app/core/components/sub_page_app_bar.dart';
import 'package:lncmis_mobile_app/core/components/sup_page_body.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/services/organisation_unit_service.dart';
import 'package:lncmis_mobile_app/models/organisation_unit.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

class MgysdNewCasePage extends StatefulWidget {
  const MgysdNewCasePage({
    Key? key,
    required this.color,
    this.reportedEventId,
    this.prefillClientFirstName,
    this.prefillClientLastName,
    this.prefillClientPhone,
    this.prefillCaseType,
    this.prefillIncidentDate,
  }) : super(key: key);

  final Color color;
  final String? reportedEventId;
  final String? prefillClientFirstName;
  final String? prefillClientLastName;
  final String? prefillClientPhone;
  final String? prefillCaseType;
  final String? prefillIncidentDate;

  @override
  State<MgysdNewCasePage> createState() => _MgysdNewCasePageState();
}

class _Opt {
  final String code;
  final String label;

  const _Opt(this.code, this.label);
}

class _ReasonGroup {
  final String code;
  final String title;
  final List<_Opt> options;
  final bool childOnly;

  const _ReasonGroup({
    required this.code,
    required this.title,
    required this.options,
    this.childOnly = false,
  });
}

class _DynamicTextItem {
  final String id;
  final TextEditingController controller;

  _DynamicTextItem({
    required this.id,
    String value = '',
  }) : controller = TextEditingController(text: value);

  void dispose() => controller.dispose();
}

class _HouseholdMemberEntry {
  final String id;
  final TextEditingController firstNameController;
  final TextEditingController surnameController;
  final TextEditingController dobController;
  final TextEditingController ageController;
  final TextEditingController occupationController;
  final TextEditingController contactsController;
  final TextEditingController disabilitySpecifyController;

  String sex;
  String relationshipToClient;
  String hasDisability;

  _HouseholdMemberEntry({
    required this.id,
    this.sex = '',
    this.relationshipToClient = '',
    this.hasDisability = '',
  })  : firstNameController = TextEditingController(),
        surnameController = TextEditingController(),
        dobController = TextEditingController(),
        ageController = TextEditingController(),
        occupationController = TextEditingController(),
        contactsController = TextEditingController(),
        disabilitySpecifyController = TextEditingController();

  bool get hasAnyData {
    return firstNameController.text.trim().isNotEmpty ||
        surnameController.text.trim().isNotEmpty ||
        dobController.text.trim().isNotEmpty ||
        ageController.text.trim().isNotEmpty ||
        occupationController.text.trim().isNotEmpty ||
        contactsController.text.trim().isNotEmpty ||
        disabilitySpecifyController.text.trim().isNotEmpty ||
        sex.trim().isNotEmpty ||
        relationshipToClient.trim().isNotEmpty ||
        hasDisability.trim().isNotEmpty;
  }

  void dispose() {
    firstNameController.dispose();
    surnameController.dispose();
    dobController.dispose();
    ageController.dispose();
    occupationController.dispose();
    contactsController.dispose();
    disabilitySpecifyController.dispose();
  }
}

class _MgysdNewCasePageState extends State<MgysdNewCasePage> {
  final _formKey = GlobalKey<FormState>();

  final _fileNumberController = TextEditingController();
  final _districtController = TextEditingController();
  final _communityCouncilController = TextEditingController();
  final _villageController = TextEditingController();
  final _physicalAddressController = TextEditingController();

  final _identityNumberController = TextEditingController();
  final _clientFirstNameController = TextEditingController();
  final _clientSurnameController = TextEditingController();
  final _clientDobController = TextEditingController();
  final _clientAgeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternativePhoneController = TextEditingController();
  final _homeLanguageOtherController = TextEditingController();

  final _schoolNameController = TextEditingController();
  final _employerNameController = TextEditingController();

  final _nextOfKinFirstNameController = TextEditingController();
  final _nextOfKinSurnameController = TextEditingController();
  final _nextOfKinPhoneController = TextEditingController();
  final _nextOfKinPhysicalAddressController = TextEditingController();
  final _nextOfKinRelationshipOtherController = TextEditingController();

  final _fatherFirstNameController = TextEditingController();
  final _fatherSurnameController = TextEditingController();
  final _fatherDobController = TextEditingController();
  final _fatherOccupationController = TextEditingController();
  final _fatherWhyNotLivingController = TextEditingController();
  final _fatherPhoneController = TextEditingController();

  final _motherFirstNameController = TextEditingController();
  final _motherSurnameController = TextEditingController();
  final _motherDobController = TextEditingController();
  final _motherOccupationController = TextEditingController();
  final _motherWhyNotLivingController = TextEditingController();
  final _motherPhoneController = TextEditingController();

  final _caregiverNameController = TextEditingController();
  final _caregiverSurnameController = TextEditingController();
  final _caregiverRelationshipController = TextEditingController();
  final _caregiverDobController = TextEditingController();
  final _caregiverOccupationController = TextEditingController();
  final _caregiverPhoneController = TextEditingController();

  final _personalAssistantNameController = TextEditingController();
  final _personalAssistantSurnameController = TextEditingController();
  final _personalAssistantRelationshipController = TextEditingController();
  final _personalAssistantDobController = TextEditingController();
  final _personalAssistantOccupationController = TextEditingController();
  final _personalAssistantPhoneController = TextEditingController();

  final _reasonOtherController = TextEditingController();

  final _emergencyActionTakenController = TextEditingController();
  final _emergencyNoActionRefusedSpecifyController = TextEditingController();
  final _emergencyNoActionOtherSpecifyController = TextEditingController();

  final _riskAssessmentDateController = TextEditingController();
  final _riskSocialWorkerController = TextEditingController();
  final _riskReasonController = TextEditingController();
  final _riskImmediateReferralsController = TextEditingController();
  final _riskAdditionalNotesController = TextEditingController();

  final _riskFamilyBackgroundNotesController = TextEditingController();
  final _riskCaregiverWellbeingNotesController = TextEditingController();
  final _riskExtendedFamilyNotesController = TextEditingController();
  final _riskClientRelationshipsNotesController = TextEditingController();
  final _riskLivingCircumstancesNotesController = TextEditingController();
  final _riskHousingNotesController = TextEditingController();
  final _riskPhysicalHealthNotesController = TextEditingController();
  final _riskNutritionNotesController = TextEditingController();
  final _riskEmotionalHealthNotesController = TextEditingController();
  final _riskSupervisionNotesController = TextEditingController();
  final _riskEducationNotesController = TextEditingController();

  DateTime? _selectedDob;
  bool _saving = false;
  bool _loadingOrgUnits = false;

  List<OrganisationUnit> _districtOrgUnits = [];
  List<OrganisationUnit> _communityCouncilOrgUnits = [];

  String _selectedDistrictId = '';
  String _selectedDistrictName = '';
  String _selectedCommunityCouncilId = '';
  String _selectedCommunityCouncilName = '';

  String _clientCategory = '';
  String _isDisabled = '';
  String _sex = '';
  String _nationality = '';
  String _homeLanguage = '';
  String _isClientInSchool = '';
  String _grade = '';
  String _schoolAttendanceStatus = '';
  String _isAdultEmployed = '';
  String _nextOfKinRelationship = '';

  String _fatherAlive = '';
  String _fatherLivingWithChild = '';
  String _motherAlive = '';
  String _motherLivingWithChild = '';

  String _caregiverSex = '';
  String _personalAssistantSex = '';

  String _hasEmergencyActionTaken = '';
  String _emergencyNoActionReason = '';

  String _riskReportSource = '';
  String _riskHasActionTaken = '';
  String _riskNoActionReason = '';
  String _riskFamilyBackground = '';
  String _riskCaregiverWellbeing = '';
  String _riskExtendedFamilyRelationships = '';
  String _riskClientRelationships = '';
  String _riskLivingCircumstances = '';
  String _riskHousing = '';
  String _riskPhysicalHealth = '';
  String _riskNutrition = '';
  String _riskEmotionalHealth = '';
  String _riskSupervision = '';
  String _riskEducation = '';
  String _riskLevel = '';

  final Set<String> _selectedReasonOptions = {};
  final List<_DynamicTextItem> _contactedPhoneNumbers = [];
  final List<_DynamicTextItem> _servicesAlreadyProvided = [];
  final Set<String> _riskEmergencyActionsTaken = {};
  final Set<String> _riskServicesAccessed = {};
  final Set<String> _riskNextSteps = {};
  final List<_HouseholdMemberEntry> _otherHouseholdMembers = [];

  static const String mgysdAssessedHouseholdsProgramId =
      MgysdDhis2Uids.assessedHouseholdsProgram;
  static const String mgysdEnrolledHouseholdsProgramId =
      MgysdDhis2Uids.enrolledHouseholdsProgram;
  static const String mgysdFamilyMembersProgramId =
      MgysdDhis2Uids.familyMemberTrackerProgram;
  static const String mgysdHouseholdTeiTypeId = MgysdDhis2Uids.householdTrackedEntityType;
  static const String mgysdPersonTeiTypeId = MgysdDhis2Uids.personTrackedEntityType;

  static const String attHouseholdFileNumber = MgysdDhis2Uids.attHouseholdFileNumber;
  static const String attHouseholdDistrict = MgysdDhis2Uids.attHouseholdDistrict;
  static const String attHouseholdCommunityCouncil =
      MgysdDhis2Uids.attHouseholdCommunityCouncil;
  static const String attHouseholdVillage = MgysdDhis2Uids.attHouseholdVillage;
  static const String attHouseholdAddress = MgysdDhis2Uids.attHouseholdAddress;

  static const String attFirstName = MgysdDhis2Uids.attFirstName;
  static const String attLastName = MgysdDhis2Uids.attLastName;
  static const String attDob = MgysdDhis2Uids.attDob;
  static const String attAge = MgysdDhis2Uids.attAge;
  static const String attPhone = MgysdDhis2Uids.attPhone;
  static const String attAlternativePhone = MgysdDhis2Uids.attAlternativePhone;
  static const String attSex = MgysdDhis2Uids.attSex;
  static const String attClientCategory = MgysdDhis2Uids.attClientCategory;
  static const String attIsDisabled = MgysdDhis2Uids.attIsDisabled;
  static const String attIdentityNumber = MgysdDhis2Uids.attIdentityNumber;
  static const String attNationality = MgysdDhis2Uids.attNationality;
  static const String attHomeLanguage = MgysdDhis2Uids.attHomeLanguage;
  static const String attHomeLanguageOther = MgysdDhis2Uids.attHomeLanguageOther;
  static const String attOccupation = MgysdDhis2Uids.attOccupation;
  static const String attRelationshipToClient = MgysdDhis2Uids.attRelationshipToClient;
  static const String attHasDisability = MgysdDhis2Uids.attHasDisability;
  static const String attDisabilitySpecify = MgysdDhis2Uids.attDisabilitySpecify;

  static const String attIsClientInSchool = MgysdDhis2Uids.attIsClientInSchool;
  static const String attSchoolName = MgysdDhis2Uids.attSchoolName;
  static const String attGrade = MgysdDhis2Uids.attGrade;
  static const String attSchoolAttendanceStatus =
      MgysdDhis2Uids.attSchoolAttendanceStatus;

  static const String attIsAdultEmployed = MgysdDhis2Uids.attIsAdultEmployed;
  static const String attEmployerName = MgysdDhis2Uids.attEmployerName;

  static const String attNextOfKinFirstName = MgysdDhis2Uids.attNextOfKinFirstName;
  static const String attNextOfKinSurname = MgysdDhis2Uids.attNextOfKinSurname;
  static const String attNextOfKinPhone = MgysdDhis2Uids.attNextOfKinPhone;
  static const String attNextOfKinPhysicalAddress =
      MgysdDhis2Uids.attNextOfKinPhysicalAddress;
  static const String attNextOfKinRelationship = MgysdDhis2Uids.attNextOfKinRelationship;
  static const String attNextOfKinRelationshipOther =
      MgysdDhis2Uids.attNextOfKinRelationshipOther;

  static const String attFatherAlive = MgysdDhis2Uids.attFatherAlive;
  static const String attFatherFirstName = MgysdDhis2Uids.attFatherFirstName;
  static const String attFatherSurname = MgysdDhis2Uids.attFatherSurname;
  static const String attFatherDob = MgysdDhis2Uids.attFatherDob;
  static const String attFatherOccupation = MgysdDhis2Uids.attFatherOccupation;
  static const String attFatherLivingWithChild =
      MgysdDhis2Uids.attFatherLivingWithChild;
  static const String attFatherWhyNotLiving = MgysdDhis2Uids.attFatherWhyNotLiving;
  static const String attFatherPhone = MgysdDhis2Uids.attFatherPhone;

  static const String attMotherAlive = MgysdDhis2Uids.attMotherAlive;
  static const String attMotherFirstName = MgysdDhis2Uids.attMotherFirstName;
  static const String attMotherSurname = MgysdDhis2Uids.attMotherSurname;
  static const String attMotherDob = MgysdDhis2Uids.attMotherDob;
  static const String attMotherOccupation = MgysdDhis2Uids.attMotherOccupation;
  static const String attMotherLivingWithChild =
      MgysdDhis2Uids.attMotherLivingWithChild;
  static const String attMotherWhyNotLiving = MgysdDhis2Uids.attMotherWhyNotLiving;
  static const String attMotherPhone = MgysdDhis2Uids.attMotherPhone;

  static const String attCaregiverName = MgysdDhis2Uids.attCaregiverName;
  static const String attCaregiverSurname = MgysdDhis2Uids.attCaregiverSurname;
  static const String attCaregiverSex = MgysdDhis2Uids.attCaregiverSex;
  static const String attCaregiverRelationship = MgysdDhis2Uids.attCaregiverRelationship;
  static const String attCaregiverDob = MgysdDhis2Uids.attCaregiverDob;
  static const String attCaregiverOccupation = MgysdDhis2Uids.attCaregiverOccupation;
  static const String attCaregiverPhone = MgysdDhis2Uids.attCaregiverPhone;

  static const String attPersonalAssistantName =
      MgysdDhis2Uids.attPersonalAssistantName;
  static const String attPersonalAssistantSurname =
      MgysdDhis2Uids.attPersonalAssistantSurname;
  static const String attPersonalAssistantSex = MgysdDhis2Uids.attPersonalAssistantSex;
  static const String attPersonalAssistantRelationship =
      MgysdDhis2Uids.attPersonalAssistantRelationship;
  static const String attPersonalAssistantDob = MgysdDhis2Uids.attPersonalAssistantDob;
  static const String attPersonalAssistantOccupation =
      MgysdDhis2Uids.attPersonalAssistantOccupation;
  static const String attPersonalAssistantPhone =
      MgysdDhis2Uids.attPersonalAssistantPhone;

  static const String attReasonForEnrolment = MgysdDhis2Uids.attReasonForEnrolment;
  static const String attReasonForEnrolmentOther =
      MgysdDhis2Uids.attReasonForEnrolmentOther;

  static const String attHasEmergencyActionTaken =
      MgysdDhis2Uids.attHasEmergencyActionTaken;
  static const String attEmergencyNoActionReason =
      MgysdDhis2Uids.attEmergencyNoActionReason;
  static const String attEmergencyNoActionRefusedSpecify =
      MgysdDhis2Uids.attEmergencyNoActionRefusedSpecify;
  static const String attEmergencyNoActionOtherSpecify =
      MgysdDhis2Uids.attEmergencyNoActionOtherSpecify;
  static const String attEmergencyActionTakenDescription =
      MgysdDhis2Uids.attEmergencyActionTakenDescription;
  static const String attEmergencyContactedPhoneNumbers =
      MgysdDhis2Uids.attEmergencyContactedPhoneNumbers;
  static const String attEmergencyServicesAlreadyProvided =
      MgysdDhis2Uids.attEmergencyServicesAlreadyProvided;

  static const String attRiskAssessmentDate = MgysdDhis2Uids.attRiskAssessmentDate;
  static const String attRiskAssessmentSocialWorker =
      MgysdDhis2Uids.attRiskAssessmentSocialWorker;
  static const String attRiskAssessmentReportSource =
      MgysdDhis2Uids.attRiskAssessmentReportSource;
  static const String attRiskAssessmentHasActionTaken =
      MgysdDhis2Uids.attRiskAssessmentHasActionTaken;
  static const String attRiskAssessmentNoActionReason =
      MgysdDhis2Uids.attRiskAssessmentNoActionReason;
  static const String attRiskAssessmentEmergencyActionsTaken =
      MgysdDhis2Uids.attRiskAssessmentEmergencyActionsTaken;
  static const String attRiskAssessmentServicesAccessed =
      MgysdDhis2Uids.attRiskAssessmentServicesAccessed;

  static const String attRiskFamilyBackground = MgysdDhis2Uids.attRiskFamilyBackground;
  static const String attRiskFamilyBackgroundNotes =
      MgysdDhis2Uids.attRiskFamilyBackgroundNotes;
  static const String attRiskCaregiverWellbeing = MgysdDhis2Uids.attRiskCaregiverWellbeing;
  static const String attRiskCaregiverWellbeingNotes =
      MgysdDhis2Uids.attRiskCaregiverWellbeingNotes;
  static const String attRiskExtendedFamilyRelationships =
      MgysdDhis2Uids.attRiskExtendedFamilyRelationships;
  static const String attRiskExtendedFamilyNotes = MgysdDhis2Uids.attRiskExtendedFamilyNotes;
  static const String attRiskClientRelationships = MgysdDhis2Uids.attRiskClientRelationships;
  static const String attRiskClientRelationshipsNotes =
      MgysdDhis2Uids.attRiskClientRelationshipsNotes;
  static const String attRiskLivingCircumstances = MgysdDhis2Uids.attRiskLivingCircumstances;
  static const String attRiskLivingCircumstancesNotes =
      MgysdDhis2Uids.attRiskLivingCircumstancesNotes;
  static const String attRiskHousing = MgysdDhis2Uids.attRiskHousing;
  static const String attRiskHousingNotes = MgysdDhis2Uids.attRiskHousingNotes;
  static const String attRiskPhysicalHealth = MgysdDhis2Uids.attRiskPhysicalHealth;
  static const String attRiskPhysicalHealthNotes = MgysdDhis2Uids.attRiskPhysicalHealthNotes;
  static const String attRiskNutrition = MgysdDhis2Uids.attRiskNutrition;
  static const String attRiskNutritionNotes = MgysdDhis2Uids.attRiskNutritionNotes;
  static const String attRiskEmotionalHealth = MgysdDhis2Uids.attRiskEmotionalHealth;
  static const String attRiskEmotionalHealthNotes = MgysdDhis2Uids.attRiskEmotionalHealthNotes;
  static const String attRiskSupervision = MgysdDhis2Uids.attRiskSupervision;
  static const String attRiskSupervisionNotes = MgysdDhis2Uids.attRiskSupervisionNotes;
  static const String attRiskEducation = MgysdDhis2Uids.attRiskEducation;
  static const String attRiskEducationNotes = MgysdDhis2Uids.attRiskEducationNotes;

  static const String attRiskLevel = MgysdDhis2Uids.attRiskLevel;
  static const String attRiskReason = MgysdDhis2Uids.attRiskReason;
  static const String attRiskImmediateReferrals = MgysdDhis2Uids.attRiskImmediateReferrals;
  static const String attRiskNextSteps = MgysdDhis2Uids.attRiskNextSteps;
  static const String attRiskAdditionalNotes = MgysdDhis2Uids.attRiskAdditionalNotes;

  static const String relHouseholdHasMember = MgysdDhis2Uids.householdHasMemberRelationshipType;

  static const List<_Opt> clientCategoryOptions = [
    _Opt('CHILD', 'Child'),
    _Opt('ADULT_ELDERLY_PERSON', 'Adult / Elderly Person'),
  ];

  static const List<_Opt> yesNoOptions = [
    _Opt('YES', 'Yes'),
    _Opt('NO', 'No'),
  ];

  static const List<_Opt> yesNoUnknownOptions = [
    _Opt('YES', 'Yes'),
    _Opt('NO', 'No'),
    _Opt('UNKNOWN', 'Unknown'),
  ];

  static const List<_Opt> sexOptions = [
    _Opt('MALE', 'Male'),
    _Opt('FEMALE', 'Female'),
  ];

  static const List<_Opt> nationalityOptions = [
    _Opt('MOSOTHO', 'Mosotho'),
    _Opt('SOUTH_AFRICAN', 'South African'),
    _Opt('ZIMBABWEAN', 'Zimbabwean'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> homeLanguageOptions = [
    _Opt('SESOTHO', 'Sesotho'),
    _Opt('ENGLISH', 'English'),
    _Opt('XHOSA', 'Xhosa'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> gradeOptions = [
    _Opt('1', 'Grade 1'),
    _Opt('2', 'Grade 2'),
    _Opt('3', 'Grade 3'),
    _Opt('4', 'Grade 4'),
    _Opt('5', 'Grade 5'),
    _Opt('6', 'Grade 6'),
    _Opt('7', 'Grade 7'),
    _Opt('8', 'Grade 8'),
    _Opt('9', 'Grade 9'),
    _Opt('10', 'Grade 10'),
    _Opt('11', 'Grade 11'),
  ];

  static const List<_Opt> inSchoolAttendanceOptions = [
    _Opt('POOR_ATTENDANCE', 'Poor attendance'),
    _Opt('GOOD_ATTENDANCE', 'Good attendance'),
  ];

  static const List<_Opt> notInSchoolAttendanceOptions = [
    _Opt('NO_LONGER_IN_SCHOOL', 'No longer in School'),
    _Opt('NEVER_ATTENDED_SCHOOL', 'Never attended School'),
  ];

  static const List<_Opt> nextOfKinRelationshipOptions = [
    _Opt('PARENT', 'Parent'),
    _Opt('CAREGIVER', 'Caregiver'),
    _Opt('GUARDIAN', 'Guardian'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> emergencyNoActionOptions = [
    _Opt('NOT_REQUIRED', 'Not required'),
    _Opt('REFUSED', 'Refused'),
    _Opt('OTHER', 'Other'),
  ];


  static const List<_Opt> riskReportSourceOptions = [
    _Opt('COMMUNITY_MEMBER', 'Community member'),
    _Opt('TEACHER', 'Teacher'),
    _Opt('POLICE', 'Police'),
    _Opt('HEALTH_FACILITY', 'Health facility'),
    _Opt('SOCIAL_WORKER', 'Social worker'),
    _Opt('FAMILY_MEMBER', 'Family member'),
    _Opt('SELF_REPORT', 'Self-report'),
    _Opt('NGO_PARTNER', 'NGO / Partner'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> riskNoActionReasonOptions = [
    _Opt('NOT_REQUIRED', 'Not required'),
    _Opt('REFUSED', 'Refused'),
    _Opt('PENDING_ASSESSMENT', 'Pending assessment'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> riskEmergencyActionOptions = [
    _Opt('POLICE_CGPU_REFERRAL', 'Referral to police / CGPU'),
    _Opt('EMERGENCY_MEDICAL_SERVICES', 'Emergency medical services'),
    _Opt('PLACE_OF_SAFETY', 'Place of safety arranged'),
    _Opt('REMOVED_FROM_HOME', 'Removed from home'),
    _Opt('PSYCHOSOCIAL_FIRST_RESPONSE', 'Counselling / psychosocial first response'),
    _Opt('SUPERVISOR_INFORMED', 'Supervisor informed'),
    _Opt('NO_IMMEDIATE_ACTION', 'No immediate action'),
  ];

  static const List<_Opt> riskServicesAccessedOptions = [
    _Opt('HEALTH_SERVICES', 'Health services'),
    _Opt('POLICE_SERVICES', 'Police services'),
    _Opt('PSYCHOSOCIAL_SUPPORT', 'Psychosocial support'),
    _Opt('SHELTER_PLACE_OF_SAFETY', 'Shelter / place of safety'),
    _Opt('TRANSPORT_ASSISTANCE', 'Transport assistance'),
    _Opt('FOOD_ASSISTANCE', 'Food assistance'),
    _Opt('LEGAL_SUPPORT', 'Legal support'),
  ];

  static const List<_Opt> riskNextStepOptions = [
    _Opt('MONITOR_LOCAL_CONTACTS', 'Monitor through local contacts'),
    _Opt('REFER_COMMUNITY_SERVICES', 'Refer to community services'),
    _Opt('FURTHER_INVESTIGATION', 'Further investigation required'),
    _Opt('URGENT_PROTECTION_ACTION', 'Urgent protection action required'),
    _Opt('OPEN_SOCIAL_INVESTIGATION', 'Open social investigation'),
    _Opt('DEVELOP_CARE_PLAN', 'Develop care plan'),
  ];

  static const List<_Opt> riskFamilyBackgroundOptions = [
    _Opt('STABLE', 'Stable'),
    _Opt('RECENT_CHANGES', 'Recent changes'),
    _Opt('ONGOING_CHALLENGES', 'Ongoing challenges'),
    _Opt('UNPREDICTABLE_OR_VIOLENT', 'Unpredictable or violent context'),
  ];

  static const List<_Opt> riskCaregiverWellbeingOptions = [
    _Opt('GOOD_STABLE', 'In good health / stable'),
    _Opt('CONCERNS_WITH_SUPPORT', 'Concerns but receiving support'),
    _Opt('FRAGILE_INCONSISTENT', 'Fragile / inconsistent'),
    _Opt('SIGNIFICANT_ISSUES', 'Significant issues'),
  ];

  static const List<_Opt> riskRelationshipOptions = [
    _Opt('STABLE_GOOD', 'Stable / Good'),
    _Opt('INCONSISTENT', 'Inconsistent'),
    _Opt('NON_EXISTENT_POOR', 'Non-existent / Poor'),
  ];

  static const List<_Opt> riskLivingCircumstancesOptions = [
    _Opt('STABLE_GOOD', 'Stable / Good'),
    _Opt('SAFE_OKAY', 'Safe / Okay'),
    _Opt('INCONSISTENT', 'Inconsistent'),
    _Opt('UNSTABLE_UNSAFE', 'Unstable / Unsafe'),
  ];

  static const List<_Opt> riskHousingOptions = [
    _Opt('STABLE_GOOD', 'Stable / Good'),
    _Opt('SAFE_SUFFICIENT', 'Safe / Sufficient'),
    _Opt('INCONSISTENT', 'Inconsistent'),
    _Opt('NOT_HABITABLE', 'Not habitable'),
  ];

  static const List<_Opt> riskPhysicalHealthOptions = [
    _Opt('GOOD_STABLE', 'In good health / stable'),
    _Opt('CONCERNS_WITH_SUPPORT', 'Health / wellbeing concerns but receiving support'),
    _Opt('FRAGILE_INCONSISTENT', 'Fragile / inconsistent'),
    _Opt('SIGNIFICANT_ISSUES', 'Significant issues'),
  ];

  static const List<_Opt> riskNutritionOptions = [
    _Opt('STABLE_GOOD', 'Stable / Good'),
    _Opt('INCONSISTENT', 'Inconsistent'),
    _Opt('POOR', 'Poor'),
  ];

  static const List<_Opt> riskEmotionalHealthOptions = [
    _Opt('GOOD_STABLE', 'In good health / stable'),
    _Opt('CONCERNS_WITH_SUPPORT', 'Mental or wellbeing concerns but receiving support'),
    _Opt('FRAGILE_INCONSISTENT', 'Fragile / inconsistent'),
    _Opt('SIGNIFICANT_POOR', 'Significant issues / poor'),
  ];

  static const List<_Opt> riskSupervisionOptions = [
    _Opt('WELL_SUPERVISED', 'Well supervised / supported'),
    _Opt('BASIC_SUPPORT_LEFT_ALONE', 'Basic support but often left alone'),
    _Opt('UNSAFE_SUPERVISION', 'Significant issues / unsafe supervision'),
  ];

  static const List<_Opt> riskEducationOptions = [
    _Opt('STABLE_GOOD', 'Stable / Good'),
    _Opt('REASONABLE_INCONSISTENT', 'Reasonable but inconsistent'),
    _Opt('ONGOING_CONCERNS', 'Ongoing concerns'),
    _Opt('SIGNIFICANT_DROPOUT', 'Significant issues / dropout'),
  ];

  static const List<_Opt> riskLevelOptions = [
    _Opt('LOW', 'No / Low Risk'),
    _Opt('MEDIUM', 'Medium Risk'),
    _Opt('HIGH', 'High Risk'),
  ];

  static const List<_ReasonGroup> groupedReasons = [
    _ReasonGroup(
      code: 'ABUSE',
      title: 'Abuse',
      options: [
        _Opt('ABUSE_PHYSICAL', 'Physical abuse'),
        _Opt('ABUSE_EMOTIONAL', 'Emotional abuse'),
        _Opt('ABUSE_SEXUAL', 'Sexual abuse'),
        _Opt('ABUSE_RAPE', 'Rape'),
        _Opt('ABUSE_INCEST', 'Incest'),
      ],
    ),
    _ReasonGroup(
      code: 'CARE_OR_PROTECTION',
      title: 'In need of care or protection',
      options: [
        _Opt('CARE_NEGLECT', 'Neglect'),
        _Opt('CARE_ABANDONMENT', 'Abandonment'),
        _Opt('CARE_ORPHANS', 'Orphans'),
        _Opt('CARE_BABY_ABANDONMENT', 'Baby abandonment'),
      ],
    ),
    _ReasonGroup(
      code: 'BEHAVIOURAL_PROBLEMS',
      title: 'Behavioural problems',
      options: [
        _Opt('BEHAVIOUR_ALCOHOL_ABUSE', 'Alcohol abuse'),
        _Opt('BEHAVIOUR_DRUG_ABUSE', 'Drug abuse'),
        _Opt('BEHAVIOUR_OTHER', 'Other behavioural problem'),
      ],
    ),
    _ReasonGroup(
      code: 'SPECIAL_NEEDS',
      title: 'Special needs',
      options: [
        _Opt('SPECIAL_PHYSICAL', 'Physical'),
        _Opt('SPECIAL_MENTAL', 'Mental'),
        _Opt('SPECIAL_PSYCHOLOGICAL', 'Psychological'),
      ],
    ),
    _ReasonGroup(
      code: 'CHILD_EXPLOITATION',
      title: 'Child exploitation',
      childOnly: true,
      options: [
        _Opt('EXPLOITATION_CHILD_LABOUR', 'Child labour'),
        _Opt('EXPLOITATION_CHILD_MARRIAGE', 'Child marriage'),
        _Opt('EXPLOITATION_SEXUAL', 'Sexual exploitation'),
      ],
    ),
  ];

  static const List<_Opt> singleReasons = [
    _Opt('STREET_CHILD', 'Child living and working on the street'),
    _Opt('CONFLICT_WITH_LAW', 'Child in conflict with the law'),
    _Opt('ABDUCTION_KIDNAPPING', 'Child abduction / kidnapping'),
    _Opt('CHILD_MAINTENANCE', 'Child maintenance'),
    _Opt('CHILD_WITNESS_SUPPORT', 'Child witness support services'),
    _Opt('DOMESTIC_VIOLENCE', 'Domestic violence'),
    _Opt('HUMAN_TRAFFICKING', 'Human trafficking / Trafficking in Persons'),
    _Opt('INTERNATIONAL_SOCIAL_SERVICES', 'International social services'),
    _Opt('TEENAGE_PREGNANCY_YOUNG_MOTHERS',
        'Teenage pregnancy / young mothers'),
    _Opt('PSYCHOSOCIAL_DISTRESS',
        'Psychosocial distress / bereavement / trauma'),
    _Opt('PRE_SENTENCE_REQUEST_REPORT', 'Pre-sentence request / report'),
    _Opt('SOCIAL_ASSISTANCE_EDUCATIONAL_AID',
        'Social Assistance and Educational Aid'),
    _Opt('GRIEVANCE', 'Grievance'),
    _Opt('COMMUNITY_DEVELOPMENT_INITIATIVES',
        'Community Development Initiatives'),
    _Opt('HEALTH_NUTRITION_ISSUES', 'Health and nutrition issues'),
    _Opt('OTHER', 'Other'),
  ];

  static const Set<String> childOnlySingleReasonCodes = {
    'STREET_CHILD',
    'CONFLICT_WITH_LAW',
    'ABDUCTION_KIDNAPPING',
    'CHILD_MAINTENANCE',
    'CHILD_WITNESS_SUPPORT',
    'TEENAGE_PREGNANCY_YOUNG_MOTHERS',
    'SOCIAL_ASSISTANCE_EDUCATIONAL_AID',
  };

  bool get _isAdultOrElderly => _clientCategory == 'ADULT_ELDERLY_PERSON';
  bool get _isChild => _clientCategory == 'CHILD';
  bool get _isDisabledYes => _isDisabled == 'YES';
  bool get _showGuardianOption => _isDisabledYes;
  bool get _nextOfKinRelationshipIsOther => _nextOfKinRelationship == 'OTHER';
  bool get _reasonOtherSelected => _selectedReasonOptions.contains('OTHER');

  int? get _clientAge => int.tryParse(_clientAgeController.text.trim());

  @override
  void initState() {
    super.initState();

    _clientFirstNameController.text =
        (widget.prefillClientFirstName ?? '').trim();
    _clientSurnameController.text = (widget.prefillClientLastName ?? '').trim();
    _phoneController.text = (widget.prefillClientPhone ?? '').trim();
    _fileNumberController.text =
    'MGYSD-${DateTime.now().millisecondsSinceEpoch}';
    _riskAssessmentDateController.text = _formatDate(DateTime.now());

    _addContactedPhoneNumber();
    _addServiceProvided();
    _addOtherHouseholdMember();
    _loadLocationTree();
  }

  @override
  void dispose() {
    _fileNumberController.dispose();
    _districtController.dispose();
    _communityCouncilController.dispose();
    _villageController.dispose();
    _physicalAddressController.dispose();
    _identityNumberController.dispose();
    _clientFirstNameController.dispose();
    _clientSurnameController.dispose();
    _clientDobController.dispose();
    _clientAgeController.dispose();
    _phoneController.dispose();
    _alternativePhoneController.dispose();
    _homeLanguageOtherController.dispose();
    _schoolNameController.dispose();
    _employerNameController.dispose();
    _nextOfKinFirstNameController.dispose();
    _nextOfKinSurnameController.dispose();
    _nextOfKinPhoneController.dispose();
    _nextOfKinPhysicalAddressController.dispose();
    _nextOfKinRelationshipOtherController.dispose();
    _fatherFirstNameController.dispose();
    _fatherSurnameController.dispose();
    _fatherDobController.dispose();
    _fatherOccupationController.dispose();
    _fatherWhyNotLivingController.dispose();
    _fatherPhoneController.dispose();
    _motherFirstNameController.dispose();
    _motherSurnameController.dispose();
    _motherDobController.dispose();
    _motherOccupationController.dispose();
    _motherWhyNotLivingController.dispose();
    _motherPhoneController.dispose();
    _caregiverNameController.dispose();
    _caregiverSurnameController.dispose();
    _caregiverRelationshipController.dispose();
    _caregiverDobController.dispose();
    _caregiverOccupationController.dispose();
    _caregiverPhoneController.dispose();
    _personalAssistantNameController.dispose();
    _personalAssistantSurnameController.dispose();
    _personalAssistantRelationshipController.dispose();
    _personalAssistantDobController.dispose();
    _personalAssistantOccupationController.dispose();
    _personalAssistantPhoneController.dispose();
    _reasonOtherController.dispose();
    _emergencyActionTakenController.dispose();
    _emergencyNoActionRefusedSpecifyController.dispose();
    _emergencyNoActionOtherSpecifyController.dispose();
    _riskAssessmentDateController.dispose();
    _riskSocialWorkerController.dispose();
    _riskReasonController.dispose();
    _riskImmediateReferralsController.dispose();
    _riskAdditionalNotesController.dispose();
    _riskFamilyBackgroundNotesController.dispose();
    _riskCaregiverWellbeingNotesController.dispose();
    _riskExtendedFamilyNotesController.dispose();
    _riskClientRelationshipsNotesController.dispose();
    _riskLivingCircumstancesNotesController.dispose();
    _riskHousingNotesController.dispose();
    _riskPhysicalHealthNotesController.dispose();
    _riskNutritionNotesController.dispose();
    _riskEmotionalHealthNotesController.dispose();
    _riskSupervisionNotesController.dispose();
    _riskEducationNotesController.dispose();

    for (final item in _contactedPhoneNumbers) {
      item.dispose();
    }
    for (final item in _servicesAlreadyProvided) {
      item.dispose();
    }
    for (final item in _otherHouseholdMembers) {
      item.dispose();
    }

    super.dispose();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  Future<void> _loadLocationTree() async {
    setState(() => _loadingOrgUnits = true);

    try {
      final service = OrganisationUnitService();
      final accessibleIds =
      await service.getOrganisationUnitAccessedByCurrentUser();

      final level2Units = await service.getOrganisationUnitsByLevel(2);
      final level3Units = await service.getOrganisationUnitsByLevel(3);

      final accessibleSet = accessibleIds
          .map((id) => id.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      bool isAccessible(OrganisationUnit unit) {
        if (accessibleSet.isEmpty) return true;
        final id = (unit.id ?? '').trim();
        return id.isNotEmpty && accessibleSet.contains(id);
      }

      final accessibleDistricts = level2Units.where((district) {
        final districtId = (district.id ?? '').trim();
        if (districtId.isEmpty) return false;

        if (isAccessible(district)) return true;

        return level3Units.any((cc) {
          return (cc.parent ?? '').trim() == districtId && isAccessible(cc);
        });
      }).toList()
        ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      if (!mounted) return;

      setState(() {
        _districtOrgUnits = accessibleDistricts;

        if (_selectedDistrictId.isNotEmpty &&
            !_districtOrgUnits.any((ou) => ou.id == _selectedDistrictId)) {
          _selectedDistrictId = '';
          _selectedDistrictName = '';
          _districtController.clear();
          _selectedCommunityCouncilId = '';
          _selectedCommunityCouncilName = '';
          _communityCouncilController.clear();
          _communityCouncilOrgUnits = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppUtil.showToastMessage(
        message: 'Failed to load locations: $e',
      );
    } finally {
      if (mounted) setState(() => _loadingOrgUnits = false);
    }
  }

  Future<void> _loadCommunityCouncilsForDistrict(String districtId) async {
    if (districtId.trim().isEmpty) {
      setState(() {
        _communityCouncilOrgUnits = [];
        _selectedCommunityCouncilId = '';
        _selectedCommunityCouncilName = '';
        _communityCouncilController.clear();
      });
      return;
    }

    setState(() => _loadingOrgUnits = true);

    try {
      final service = OrganisationUnitService();
      final accessibleIds =
      await service.getOrganisationUnitAccessedByCurrentUser();
      final level3Units = await service.getOrganisationUnitsByLevel(3);

      final accessibleSet = accessibleIds
          .map((id) => id.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      bool isAccessible(OrganisationUnit unit) {
        if (accessibleSet.isEmpty) return true;
        final id = (unit.id ?? '').trim();
        return id.isNotEmpty && accessibleSet.contains(id);
      }

      final councils = level3Units.where((ou) {
        return (ou.parent ?? '').trim() == districtId.trim() &&
            isAccessible(ou);
      }).toList()
        ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      if (!mounted) return;

      setState(() {
        _communityCouncilOrgUnits = councils;

        if (_selectedCommunityCouncilId.isNotEmpty &&
            !_communityCouncilOrgUnits
                .any((ou) => ou.id == _selectedCommunityCouncilId)) {
          _selectedCommunityCouncilId = '';
          _selectedCommunityCouncilName = '';
          _communityCouncilController.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppUtil.showToastMessage(
        message: 'Failed to load community councils: $e',
      );
    } finally {
      if (mounted) setState(() => _loadingOrgUnits = false);
    }
  }

  String _newId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${r.nextInt(999999)}';
  }

  String _newDhis2Uid() {
    return AppUtil.getUid();
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    final hadBirthday = today.month > dob.month ||
        (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthday) age--;
    return age < 0 ? 0 : age;
  }

  Future<void> _pickDateFor(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text.trim()) ??
        DateTime(now.year - 20, 1, 1);

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      initialDate: initial,
    );

    if (picked != null) {
      setState(() {
        controller.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickDobForClient() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 15, 1, 1);

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      initialDate: initial,
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _clientDobController.text = _formatDate(picked);
        _clientAgeController.text = _calculateAge(picked).toString();
        _removeHiddenReasonOptions();
      });
    }
  }

  Future<void> _pickDobForHouseholdMember(_HouseholdMemberEntry member) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(member.dobController.text.trim()) ??
        DateTime(now.year - 15, 1, 1);

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      initialDate: initial,
    );

    if (picked != null) {
      setState(() {
        member.dobController.text = _formatDate(picked);
        member.ageController.text = _calculateAge(picked).toString();
      });
    }
  }

  List<_Opt> _nextOfKinRelationshipOptions() {
    if (_showGuardianOption) return nextOfKinRelationshipOptions;
    return nextOfKinRelationshipOptions
        .where((option) => option.code != 'GUARDIAN')
        .toList();
  }

  List<_Opt> _relationshipOptionsForMemberSex(String memberSex) {
    final options = <_Opt>[
      _Opt('GRANDPARENT', 'Grandparent'),
      _Opt('AUNT', 'Aunt'),
      _Opt('UNCLE', 'Uncle'),
      _Opt('COUSIN', 'Cousin'),
      _Opt('SPOUSE', 'Spouse'),
      _Opt('CHILD', 'Child'),
      _Opt('OTHER_RELATIVE', 'Other relative'),
      _Opt('NON_RELATIVE', 'Non-relative'),
      _Opt('OTHER', 'Other'),
    ];

    if (memberSex == 'MALE') {
      options.insertAll(0, [
        _Opt('FATHER', 'Father'),
        _Opt('BROTHER', 'Brother'),
        _Opt('SON', 'Son'),
        _Opt('GRANDFATHER', 'Grandfather'),
      ]);
    } else if (memberSex == 'FEMALE') {
      options.insertAll(0, [
        _Opt('MOTHER', 'Mother'),
        _Opt('SISTER', 'Sister'),
        _Opt('DAUGHTER', 'Daughter'),
        _Opt('GRANDMOTHER', 'Grandmother'),
      ]);
    }

    if (_isChild) {
      options.add(_Opt('CAREGIVER', 'Caregiver'));
      options.add(_Opt('GUARDIAN', 'Guardian'));
    }

    return options;
  }

  bool _isVisibleReasonGroup(_ReasonGroup group) {
    if (group.childOnly) return _isChild;
    return true;
  }

  bool _isVisibleSingleReason(_Opt reason) {
    if (childOnlySingleReasonCodes.contains(reason.code) && !_isChild) {
      return false;
    }
    if (reason.code == 'TEENAGE_PREGNANCY_YOUNG_MOTHERS') {
      return _isChild && _sex == 'FEMALE';
    }
    if (reason.code == 'SOCIAL_ASSISTANCE_EDUCATIONAL_AID') {
      final age = _clientAge;
      return _isChild && age != null && age < 18;
    }
    return true;
  }

  List<_ReasonGroup> _visibleGroupedReasons() {
    return groupedReasons.where(_isVisibleReasonGroup).toList();
  }

  Set<String> _allVisibleReasonCodes() {
    final codes = <String>{};
    for (final group in _visibleGroupedReasons()) {
      for (final option in group.options) {
        codes.add(option.code);
      }
    }
    for (final reason in singleReasons.where(_isVisibleSingleReason)) {
      codes.add(reason.code);
    }
    return codes;
  }

  void _removeHiddenReasonOptions() {
    final visibleCodes = _allVisibleReasonCodes();
    _selectedReasonOptions.removeWhere((code) => !visibleCodes.contains(code));
    if (!_reasonOtherSelected) _reasonOtherController.clear();
  }

  List<Map<String, String>> _selectedReasonPayload() {
    final payload = <Map<String, String>>[];
    for (final group in groupedReasons) {
      for (final option in group.options) {
        if (_selectedReasonOptions.contains(option.code)) {
          payload.add({
            'type': 'grouped',
            'groupCode': group.code,
            'groupTitle': group.title,
            'optionCode': option.code,
            'optionLabel': option.label,
          });
        }
      }
    }
    for (final reason in singleReasons) {
      if (_selectedReasonOptions.contains(reason.code)) {
        payload.add({
          'type': 'single',
          'groupCode': '',
          'groupTitle': '',
          'optionCode': reason.code,
          'optionLabel': reason.label,
        });
      }
    }
    return payload;
  }

  List<String> _dynamicValues(List<_DynamicTextItem> items) {
    return items
        .map((item) => item.controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  void _addContactedPhoneNumber() {
    setState(() => _contactedPhoneNumbers.add(_DynamicTextItem(id: _newId())));
  }

  void _removeContactedPhoneNumber(int index) {
    setState(() {
      final item = _contactedPhoneNumbers.removeAt(index);
      item.dispose();
      if (_contactedPhoneNumbers.isEmpty) {
        _contactedPhoneNumbers.add(_DynamicTextItem(id: _newId()));
      }
    });
  }

  void _addServiceProvided() {
    setState(() => _servicesAlreadyProvided.add(_DynamicTextItem(id: _newId())));
  }

  void _removeServiceProvided(int index) {
    setState(() {
      final item = _servicesAlreadyProvided.removeAt(index);
      item.dispose();
      if (_servicesAlreadyProvided.isEmpty) {
        _servicesAlreadyProvided.add(_DynamicTextItem(id: _newId()));
      }
    });
  }

  void _addOtherHouseholdMember() {
    setState(() {
      _otherHouseholdMembers.add(
        _HouseholdMemberEntry(id: _newId()),
      );
    });
  }

  void _removeOtherHouseholdMember(int index) {
    setState(() {
      final item = _otherHouseholdMembers.removeAt(index);
      item.dispose();
      if (_otherHouseholdMembers.isEmpty) {
        _otherHouseholdMembers.add(_HouseholdMemberEntry(id: _newId()));
      }
    });
  }

  bool _controllerHasData(TextEditingController controller) {
    return controller.text.trim().isNotEmpty;
  }

  bool _fatherHasData() {
    return _fatherAlive.trim().isNotEmpty ||
        _controllerHasData(_fatherFirstNameController) ||
        _controllerHasData(_fatherSurnameController) ||
        _controllerHasData(_fatherDobController) ||
        _controllerHasData(_fatherOccupationController) ||
        _fatherLivingWithChild.trim().isNotEmpty ||
        _controllerHasData(_fatherWhyNotLivingController) ||
        _controllerHasData(_fatherPhoneController);
  }

  bool _motherHasData() {
    return _motherAlive.trim().isNotEmpty ||
        _controllerHasData(_motherFirstNameController) ||
        _controllerHasData(_motherSurnameController) ||
        _controllerHasData(_motherDobController) ||
        _controllerHasData(_motherOccupationController) ||
        _motherLivingWithChild.trim().isNotEmpty ||
        _controllerHasData(_motherWhyNotLivingController) ||
        _controllerHasData(_motherPhoneController);
  }

  bool _caregiverHasData() {
    return _controllerHasData(_caregiverNameController) ||
        _controllerHasData(_caregiverSurnameController) ||
        _caregiverSex.trim().isNotEmpty ||
        _controllerHasData(_caregiverRelationshipController) ||
        _controllerHasData(_caregiverDobController) ||
        _controllerHasData(_caregiverOccupationController) ||
        _controllerHasData(_caregiverPhoneController);
  }

  bool _personalAssistantHasData() {
    return _isDisabledYes &&
        (_controllerHasData(_personalAssistantNameController) ||
            _controllerHasData(_personalAssistantSurnameController) ||
            _personalAssistantSex.trim().isNotEmpty ||
            _controllerHasData(_personalAssistantRelationshipController) ||
            _controllerHasData(_personalAssistantDobController) ||
            _controllerHasData(_personalAssistantOccupationController) ||
            _controllerHasData(_personalAssistantPhoneController));
  }

  Future<void> _saveTeiOffline({
    required Database db,
    required String teiId,
    required String teiTypeId,
    required String orgUnit,
  }) async {
    await db.insert(
      'tracked_entity_instance',
      {
        'id': _newId(),
        'trackedEntityInstance': teiId,
        'trackedEntityType': teiTypeId,
        'orgUnit': orgUnit,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveAttrOffline({
    required Database db,
    required String teiId,
    required String attribute,
    required String value,
  }) async {
    final v = value.trim();
    if (v.isEmpty) return;
    await db.insert(
      'tracked_entity_instance_attribute',
      {
        'id': _newId(),
        'trackedEntityInstance': teiId,
        'attribute': attribute,
        'value': v,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveAttrsOffline({
    required Database db,
    required String teiId,
    required Map<String, String> attrs,
  }) async {
    for (final entry in attrs.entries) {
      await _saveAttrOffline(
        db: db,
        teiId: teiId,
        attribute: entry.key,
        value: entry.value,
      );
    }
  }

  Future<void> _saveRelationshipOffline({
    required Database db,
    required String relationshipTypeCode,
    required String fromTei,
    required String toTei,
  }) async {
    await db.insert(
      'tei_relationships',
      {
        'id': _newDhis2Uid(),
        'relationshipType': relationshipTypeCode,
        'fromTei': fromTei,
        'toTei': toTei,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveHouseholdMemberOffline({
    required Database db,
    required String householdTei,
    required String memberTei,
    required String memberRole,
    required bool isPrimaryClient,
  }) async {
    await db.insert(
      'mgysd_household_member',
      {
        'id': _newId(),
        'householdTei': householdTei,
        'memberTei': memberTei,
        'memberRole': memberRole,
        'isPrimaryClient': isPrimaryClient ? 'true' : 'false',
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveEnrollmentOffline({
    required Database db,
    required String enrollmentId,
    required String teiId,
    required String programId,
    required String orgUnit,
    required String searchableValue,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    await db.insert(
      'enrollment',
      {
        'id': _newId(),
        'enrollment': enrollmentId,
        'enrollmentDate': nowIso.substring(0, 10),
        'incidentDate': nowIso.substring(0, 10),
        'program': programId,
        'orgUnit': orgUnit,
        'trackedEntityInstance': teiId,
        'status': 'ACTIVE',
        'searchableValue': searchableValue,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveLinkToReportEvent({
    required Database db,
    required String reportEventId,
    required String teiId,
    required String enrollmentId,
  }) async {
    await db.insert(
      'mgysd_report_intake_link',
      {
        'id': _newId(),
        'reportEvent': reportEventId,
        'tei': teiId,
        'enrollment': enrollmentId,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> _savePersonAsFamilyMember({
    required Database db,
    required String householdTeiId,
    required String orgUnit,
    required String memberRole,
    required Map<String, String> attrs,
    required bool enrollInFamilyMembersProgram,
  }) async {
    final memberTeiId = _newDhis2Uid();
    final memberEnrollmentId = _newDhis2Uid();

    await _saveTeiOffline(
      db: db,
      teiId: memberTeiId,
      teiTypeId: mgysdPersonTeiTypeId,
      orgUnit: orgUnit,
    );

    await _saveAttrsOffline(db: db, teiId: memberTeiId, attrs: attrs);

    final searchableValue = [
      attrs[attFirstName] ?? attrs[attCaregiverName] ?? '',
      attrs[attLastName] ?? attrs[attCaregiverSurname] ?? '',
      attrs[attPhone] ?? attrs[attCaregiverPhone] ?? '',
      memberRole,
    ].where((e) => e.trim().isNotEmpty).join(' | ');

    if (enrollInFamilyMembersProgram) {
      await _saveEnrollmentOffline(
        db: db,
        enrollmentId: memberEnrollmentId,
        teiId: memberTeiId,
        programId: mgysdFamilyMembersProgramId,
        orgUnit: orgUnit,
        searchableValue: searchableValue,
      );
    }

    await _saveRelationshipOffline(
      db: db,
      relationshipTypeCode: relHouseholdHasMember,
      fromTei: householdTeiId,
      toTei: memberTeiId,
    );

    await _saveHouseholdMemberOffline(
      db: db,
      householdTei: householdTeiId,
      memberTei: memberTeiId,
      memberRole: memberRole,
      isPrimaryClient: false,
    );

    return memberTeiId;
  }

  bool _shouldEnrollForCaseManagement() {
    final value = _riskLevel.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (value.isEmpty) return false;
    return value != 'LOW' && value != 'NOLOW' && value != 'NOLOWRISK' && value != 'NORISK';
  }

  Future<void> _saveCase() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedReasonOptions.isEmpty) {
      AppUtil.showToastMessage(
        message: 'Please select at least one reason for enrolment.',
      );
      return;
    }

    if (_reasonOtherSelected && _reasonOtherController.text.trim().isEmpty) {
      AppUtil.showToastMessage(
        message: 'Please specify the other reason for enrolment.',
      );
      return;
    }

    if (_riskLevel.trim().isEmpty) {
      AppUtil.showToastMessage(
        message: 'Please select the initial risk level.',
      );
      return;
    }

    if (_riskHasActionTaken.trim().isEmpty) {
      AppUtil.showToastMessage(
        message: 'Please indicate whether emergency action was taken in the initial risk assessment.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final db = await _db();

      final householdTeiId = _newDhis2Uid();
      final clientTeiId = _newDhis2Uid();
      final assessedHouseholdEnrollmentId = _newDhis2Uid();
      final enrolledHouseholdEnrollmentId = _newDhis2Uid();
      final clientFamilyEnrollmentId = _newDhis2Uid();
      final shouldEnrollForCaseManagement = _shouldEnrollForCaseManagement();
      final orgUnit = _selectedCommunityCouncilId.trim();

      if (orgUnit.isEmpty) {
        AppUtil.showToastMessage(
          message: 'Please select the Community Council for this case.',
        );
        setState(() => _saving = false);
        return;
      }

      await _saveTeiOffline(
        db: db,
        teiId: householdTeiId,
        teiTypeId: mgysdHouseholdTeiTypeId,
        orgUnit: orgUnit,
      );

      await _saveAttrsOffline(
        db: db,
        teiId: householdTeiId,
        attrs: {
          attHouseholdFileNumber: _fileNumberController.text,
          attHouseholdDistrict: _selectedDistrictName.isNotEmpty
              ? _selectedDistrictName
              : _districtController.text,
          attHouseholdCommunityCouncil: _selectedCommunityCouncilName.isNotEmpty
              ? _selectedCommunityCouncilName
              : _communityCouncilController.text,
          attHouseholdVillage: _villageController.text,
          attHouseholdAddress: _physicalAddressController.text,
          attReasonForEnrolment: jsonEncode(_selectedReasonPayload()),
          attReasonForEnrolmentOther: _reasonOtherController.text,
          attHasEmergencyActionTaken: _hasEmergencyActionTaken,
          attEmergencyNoActionReason: _emergencyNoActionReason,
          attEmergencyNoActionRefusedSpecify:
          _emergencyNoActionRefusedSpecifyController.text,
          attEmergencyNoActionOtherSpecify:
          _emergencyNoActionOtherSpecifyController.text,
          attEmergencyActionTakenDescription:
          _emergencyActionTakenController.text,
          attEmergencyContactedPhoneNumbers:
          jsonEncode(_dynamicValues(_contactedPhoneNumbers)),
          attEmergencyServicesAlreadyProvided:
          jsonEncode(_dynamicValues(_servicesAlreadyProvided)),
          attRiskAssessmentDate: _riskAssessmentDateController.text,
          attRiskAssessmentSocialWorker: _riskSocialWorkerController.text,
          attRiskAssessmentReportSource: _riskReportSource,
          attRiskAssessmentHasActionTaken: _riskHasActionTaken,
          attRiskAssessmentNoActionReason: _riskNoActionReason,
          attRiskAssessmentEmergencyActionsTaken:
          jsonEncode(_riskEmergencyActionsTaken.toList()),
          attRiskAssessmentServicesAccessed:
          jsonEncode(_riskServicesAccessed.toList()),
          attRiskFamilyBackground: _riskFamilyBackground,
          attRiskFamilyBackgroundNotes: _riskFamilyBackgroundNotesController.text,
          attRiskCaregiverWellbeing: _riskCaregiverWellbeing,
          attRiskCaregiverWellbeingNotes:
          _riskCaregiverWellbeingNotesController.text,
          attRiskExtendedFamilyRelationships: _riskExtendedFamilyRelationships,
          attRiskExtendedFamilyNotes: _riskExtendedFamilyNotesController.text,
          attRiskClientRelationships: _riskClientRelationships,
          attRiskClientRelationshipsNotes:
          _riskClientRelationshipsNotesController.text,
          attRiskLivingCircumstances: _riskLivingCircumstances,
          attRiskLivingCircumstancesNotes:
          _riskLivingCircumstancesNotesController.text,
          attRiskHousing: _riskHousing,
          attRiskHousingNotes: _riskHousingNotesController.text,
          attRiskPhysicalHealth: _riskPhysicalHealth,
          attRiskPhysicalHealthNotes: _riskPhysicalHealthNotesController.text,
          attRiskNutrition: _riskNutrition,
          attRiskNutritionNotes: _riskNutritionNotesController.text,
          attRiskEmotionalHealth: _riskEmotionalHealth,
          attRiskEmotionalHealthNotes: _riskEmotionalHealthNotesController.text,
          attRiskSupervision: _riskSupervision,
          attRiskSupervisionNotes: _riskSupervisionNotesController.text,
          attRiskEducation: _riskEducation,
          attRiskEducationNotes: _riskEducationNotesController.text,
          attRiskLevel: _riskLevel,
          attRiskReason: _riskReasonController.text,
          attRiskImmediateReferrals: _riskImmediateReferralsController.text,
          attRiskNextSteps: jsonEncode(_riskNextSteps.toList()),
          attRiskAdditionalNotes: _riskAdditionalNotesController.text,
        },
      );

      await _saveTeiOffline(
        db: db,
        teiId: clientTeiId,
        teiTypeId: mgysdPersonTeiTypeId,
        orgUnit: orgUnit,
      );

      final clientAttrs = <String, String>{
        attClientCategory: _clientCategory,
        attIsDisabled: _isDisabled,
        attIdentityNumber: _identityNumberController.text,
        attFirstName: _clientFirstNameController.text,
        attLastName: _clientSurnameController.text,
        attDob: _clientDobController.text,
        attAge: _clientAgeController.text,
        attSex: _sex,
        attNationality: _nationality,
        attHomeLanguage: _homeLanguage,
        attHomeLanguageOther: _homeLanguageOtherController.text,
        attPhone: _phoneController.text,
        attAlternativePhone: _alternativePhoneController.text,
        attIsClientInSchool: _isClientInSchool,
        attSchoolName: _schoolNameController.text,
        attGrade: _grade,
        attSchoolAttendanceStatus: _schoolAttendanceStatus,
        attIsAdultEmployed: _isAdultEmployed,
        attEmployerName: _employerNameController.text,
        attNextOfKinFirstName: _nextOfKinFirstNameController.text,
        attNextOfKinSurname: _nextOfKinSurnameController.text,
        attNextOfKinPhone: _nextOfKinPhoneController.text,
        attNextOfKinPhysicalAddress: _nextOfKinPhysicalAddressController.text,
        attNextOfKinRelationship: _nextOfKinRelationship,
        attNextOfKinRelationshipOther:
        _nextOfKinRelationshipOtherController.text,
        // Parent/caregiver/person details are NOT stored on the client TEI.
        // They are saved below as their own separate TEIs using the same generic
        // person attributes: firstName, lastName, dob, sex, occupation, phone.
        // Only case-specific parent-status information remains on the client TEI.
        attFatherAlive: _fatherAlive,
        attFatherLivingWithChild: _fatherLivingWithChild,
        attFatherWhyNotLiving: _fatherWhyNotLivingController.text,
        attMotherAlive: _motherAlive,
        attMotherLivingWithChild: _motherLivingWithChild,
        attMotherWhyNotLiving: _motherWhyNotLivingController.text,
        attReasonForEnrolment: jsonEncode(_selectedReasonPayload()),
        attReasonForEnrolmentOther: _reasonOtherController.text,
        attHasEmergencyActionTaken: _hasEmergencyActionTaken,
        attEmergencyNoActionReason: _emergencyNoActionReason,
        attEmergencyNoActionRefusedSpecify:
        _emergencyNoActionRefusedSpecifyController.text,
        attEmergencyNoActionOtherSpecify:
        _emergencyNoActionOtherSpecifyController.text,
        attEmergencyActionTakenDescription:
        _emergencyActionTakenController.text,
        attEmergencyContactedPhoneNumbers:
        jsonEncode(_dynamicValues(_contactedPhoneNumbers)),
        attEmergencyServicesAlreadyProvided:
        jsonEncode(_dynamicValues(_servicesAlreadyProvided)),
        attRiskAssessmentDate: _riskAssessmentDateController.text,
        attRiskAssessmentSocialWorker: _riskSocialWorkerController.text,
        attRiskAssessmentReportSource: _riskReportSource,
        attRiskAssessmentHasActionTaken: _riskHasActionTaken,
        attRiskAssessmentNoActionReason: _riskNoActionReason,
        attRiskAssessmentEmergencyActionsTaken:
        jsonEncode(_riskEmergencyActionsTaken.toList()),
        attRiskAssessmentServicesAccessed:
        jsonEncode(_riskServicesAccessed.toList()),
        attRiskFamilyBackground: _riskFamilyBackground,
        attRiskFamilyBackgroundNotes: _riskFamilyBackgroundNotesController.text,
        attRiskCaregiverWellbeing: _riskCaregiverWellbeing,
        attRiskCaregiverWellbeingNotes:
        _riskCaregiverWellbeingNotesController.text,
        attRiskExtendedFamilyRelationships: _riskExtendedFamilyRelationships,
        attRiskExtendedFamilyNotes: _riskExtendedFamilyNotesController.text,
        attRiskClientRelationships: _riskClientRelationships,
        attRiskClientRelationshipsNotes:
        _riskClientRelationshipsNotesController.text,
        attRiskLivingCircumstances: _riskLivingCircumstances,
        attRiskLivingCircumstancesNotes:
        _riskLivingCircumstancesNotesController.text,
        attRiskHousing: _riskHousing,
        attRiskHousingNotes: _riskHousingNotesController.text,
        attRiskPhysicalHealth: _riskPhysicalHealth,
        attRiskPhysicalHealthNotes: _riskPhysicalHealthNotesController.text,
        attRiskNutrition: _riskNutrition,
        attRiskNutritionNotes: _riskNutritionNotesController.text,
        attRiskEmotionalHealth: _riskEmotionalHealth,
        attRiskEmotionalHealthNotes: _riskEmotionalHealthNotesController.text,
        attRiskSupervision: _riskSupervision,
        attRiskSupervisionNotes: _riskSupervisionNotesController.text,
        attRiskEducation: _riskEducation,
        attRiskEducationNotes: _riskEducationNotesController.text,
        attRiskLevel: _riskLevel,
        attRiskReason: _riskReasonController.text,
        attRiskImmediateReferrals: _riskImmediateReferralsController.text,
        attRiskNextSteps: jsonEncode(_riskNextSteps.toList()),
        attRiskAdditionalNotes: _riskAdditionalNotesController.text,
      };

      await _saveAttrsOffline(db: db, teiId: clientTeiId, attrs: clientAttrs);

      final searchableValue = [
        _fileNumberController.text.trim(),
        _clientFirstNameController.text.trim(),
        _clientSurnameController.text.trim(),
        _identityNumberController.text.trim(),
        widget.reportedEventId == null
            ? ''
            : 'reportEvent:${widget.reportedEventId}',
      ].where((e) => e.isNotEmpty).join(' | ');

      final householdSearchableValue = [
        _fileNumberController.text.trim(),
        _selectedDistrictName.trim(),
        _selectedCommunityCouncilName.trim(),
        _villageController.text.trim(),
        'risk:$_riskLevel',
      ].where((e) => e.isNotEmpty).join(' | ');

      await _saveEnrollmentOffline(
        db: db,
        enrollmentId: assessedHouseholdEnrollmentId,
        teiId: householdTeiId,
        programId: mgysdAssessedHouseholdsProgramId,
        orgUnit: orgUnit,
        searchableValue: householdSearchableValue,
      );

      if (shouldEnrollForCaseManagement) {
        await _saveEnrollmentOffline(
          db: db,
          enrollmentId: enrolledHouseholdEnrollmentId,
          teiId: householdTeiId,
          programId: mgysdEnrolledHouseholdsProgramId,
          orgUnit: orgUnit,
          searchableValue: householdSearchableValue,
        );

        await _saveEnrollmentOffline(
          db: db,
          enrollmentId: clientFamilyEnrollmentId,
          teiId: clientTeiId,
          programId: mgysdFamilyMembersProgramId,
          orgUnit: orgUnit,
          searchableValue: searchableValue,
        );
      }

      await _saveRelationshipOffline(
        db: db,
        relationshipTypeCode: relHouseholdHasMember,
        fromTei: householdTeiId,
        toTei: clientTeiId,
      );

      await _saveHouseholdMemberOffline(
        db: db,
        householdTei: householdTeiId,
        memberTei: clientTeiId,
        memberRole: 'CLIENT',
        isPrimaryClient: true,
      );

      final reportEventId = (widget.reportedEventId ?? '').trim();
      if (reportEventId.isNotEmpty) {
        await _saveLinkToReportEvent(
          db: db,
          reportEventId: reportEventId,
          teiId: householdTeiId,
          enrollmentId: assessedHouseholdEnrollmentId,
        );
      }

      if (_fatherHasData()) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: 'FATHER',
          enrollInFamilyMembersProgram: shouldEnrollForCaseManagement,
          attrs: {
            attFirstName: _fatherFirstNameController.text,
            attLastName: _fatherSurnameController.text,
            attDob: _fatherDobController.text,
            attOccupation: _fatherOccupationController.text,
            attPhone: _fatherPhoneController.text,
            attSex: 'MALE',
            attRelationshipToClient: 'FATHER',
            attFatherAlive: _fatherAlive,
            attFatherLivingWithChild: _fatherLivingWithChild,
            attFatherWhyNotLiving: _fatherWhyNotLivingController.text,
          },
        );
      }

      if (_motherHasData()) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: 'MOTHER',
          enrollInFamilyMembersProgram: shouldEnrollForCaseManagement,
          attrs: {
            attFirstName: _motherFirstNameController.text,
            attLastName: _motherSurnameController.text,
            attDob: _motherDobController.text,
            attOccupation: _motherOccupationController.text,
            attPhone: _motherPhoneController.text,
            attSex: 'FEMALE',
            attRelationshipToClient: 'MOTHER',
            attMotherAlive: _motherAlive,
            attMotherLivingWithChild: _motherLivingWithChild,
            attMotherWhyNotLiving: _motherWhyNotLivingController.text,
          },
        );
      }

      if (_caregiverHasData()) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: 'CAREGIVER',
          enrollInFamilyMembersProgram: shouldEnrollForCaseManagement,
          attrs: {
            attFirstName: _caregiverNameController.text,
            attLastName: _caregiverSurnameController.text,
            attSex: _caregiverSex,
            attRelationshipToClient: _caregiverRelationshipController.text,
            attDob: _caregiverDobController.text,
            attOccupation: _caregiverOccupationController.text,
            attPhone: _caregiverPhoneController.text,
          },
        );
      }

      if (_personalAssistantHasData()) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: 'PERSONAL_ASSISTANT',
          enrollInFamilyMembersProgram: shouldEnrollForCaseManagement,
          attrs: {
            attFirstName: _personalAssistantNameController.text,
            attLastName: _personalAssistantSurnameController.text,
            attSex: _personalAssistantSex,
            attRelationshipToClient:
            _personalAssistantRelationshipController.text,
            attDob: _personalAssistantDobController.text,
            attOccupation: _personalAssistantOccupationController.text,
            attPhone: _personalAssistantPhoneController.text,
          },
        );
      }

      for (final member in _otherHouseholdMembers.where((m) => m.hasAnyData)) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: member.relationshipToClient.isEmpty
              ? 'HOUSEHOLD_MEMBER'
              : member.relationshipToClient,
          enrollInFamilyMembersProgram: shouldEnrollForCaseManagement,
          attrs: {
            attFirstName: member.firstNameController.text,
            attLastName: member.surnameController.text,
            attDob: member.dobController.text,
            attAge: member.ageController.text,
            attSex: member.sex,
            attRelationshipToClient: member.relationshipToClient,
            attOccupation: member.occupationController.text,
            attPhone: member.contactsController.text,
            attHasDisability: member.hasDisability,
            attDisabilitySpecify: member.disabilitySpecifyController.text,
          },
        );
      }

      AppUtil.showToastMessage(
        message: shouldEnrollForCaseManagement
            ? 'Household assessed and enrolled for case management.'
            : 'Household assessed. Risk is No/Low, so it was not enrolled for case management.',
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      AppUtil.showToastMessage(message: 'Failed to save case: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _titleRow({
    required Color color,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                  const TextStyle(color: Colors.blueGrey, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<_Opt> options,
    required void Function(String?) onChanged,
    bool requiredField = false,
  }) {
    final safeValue = options.any((o) => o.code == value) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      items: options
          .map(
            (o) => DropdownMenuItem<String>(
          value: o.code,
          child: Text(o.label, overflow: TextOverflow.ellipsis),
        ),
      )
          .toList(),
      onChanged: onChanged,
      validator: (v) {
        if (!requiredField) return null;
        if ((v ?? '').trim().isEmpty) return 'Required';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );
  }

  Widget _dateInput({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return GestureDetector(
      onTap: () => _pickDateFor(controller),
      child: AbsorbPointer(
        child: _Input(
          controller: controller,
          label: label,
          hint: hint,
          suffixIcon: const Icon(Icons.date_range),
        ),
      ),
    );
  }

  Widget _reasonGroupCard(_ReasonGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.title,
              style:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options.map(_reasonChoiceChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _reasonChoiceChip(_Opt option) {
    final selected = _selectedReasonOptions.contains(option.code);
    return FilterChip(
      selected: selected,
      label: Text(option.label),
      selectedColor: widget.color.withOpacity(0.16),
      checkmarkColor: widget.color,
      onSelected: (checked) {
        setState(() {
          if (checked) {
            _selectedReasonOptions.add(option.code);
          } else {
            _selectedReasonOptions.remove(option.code);
            if (option.code == 'OTHER') _reasonOtherController.clear();
          }
        });
      },
    );
  }

  Widget _buildReasonSection(Color primary) {
    final visibleSingleReasons =
    singleReasons.where(_isVisibleSingleReason).toList();

    return MaterialCard(
      body: Container(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              color: primary,
              title: 'Reason for Enrolment',
              subtitle: 'Select all applicable reasons for this case.',
              icon: Icons.fact_check_outlined,
            ),
            const SizedBox(height: 12),
            ..._visibleGroupedReasons().map(_reasonGroupCard).toList(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Other enrolment reasons',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                    visibleSingleReasons.map(_reasonChoiceChip).toList(),
                  ),
                  if (_reasonOtherSelected) ...[
                    const SizedBox(height: 12),
                    _Input(
                      controller: _reasonOtherController,
                      label: 'Specify other reason',
                      hint: 'Describe other reason for enrolment',
                      maxLines: 3,
                      validator: (v) {
                        if (_reasonOtherSelected &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Please specify other reason';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dynamicTextList({
    required String title,
    required List<_DynamicTextItem> items,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    required VoidCallback onAdd,
    required void Function(int index) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
          const TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey),
        ),
        const SizedBox(height: 8),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Input(
                    controller: item.controller,
                    label: '$label ${index + 1}',
                    hint: hint,
                    keyboardType: keyboardType,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text('Add $label'),
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.color,
            side: BorderSide(color: widget.color),
          ),
        ),
      ],
    );
  }

  Widget _orgUnitDropdown({
    required String label,
    required String value,
    required List<OrganisationUnit> options,
    required String hint,
    required void Function(OrganisationUnit selected) onChanged,
    bool requiredField = false,
  }) {
    final safeValue = options.any((ou) => ou.id == value) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      items: options
          .map(
            (ou) => DropdownMenuItem<String>(
          value: ou.id,
          child: Text(
            ou.name ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .toList(),
      onChanged: _loadingOrgUnits
          ? null
          : (selectedId) {
        if (selectedId == null || selectedId.trim().isEmpty) return;
        final selected = options.firstWhere((ou) => ou.id == selectedId);
        onChanged(selected);
      },
      validator: (v) {
        if (!requiredField) return null;
        if ((v ?? '').trim().isEmpty) return 'Required';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: _loadingOrgUnits
            ? const Padding(
          padding: EdgeInsets.all(12.0),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildEmergencyActionSection(Color primary) {
    return MaterialCard(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              color: primary,
              title: 'Any Emergency Actions Already Taken',
              subtitle:
              'Capture immediate actions, people contacted, and services already provided.',
              icon: Icons.emergency_outlined,
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Has any action already been taken?',
              value: _hasEmergencyActionTaken,
              options: yesNoOptions,
              requiredField: true,
              onChanged: (v) {
                setState(() {
                  _hasEmergencyActionTaken = v ?? '';
                  if (_hasEmergencyActionTaken != 'YES') {
                    _emergencyActionTakenController.clear();
                  }
                  if (_hasEmergencyActionTaken != 'NO') {
                    _emergencyNoActionReason = '';
                    _emergencyNoActionRefusedSpecifyController.clear();
                    _emergencyNoActionOtherSpecifyController.clear();
                  }
                });
              },
            ),
            if (_hasEmergencyActionTaken == 'NO') ...[
              const SizedBox(height: 10),
              _dropdown(
                label: 'If no, specify',
                value: _emergencyNoActionReason,
                options: emergencyNoActionOptions,
                requiredField: true,
                onChanged: (v) {
                  setState(() {
                    _emergencyNoActionReason = v ?? '';
                    if (_emergencyNoActionReason != 'REFUSED') {
                      _emergencyNoActionRefusedSpecifyController.clear();
                    }
                    if (_emergencyNoActionReason != 'OTHER') {
                      _emergencyNoActionOtherSpecifyController.clear();
                    }
                  });
                },
              ),
              if (_emergencyNoActionReason == 'REFUSED') ...[
                const SizedBox(height: 10),
                _Input(
                  controller: _emergencyNoActionRefusedSpecifyController,
                  label: 'Specify refusal reason',
                  hint: 'Explain why action was refused',
                  maxLines: 3,
                ),
              ],
              if (_emergencyNoActionReason == 'OTHER') ...[
                const SizedBox(height: 10),
                _Input(
                  controller: _emergencyNoActionOtherSpecifyController,
                  label: 'Specify other reason',
                  hint: 'Explain other reason',
                  maxLines: 3,
                ),
              ],
            ],
            if (_hasEmergencyActionTaken == 'YES') ...[
              const SizedBox(height: 10),
              _Input(
                controller: _emergencyActionTakenController,
                label: 'Explain what action was taken',
                hint: 'Describe emergency action already taken',
                maxLines: 4,
              ),
            ],
            const SizedBox(height: 14),
            _dynamicTextList(
              title: 'Phone numbers of people contacted, if any',
              items: _contactedPhoneNumbers,
              label: 'Phone number',
              hint: 'e.g. 5xxxxxxx',
              keyboardType: TextInputType.phone,
              onAdd: _addContactedPhoneNumber,
              onRemove: _removeContactedPhoneNumber,
            ),
            const SizedBox(height: 14),
            _dynamicTextList(
              title: 'Services already provided, if any',
              items: _servicesAlreadyProvided,
              label: 'Service',
              hint: 'e.g. Police notified, counselling, temporary shelter',
              keyboardType: TextInputType.text,
              onAdd: _addServiceProvided,
              onRemove: _removeServiceProvided,
            ),
          ],
        ),
      ),
    );
  }


  Widget _riskChoiceChip({
    required _Opt option,
    required Set<String> selectedValues,
  }) {
    final selected = selectedValues.contains(option.code);
    return FilterChip(
      selected: selected,
      label: Text(option.label),
      selectedColor: widget.color.withOpacity(0.16),
      checkmarkColor: widget.color,
      onSelected: (checked) {
        setState(() {
          if (checked) {
            selectedValues.add(option.code);
          } else {
            selectedValues.remove(option.code);
          }
        });
      },
    );
  }

  Widget _riskMultiSelect({
    required String title,
    required List<_Opt> options,
    required Set<String> selectedValues,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((option) => _riskChoiceChip(
              option: option,
              selectedValues: selectedValues,
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _riskDomainItem({
    required String title,
    required String value,
    required List<_Opt> options,
    required void Function(String?) onChanged,
    required TextEditingController notesController,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Initial rapid strengths and risks assessed',
            value: value,
            options: options,
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          _Input(
            controller: notesController,
            label: 'Notes / supporting evidence',
            hint: 'Add notes or evidence observed during intake',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialRiskAssessmentSection(Color primary) {
    return MaterialCard(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              color: primary,
              title: 'Initial Risk Assessment',
              subtitle: 'Rapid screening completed together with intake.',
              icon: Icons.health_and_safety_outlined,
            ),
            const SizedBox(height: 12),
            _row2(
              GestureDetector(
                onTap: () => _pickDateFor(_riskAssessmentDateController),
                child: AbsorbPointer(
                  child: _Input(
                    controller: _riskAssessmentDateController,
                    label: 'Assessment Date',
                    hint: 'Pick date',
                    suffixIcon: const Icon(Icons.date_range),
                  ),
                ),
              ),
              _Input(
                controller: _riskSocialWorkerController,
                label: 'Social Worker',
                hint: 'Name of social worker',
              ),
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'Report Source',
              value: _riskReportSource,
              options: riskReportSourceOptions,
              onChanged: (v) => setState(() => _riskReportSource = v ?? ''),
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: 'Has any emergency action been taken? *',
              value: _riskHasActionTaken,
              options: yesNoOptions,
              requiredField: true,
              onChanged: (v) {
                setState(() {
                  _riskHasActionTaken = v ?? '';
                  if (_riskHasActionTaken != 'NO') {
                    _riskNoActionReason = '';
                  }
                });
              },
            ),
            if (_riskHasActionTaken == 'NO') ...[
              const SizedBox(height: 10),
              _dropdown(
                label: 'If no, why?',
                value: _riskNoActionReason,
                options: riskNoActionReasonOptions,
                onChanged: (v) => setState(() => _riskNoActionReason = v ?? ''),
              ),
            ],
            const SizedBox(height: 12),
            _riskMultiSelect(
              title: 'Emergency actions taken',
              options: riskEmergencyActionOptions,
              selectedValues: _riskEmergencyActionsTaken,
            ),
            const SizedBox(height: 12),
            _riskMultiSelect(
              title: 'Services accessed',
              options: riskServicesAccessedOptions,
              selectedValues: _riskServicesAccessed,
            ),
            const SizedBox(height: 14),
            _riskDomainItem(
              title: 'Family background',
              value: _riskFamilyBackground,
              options: riskFamilyBackgroundOptions,
              onChanged: (v) => setState(() => _riskFamilyBackground = v ?? ''),
              notesController: _riskFamilyBackgroundNotesController,
            ),
            _riskDomainItem(
              title: 'Caregiver wellbeing',
              value: _riskCaregiverWellbeing,
              options: riskCaregiverWellbeingOptions,
              onChanged: (v) => setState(() => _riskCaregiverWellbeing = v ?? ''),
              notesController: _riskCaregiverWellbeingNotesController,
            ),
            _riskDomainItem(
              title: 'Extended family relationships',
              value: _riskExtendedFamilyRelationships,
              options: riskRelationshipOptions,
              onChanged: (v) => setState(() => _riskExtendedFamilyRelationships = v ?? ''),
              notesController: _riskExtendedFamilyNotesController,
            ),
            _riskDomainItem(
              title: 'Client relationships',
              value: _riskClientRelationships,
              options: riskRelationshipOptions,
              onChanged: (v) => setState(() => _riskClientRelationships = v ?? ''),
              notesController: _riskClientRelationshipsNotesController,
            ),
            _riskDomainItem(
              title: 'Living circumstances',
              value: _riskLivingCircumstances,
              options: riskLivingCircumstancesOptions,
              onChanged: (v) => setState(() => _riskLivingCircumstances = v ?? ''),
              notesController: _riskLivingCircumstancesNotesController,
            ),
            _riskDomainItem(
              title: 'Housing',
              value: _riskHousing,
              options: riskHousingOptions,
              onChanged: (v) => setState(() => _riskHousing = v ?? ''),
              notesController: _riskHousingNotesController,
            ),
            _riskDomainItem(
              title: 'Physical health',
              value: _riskPhysicalHealth,
              options: riskPhysicalHealthOptions,
              onChanged: (v) => setState(() => _riskPhysicalHealth = v ?? ''),
              notesController: _riskPhysicalHealthNotesController,
            ),
            _riskDomainItem(
              title: 'Nutrition',
              value: _riskNutrition,
              options: riskNutritionOptions,
              onChanged: (v) => setState(() => _riskNutrition = v ?? ''),
              notesController: _riskNutritionNotesController,
            ),
            _riskDomainItem(
              title: 'Emotional health',
              value: _riskEmotionalHealth,
              options: riskEmotionalHealthOptions,
              onChanged: (v) => setState(() => _riskEmotionalHealth = v ?? ''),
              notesController: _riskEmotionalHealthNotesController,
            ),
            _riskDomainItem(
              title: 'Supervision',
              value: _riskSupervision,
              options: riskSupervisionOptions,
              onChanged: (v) => setState(() => _riskSupervision = v ?? ''),
              notesController: _riskSupervisionNotesController,
            ),
            _riskDomainItem(
              title: 'Education',
              value: _riskEducation,
              options: riskEducationOptions,
              onChanged: (v) => setState(() => _riskEducation = v ?? ''),
              notesController: _riskEducationNotesController,
            ),
            const SizedBox(height: 8),
            _dropdown(
              label: 'Decision on level of risk *',
              value: _riskLevel,
              options: riskLevelOptions,
              requiredField: true,
              onChanged: (v) => setState(() => _riskLevel = v ?? ''),
            ),
            const SizedBox(height: 10),
            _Input(
              controller: _riskReasonController,
              label: 'Risk reason',
              hint: 'Explain the reason for the selected level of risk',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            _Input(
              controller: _riskImmediateReferralsController,
              label: 'Immediate referrals',
              hint: 'Record immediate referrals needed or made',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _riskMultiSelect(
              title: 'Next steps',
              options: riskNextStepOptions,
              selectedValues: _riskNextSteps,
            ),
            const SizedBox(height: 12),
            _Input(
              controller: _riskAdditionalNotesController,
              label: 'Additional notes',
              hint: 'Any additional initial risk notes',
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _parentSection({
    required String title,
    required String aliveValue,
    required void Function(String value) onAliveChanged,
    required TextEditingController firstNameController,
    required TextEditingController surnameController,
    required TextEditingController dobController,
    required TextEditingController occupationController,
    required String livingWithChildValue,
    required void Function(String value) onLivingWithChildChanged,
    required TextEditingController whyNotLivingController,
    required TextEditingController phoneController,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Is $title alive?',
            value: aliveValue,
            options: yesNoUnknownOptions,
            requiredField: true,
            onChanged: (v) => onAliveChanged(v ?? ''),
          ),
          if (aliveValue == 'YES') ...[
            const SizedBox(height: 10),
            _row2(
              _Input(
                controller: firstNameController,
                label: '$title First Name',
                hint: 'Enter first name',
              ),
              _Input(
                controller: surnameController,
                label: '$title Surname',
                hint: 'Enter surname',
              ),
            ),
            const SizedBox(height: 10),
            _row2(
              _dateInput(
                controller: dobController,
                label: 'Date of Birth',
                hint: 'Pick date',
              ),
              _Input(
                controller: occupationController,
                label: 'Occupation',
                hint: 'Enter occupation',
              ),
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'Is $title living with the child?',
              value: livingWithChildValue,
              options: yesNoUnknownOptions,
              requiredField: true,
              onChanged: (v) => onLivingWithChildChanged(v ?? ''),
            ),
            if (livingWithChildValue != 'YES' &&
                livingWithChildValue.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _Input(
                controller: whyNotLivingController,
                label: 'Why?',
                hint: 'Explain why not living with the child',
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _Input(
                controller: phoneController,
                label: 'Phone Number',
                hint: 'e.g. 5xxxxxxx',
                keyboardType: TextInputType.phone,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _caregiverSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Caregiver',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _row2(
            _Input(
              controller: _caregiverNameController,
              label: 'Name',
              hint: 'Caregiver name',
            ),
            _Input(
              controller: _caregiverSurnameController,
              label: 'Surname',
              hint: 'Caregiver surname',
            ),
          ),
          const SizedBox(height: 10),
          _row2(
            _dropdown(
              label: 'Sex',
              value: _caregiverSex,
              options: sexOptions,
              onChanged: (v) => setState(() => _caregiverSex = v ?? ''),
            ),
            _Input(
              controller: _caregiverRelationshipController,
              label: 'Relationship with client',
              hint: 'e.g. Aunt, Grandmother',
            ),
          ),
          const SizedBox(height: 10),
          _row2(
            _dateInput(
              controller: _caregiverDobController,
              label: 'Date of Birth',
              hint: 'Pick date',
            ),
            _Input(
              controller: _caregiverOccupationController,
              label: 'Occupation',
              hint: 'Enter occupation',
            ),
          ),
          const SizedBox(height: 10),
          _Input(
            controller: _caregiverPhoneController,
            label: 'Phone Number',
            hint: 'e.g. 5xxxxxxx',
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _personalAssistantSection() {
    if (!_isDisabledYes) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Assistant',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _row2(
            _Input(
              controller: _personalAssistantNameController,
              label: 'Name',
              hint: 'Personal assistant name',
            ),
            _Input(
              controller: _personalAssistantSurnameController,
              label: 'Surname',
              hint: 'Personal assistant surname',
            ),
          ),
          const SizedBox(height: 10),
          _row2(
            _dropdown(
              label: 'Sex',
              value: _personalAssistantSex,
              options: sexOptions,
              onChanged: (v) {
                setState(() => _personalAssistantSex = v ?? '');
              },
            ),
            _Input(
              controller: _personalAssistantRelationshipController,
              label: 'Relationship with client',
              hint: 'Enter relationship',
            ),
          ),
          const SizedBox(height: 10),
          _row2(
            _dateInput(
              controller: _personalAssistantDobController,
              label: 'Date of Birth',
              hint: 'Pick date',
            ),
            _Input(
              controller: _personalAssistantOccupationController,
              label: 'Occupation',
              hint: 'Enter occupation',
            ),
          ),
          const SizedBox(height: 10),
          _Input(
            controller: _personalAssistantPhoneController,
            label: 'Phone Number',
            hint: 'e.g. 5xxxxxxx',
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyInformationSection(Color primary) {
    return MaterialCard(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              color: primary,
              title: 'Family Information',
              subtitle:
              'Capture parents, caregiver, and personal assistant details where applicable.',
              icon: Icons.family_restroom_outlined,
            ),
            const SizedBox(height: 12),
            _parentSection(
              title: 'Father',
              aliveValue: _fatherAlive,
              onAliveChanged: (value) {
                setState(() {
                  _fatherAlive = value;
                  if (_fatherAlive != 'YES') {
                    _fatherFirstNameController.clear();
                    _fatherSurnameController.clear();
                    _fatherDobController.clear();
                    _fatherOccupationController.clear();
                    _fatherLivingWithChild = '';
                    _fatherWhyNotLivingController.clear();
                    _fatherPhoneController.clear();
                  }
                });
              },
              firstNameController: _fatherFirstNameController,
              surnameController: _fatherSurnameController,
              dobController: _fatherDobController,
              occupationController: _fatherOccupationController,
              livingWithChildValue: _fatherLivingWithChild,
              onLivingWithChildChanged: (value) {
                setState(() {
                  _fatherLivingWithChild = value;
                  if (_fatherLivingWithChild == 'YES') {
                    _fatherWhyNotLivingController.clear();
                    _fatherPhoneController.clear();
                  }
                });
              },
              whyNotLivingController: _fatherWhyNotLivingController,
              phoneController: _fatherPhoneController,
            ),
            _parentSection(
              title: 'Mother',
              aliveValue: _motherAlive,
              onAliveChanged: (value) {
                setState(() {
                  _motherAlive = value;
                  if (_motherAlive != 'YES') {
                    _motherFirstNameController.clear();
                    _motherSurnameController.clear();
                    _motherDobController.clear();
                    _motherOccupationController.clear();
                    _motherLivingWithChild = '';
                    _motherWhyNotLivingController.clear();
                    _motherPhoneController.clear();
                  }
                });
              },
              firstNameController: _motherFirstNameController,
              surnameController: _motherSurnameController,
              dobController: _motherDobController,
              occupationController: _motherOccupationController,
              livingWithChildValue: _motherLivingWithChild,
              onLivingWithChildChanged: (value) {
                setState(() {
                  _motherLivingWithChild = value;
                  if (_motherLivingWithChild == 'YES') {
                    _motherWhyNotLivingController.clear();
                    _motherPhoneController.clear();
                  }
                });
              },
              whyNotLivingController: _motherWhyNotLivingController,
              phoneController: _motherPhoneController,
            ),
            _caregiverSection(),
            _personalAssistantSection(),
          ],
        ),
      ),
    );
  }

  Widget _householdMemberCard(int index, _HouseholdMemberEntry member) {
    final relationshipOptions = _relationshipOptionsForMemberSex(member.sex);
    final safeRelationship = relationshipOptions
        .any((option) => option.code == member.relationshipToClient)
        ? member.relationshipToClient
        : '';

    if (safeRelationship != member.relationshipToClient) {
      member.relationshipToClient = '';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Household Member ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeOtherHouseholdMember(index),
                icon: const Icon(Icons.delete_outline),
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row2(
            _Input(
              controller: member.firstNameController,
              label: 'First name',
              hint: 'Enter first name',
            ),
            _Input(
              controller: member.surnameController,
              label: 'Surname',
              hint: 'Enter surname',
            ),
          ),
          const SizedBox(height: 10),
          _row2(
            GestureDetector(
              onTap: () => _pickDobForHouseholdMember(member),
              child: AbsorbPointer(
                child: _Input(
                  controller: member.dobController,
                  label: 'Date of Birth',
                  hint: 'Pick date',
                  suffixIcon: const Icon(Icons.date_range),
                ),
              ),
            ),
            _Input(
              controller: member.ageController,
              label: 'Age',
              hint: 'Auto-calculated',
              readOnly: true,
            ),
          ),
          const SizedBox(height: 10),
          _row2(
            _dropdown(
              label: 'Sex',
              value: member.sex,
              options: sexOptions,
              onChanged: (v) {
                setState(() {
                  member.sex = v ?? '';
                  member.relationshipToClient = '';
                });
              },
            ),
            _dropdown(
              label: 'Relationship to client',
              value: safeRelationship,
              options: relationshipOptions,
              onChanged: (v) {
                setState(() {
                  member.relationshipToClient = v ?? '';
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          _row2(
            _Input(
              controller: member.occupationController,
              label: 'Occupation',
              hint: 'Enter occupation',
            ),
            _Input(
              controller: member.contactsController,
              label: 'Contacts',
              hint: 'Phone / contact details',
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Any Disability?',
            value: member.hasDisability,
            options: yesNoOptions,
            onChanged: (v) {
              setState(() {
                member.hasDisability = v ?? '';
                if (member.hasDisability != 'YES') {
                  member.disabilitySpecifyController.clear();
                }
              });
            },
          ),
          if (member.hasDisability == 'YES') ...[
            const SizedBox(height: 10),
            _Input(
              controller: member.disabilitySpecifyController,
              label: 'Specify disability',
              hint: 'Describe disability',
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtherHouseholdMembersSection(Color primary) {
    return MaterialCard(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              color: primary,
              title: 'Other Household Members',
              subtitle:
              'Capture other household members as separate TEIs linked to this household.',
              icon: Icons.groups_outlined,
            ),
            const SizedBox(height: 12),
            ...List.generate(
              _otherHouseholdMembers.length,
                  (index) => _householdMemberCard(
                index,
                _otherHouseholdMembers[index],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _addOtherHouseholdMember,
              icon: const Icon(Icons.add),
              label: const Text('Add household member'),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.color,
                side: BorderSide(color: widget.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeInterventionProgram =
        Provider.of<InterventionCardState>(context, listen: false)
            .currentInterventionProgram;
    final Color primary = activeInterventionProgram.primaryColor ?? widget.color;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65.0),
        child: SubPageAppBar(
          label: widget.reportedEventId == null
              ? 'Intake And Initial Risk Assessment'
              : 'Enroll Client Case',
          activeInterventionProgram: activeInterventionProgram,
          disableSelectionOfActiveIntervention: false,
        ),
      ),
      body: SubPageBody(
        body: SingleChildScrollView(
          child: Container(
            margin:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if ((widget.reportedEventId ?? '').trim().isNotEmpty)
                    MaterialCard(
                      body: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(Icons.link, color: widget.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Linked to report event: ${widget.reportedEventId}',
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  MaterialCard(
                    body: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _titleRow(
                            color: primary,
                            title: 'Household Location',
                            subtitle:
                            'Capture the household location and file reference.',
                            icon: Icons.home_work_outlined,
                          ),
                          const SizedBox(height: 12),
                          _Input(
                            controller: _fileNumberController,
                            label: 'File Number',
                            hint: 'e.g. MGYSD-0001',
                            validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'File number is required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          _orgUnitDropdown(
                            label: 'District',
                            value: _selectedDistrictId,
                            options: _districtOrgUnits,
                            hint: 'Select district',
                            requiredField: true,
                            onChanged: (selected) {
                              setState(() {
                                _selectedDistrictId = selected.id ?? '';
                                _selectedDistrictName = selected.name ?? '';
                                _districtController.text = _selectedDistrictName;
                                _selectedCommunityCouncilId = '';
                                _selectedCommunityCouncilName = '';
                                _communityCouncilController.clear();
                                _communityCouncilOrgUnits = [];
                              });
                              _loadCommunityCouncilsForDistrict(
                                _selectedDistrictId,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _orgUnitDropdown(
                            label: 'Community Council',
                            value: _selectedCommunityCouncilId,
                            options: _communityCouncilOrgUnits,
                            hint: _selectedDistrictId.isEmpty
                                ? 'Select district first'
                                : 'Select community council',
                            requiredField: true,
                            onChanged: (selected) {
                              setState(() {
                                _selectedCommunityCouncilId = selected.id ?? '';
                                _selectedCommunityCouncilName = selected.name ?? '';
                                _communityCouncilController.text =
                                    _selectedCommunityCouncilName;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _Input(
                            controller: _villageController,
                            label: 'Village',
                            hint: 'e.g. Ha Thetsane',
                            validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Village is required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          _Input(
                            controller: _physicalAddressController,
                            label: 'Physical Address',
                            hint: 'Describe the household physical address',
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MaterialCard(
                    body: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _titleRow(
                            color: primary,
                            title: 'Demographics and Reporting Information',
                            subtitle:
                            'Capture the main client information for this case.',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 12),
                          _dropdown(
                            label: 'Client category',
                            value: _clientCategory,
                            options: clientCategoryOptions,
                            requiredField: true,
                            onChanged: (v) {
                              setState(() {
                                _clientCategory = v ?? '';
                                if (!_isAdultOrElderly) {
                                  _isAdultEmployed = '';
                                  _employerNameController.clear();
                                }
                                if (_isAdultOrElderly) _grade = '';
                                _removeHiddenReasonOptions();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _dropdown(
                            label: 'Is the client disabled?',
                            value: _isDisabled,
                            options: yesNoOptions,
                            requiredField: true,
                            onChanged: (v) {
                              setState(() {
                                _isDisabled = v ?? '';
                                if (!_showGuardianOption &&
                                    _nextOfKinRelationship == 'GUARDIAN') {
                                  _nextOfKinRelationship = '';
                                }
                                if (!_isDisabledYes) {
                                  _personalAssistantNameController.clear();
                                  _personalAssistantSurnameController.clear();
                                  _personalAssistantSex = '';
                                  _personalAssistantRelationshipController
                                      .clear();
                                  _personalAssistantDobController.clear();
                                  _personalAssistantOccupationController
                                      .clear();
                                  _personalAssistantPhoneController.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _Input(
                            controller: _identityNumberController,
                            label: 'Identity Number',
                            hint: 'National ID / document number',
                          ),
                          const SizedBox(height: 10),
                          _row2(
                            _Input(
                              controller: _clientFirstNameController,
                              label: 'First name',
                              hint: 'Client first name',
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'First name is required'
                                  : null,
                            ),
                            _Input(
                              controller: _clientSurnameController,
                              label: 'Surname',
                              hint: 'Client surname',
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Surname is required'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _row2(
                            GestureDetector(
                              onTap: _pickDobForClient,
                              child: AbsorbPointer(
                                child: _Input(
                                  controller: _clientDobController,
                                  label: 'Date of Birth',
                                  hint: 'Pick date',
                                  suffixIcon: const Icon(Icons.date_range),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Date of birth is required'
                                      : null,
                                ),
                              ),
                            ),
                            _Input(
                              controller: _clientAgeController,
                              label: 'Age',
                              hint: 'Auto-calculated',
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _dropdown(
                            label: 'Sex',
                            value: _sex,
                            options: sexOptions,
                            requiredField: true,
                            onChanged: (v) {
                              setState(() {
                                _sex = v ?? '';
                                _removeHiddenReasonOptions();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _dropdown(
                            label: 'Nationality',
                            value: _nationality,
                            options: nationalityOptions,
                            requiredField: true,
                            onChanged: (v) =>
                                setState(() => _nationality = v ?? ''),
                          ),
                          const SizedBox(height: 10),
                          _dropdown(
                            label: 'Home Language',
                            value: _homeLanguage,
                            options: homeLanguageOptions,
                            requiredField: true,
                            onChanged: (v) {
                              setState(() {
                                _homeLanguage = v ?? '';
                                if (_homeLanguage != 'OTHER') {
                                  _homeLanguageOtherController.text = '';
                                }
                              });
                            },
                          ),
                          if (_homeLanguage == 'OTHER') ...[
                            const SizedBox(height: 10),
                            _Input(
                              controller: _homeLanguageOtherController,
                              label: 'Specify other language',
                              hint: 'Enter language',
                            ),
                          ],
                          const SizedBox(height: 10),
                          _row2(
                            _Input(
                              controller: _phoneController,
                              label: 'Phone Number',
                              hint: 'e.g. 5xxxxxxx',
                              keyboardType: TextInputType.phone,
                            ),
                            _Input(
                              controller: _alternativePhoneController,
                              label: 'Alternative Phone Number',
                              hint: 'e.g. 5xxxxxxx',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MaterialCard(
                    body: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _titleRow(
                            color: primary,
                            title: 'Education',
                            subtitle:
                            'Capture school enrolment and attendance information.',
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: 12),
                          _dropdown(
                            label: 'Is the client in School?',
                            value: _isClientInSchool,
                            options: yesNoOptions,
                            requiredField: true,
                            onChanged: (v) {
                              setState(() {
                                _isClientInSchool = v ?? '';
                                _schoolAttendanceStatus = '';
                                if (_isClientInSchool != 'YES') {
                                  _schoolNameController.clear();
                                  _grade = '';
                                }
                              });
                            },
                          ),
                          if (_isClientInSchool == 'YES') ...[
                            const SizedBox(height: 10),
                            _Input(
                              controller: _schoolNameController,
                              label: 'Name of School',
                              hint: 'Enter school name',
                            ),
                            if (!_isAdultOrElderly) ...[
                              const SizedBox(height: 10),
                              _dropdown(
                                label: 'Grade',
                                value: _grade,
                                options: gradeOptions,
                                requiredField: true,
                                onChanged: (v) =>
                                    setState(() => _grade = v ?? ''),
                              ),
                            ],
                            const SizedBox(height: 10),
                            _dropdown(
                              label: 'School attendance Status',
                              value: _schoolAttendanceStatus,
                              options: inSchoolAttendanceOptions,
                              requiredField: true,
                              onChanged: (v) => setState(
                                      () => _schoolAttendanceStatus = v ?? ''),
                            ),
                          ],
                          if (_isClientInSchool == 'NO') ...[
                            const SizedBox(height: 10),
                            _dropdown(
                              label: 'School attendance Status',
                              value: _schoolAttendanceStatus,
                              options: notInSchoolAttendanceOptions,
                              requiredField: true,
                              onChanged: (v) => setState(
                                      () => _schoolAttendanceStatus = v ?? ''),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_isAdultOrElderly) ...[
                    const SizedBox(height: 12),
                    MaterialCard(
                      body: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _titleRow(
                              color: primary,
                              title: 'Employment Information',
                              subtitle:
                              'Capture employment details for adult or elderly clients.',
                              icon: Icons.work_outline,
                            ),
                            const SizedBox(height: 12),
                            _dropdown(
                              label: 'Is the adult employed?',
                              value: _isAdultEmployed,
                              options: yesNoOptions,
                              requiredField: true,
                              onChanged: (v) {
                                setState(() {
                                  _isAdultEmployed = v ?? '';
                                  if (_isAdultEmployed != 'YES') {
                                    _employerNameController.clear();
                                  }
                                });
                              },
                            ),
                            if (_isAdultEmployed == 'YES') ...[
                              const SizedBox(height: 10),
                              _Input(
                                controller: _employerNameController,
                                label: 'Name of Employer',
                                hint: 'Enter employer name',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  MaterialCard(
                    body: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _titleRow(
                            color: primary,
                            title: 'Details of Next of Kin or Significant Other',
                            subtitle:
                            'Capture the main contact person linked to the client.',
                            icon: Icons.contact_phone_outlined,
                          ),
                          const SizedBox(height: 12),
                          _row2(
                            _Input(
                              controller: _nextOfKinFirstNameController,
                              label: 'First name',
                              hint: 'Next of kin first name',
                            ),
                            _Input(
                              controller: _nextOfKinSurnameController,
                              label: 'Surname',
                              hint: 'Next of kin surname',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _Input(
                            controller: _nextOfKinPhoneController,
                            label: 'Phone Number',
                            hint: 'e.g. 5xxxxxxx',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          _Input(
                            controller: _nextOfKinPhysicalAddressController,
                            label: 'Physical Address',
                            hint: 'Describe physical address',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          _dropdown(
                            label: 'Relationship to Client',
                            value: _nextOfKinRelationship,
                            options: _nextOfKinRelationshipOptions(),
                            requiredField: true,
                            onChanged: (v) {
                              setState(() {
                                _nextOfKinRelationship = v ?? '';
                                if (_nextOfKinRelationship != 'OTHER') {
                                  _nextOfKinRelationshipOtherController.clear();
                                }
                              });
                            },
                          ),
                          if (_nextOfKinRelationshipIsOther) ...[
                            const SizedBox(height: 10),
                            _Input(
                              controller:
                              _nextOfKinRelationshipOtherController,
                              label: 'Specify other relationship',
                              hint: 'Enter relationship',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFamilyInformationSection(primary),
                  const SizedBox(height: 12),
                  _buildOtherHouseholdMembersSection(primary),
                  const SizedBox(height: 12),
                  _buildReasonSection(primary),
                  const SizedBox(height: 12),
                  _buildEmergencyActionSection(primary),
                  const SizedBox(height: 12),
                  _buildInitialRiskAssessmentSection(primary),
                  const SizedBox(height: 16),
                  EntryFormSaveButton(
                    marginLeft: 20.0,
                    marginRight: 20.0,
                    label: _saving ? 'Saving...' : 'Save Intake and Initial Risk Assessment',
                    svgIconPath: 'assets/icons/save-icon.svg',
                    svgIconHeight: 16.0,
                    svgIconWidth: 16.0,
                    labelColor: Colors.white,
                    buttonColor: primary,
                    fontSize: 15.0,
                    onPressButton: _saving ? () {} : _saveCase,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.suffixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.keyboardType,
  }) : super(key: key);

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final int maxLines;
  final bool readOnly;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF3F5F7) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
