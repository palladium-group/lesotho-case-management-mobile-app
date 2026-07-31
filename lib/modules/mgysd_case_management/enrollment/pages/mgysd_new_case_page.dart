
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/helpers/mgysd_program_stage_event_helper.dart';
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
    this.existingHouseholdTei,
    this.existingAssessedEnrollment,
  }) : super(key: key);

  final Color color;
  final String? reportedEventId;
  final String? prefillClientFirstName;
  final String? prefillClientLastName;
  final String? prefillClientPhone;
  final String? prefillCaseType;
  final String? prefillIncidentDate;
  final String? existingHouseholdTei;
  final String? existingAssessedEnrollment;

  bool get isEditing =>
      (existingHouseholdTei ?? '').trim().isNotEmpty &&
          (existingAssessedEnrollment ?? '').trim().isNotEmpty;

  @override
  State<MgysdNewCasePage> createState() => _MgysdNewCasePageState();
}

class _Opt {
  final String code;
  final String label;

  const _Opt(this.code, this.label);
}

class _MgysdCountryCodeOption {
  final String code;
  final String label;
  final String dialCode;
  final int minNationalDigits;
  final int maxNationalDigits;
  final List<String> allowedNationalPrefixes;
  final List<String> disallowedNationalPrefixes;
  final String prefixHint;
  final bool useNanpRules;

  const _MgysdCountryCodeOption({
    required this.code,
    required this.label,
    required this.dialCode,
    this.minNationalDigits = 7,
    this.maxNationalDigits = 12,
    this.allowedNationalPrefixes = const [],
    this.disallowedNationalPrefixes = const [],
    this.prefixHint = '',
    this.useNanpRules = false,
  });
}

class _MgysdPhoneNumberInputFormatter extends TextInputFormatter {
  final _MgysdCountryCodeOption country;

  const _MgysdPhoneNumberInputFormatter(this.country);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final formatted = country.code == 'INTL'
        ? _formatInternationalNumber(newValue.text)
        : _formatNationalNumber(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }

  String _formatInternationalNumber(String value) {
    final trimmed = value.trim();
    final hasLeadingPlus = trimmed.startsWith('+');
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final limitedDigits = digits.length > country.maxNationalDigits
        ? digits.substring(0, country.maxNationalDigits)
        : digits;

    if (limitedDigits.isEmpty) {
      return hasLeadingPlus ? '+' : '';
    }

    return hasLeadingPlus ? '+$limitedDigits' : limitedDigits;
  }

  String _formatNationalNumber(String value) {
    final dialDigits = country.dialCode.replaceAll('+', '');
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith(dialDigits) && digits.length > dialDigits.length) {
      digits = digits.substring(dialDigits.length);
    }

    if (digits.startsWith('0')) {
      final withoutLeadingZeros = digits.replaceFirst(RegExp(r'^0+'), '');
      if (withoutLeadingZeros.isNotEmpty) {
        digits = withoutLeadingZeros;
      }
    }

    if (digits.length > country.maxNationalDigits) {
      digits = digits.substring(0, country.maxNationalDigits);
    }

    return digits;
  }
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
  String phoneCountryCode;

  _DynamicTextItem({
    required this.id,
    String value = '',
    this.phoneCountryCode = 'LS',
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
  final TextEditingController relationshipOtherController;

  String sex;
  String relationshipToClient;
  String hasDisability;
  String contactsCountryCode;
  bool isExpanded;

  _HouseholdMemberEntry({
    required this.id,
    this.sex = '',
    this.relationshipToClient = '',
    this.hasDisability = '',
    this.contactsCountryCode = 'LS',
    this.isExpanded = true,
  })  : firstNameController = TextEditingController(),
        surnameController = TextEditingController(),
        dobController = TextEditingController(),
        ageController = TextEditingController(),
        occupationController = TextEditingController(),
        contactsController = TextEditingController(),
        disabilitySpecifyController = TextEditingController(),
        relationshipOtherController = TextEditingController();





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
    relationshipOtherController.dispose();
  }
}

class _CaregiverEntry {
  final String id;
  final TextEditingController nameController;
  final TextEditingController surnameController;
  final TextEditingController relationshipController;
  final TextEditingController dobController;
  final TextEditingController occupationController;
  final TextEditingController phoneController;

  String sex;
  String phoneCountryCode;
  bool isExpanded;

  _CaregiverEntry({
    required this.id,
    this.sex = '',
    this.phoneCountryCode = 'LS',
    this.isExpanded = true,
  })  : nameController = TextEditingController(),
        surnameController = TextEditingController(),
        relationshipController = TextEditingController(),
        dobController = TextEditingController(),
        occupationController = TextEditingController(),
        phoneController = TextEditingController();

  bool get hasAnyData {
    return nameController.text.trim().isNotEmpty ||
        surnameController.text.trim().isNotEmpty ||
        relationshipController.text.trim().isNotEmpty ||
        dobController.text.trim().isNotEmpty ||
        occupationController.text.trim().isNotEmpty ||
        phoneController.text.trim().isNotEmpty ||
        sex.trim().isNotEmpty;
  }

  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    relationshipController.dispose();
    dobController.dispose();
    occupationController.dispose();
    phoneController.dispose();
  }
}

class _NextOfKinEntry {
  final String id;
  final TextEditingController firstNameController;
  final TextEditingController surnameController;
  final TextEditingController phoneController;
  final TextEditingController physicalAddressController;
  final TextEditingController relationshipOtherController;

  String relationship;
  String phoneCountryCode;
  bool isExpanded;


  _NextOfKinEntry({
    required this.id,
    this.relationship = '',
    this.phoneCountryCode = 'LS',
    this.isExpanded = true,
  })  : firstNameController = TextEditingController(),
        surnameController = TextEditingController(),
        phoneController = TextEditingController(),
        physicalAddressController = TextEditingController(),
        relationshipOtherController = TextEditingController();

  bool get hasAnyData {
    return firstNameController.text.trim().isNotEmpty ||
        surnameController.text.trim().isNotEmpty ||
        phoneController.text.trim().isNotEmpty ||
        physicalAddressController.text.trim().isNotEmpty ||
        relationship.trim().isNotEmpty;
  }

  void dispose() {
    firstNameController.dispose();
    surnameController.dispose();
    phoneController.dispose();
    physicalAddressController.dispose();
    relationshipOtherController.dispose();
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
  final _nationalityOtherController = TextEditingController();

  final _schoolNameController = TextEditingController();
  final _employerNameController = TextEditingController();


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


  final _personalAssistantNameController = TextEditingController();
  final _personalAssistantSurnameController = TextEditingController();
  final _personalAssistantRelationshipController = TextEditingController();
  final _personalAssistantDobController = TextEditingController();
  final _personalAssistantOccupationController = TextEditingController();
  final _personalAssistantPhoneController = TextEditingController();

  final _reasonOtherController = TextEditingController();


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
  bool _loadingExistingCase = false;
  bool _countryPickerBusy = false;

  String _clientPhoneCountryCode = 'LS';
  String _clientAlternativePhoneCountryCode = 'LS';
  String _fatherPhoneCountryCode = 'LS';
  String _motherPhoneCountryCode = 'LS';
  String _personalAssistantPhoneCountryCode = 'LS';

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
  String _schoolLevel = '';
  String _schoolAttendanceStatus = '';
  String _notInSchoolStatus = '';
  String _highestLevelAchieved = '';
  String _isAdultEmployed = '';

  String _fatherAlive = '';
  String _fatherLivingWithChild = '';
  String _motherAlive = '';
  String _motherLivingWithChild = '';

  String _personalAssistantSex = '';


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


  String _selfCareIndependent = '';
  String _hasDisabilityDiagnosis = '';
  String _usesAssistiveDevice = '';
  String _receivesRehabilitationServices = '';

  final Set<String> _selfCareDomainsNeeded = {};
  final Set<String> _disabilityTypes = {};
  final Set<String> _assistiveDevices = {};
  final Set<String> _rehabilitationServices = {};
  final Set<String> _employabilityBarriers = {};

  final _selfCareOtherController = TextEditingController();
  final _disabilityTypeOtherController = TextEditingController();
  final _assistiveDeviceOtherController = TextEditingController();
  final _rehabilitationServiceOtherController = TextEditingController();
  final _employabilityBarrierOtherController = TextEditingController();
  final Set<String> _skillsDevelopmentAreas = {};
  final _skillsDevelopmentOtherController = TextEditingController();
  final _riskEmergencyActionOtherController = TextEditingController();
  final _riskServicesAccessedOtherController = TextEditingController();

  final Set<String> _selectedReasonOptions = {};
  final List<_DynamicTextItem> _contactedPhoneNumbers = [];
  final List<_DynamicTextItem> _servicesAlreadyProvided = [];
  final Set<String> _riskEmergencyActionsTaken = {};
  final Set<String> _riskServicesAccessed = {};
  final Set<String> _riskNextSteps = {};
  final List<_HouseholdMemberEntry> _otherHouseholdMembers = [];
  final List<_CaregiverEntry> _caregivers = [];
  final List<_NextOfKinEntry> _nextOfKins = [];

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
  static const String attNationalityOther = MgysdDhis2Uids.attNationalityOther;
  static const String attOccupation = MgysdDhis2Uids.attOccupation;
  static const String attRelationshipToClient = MgysdDhis2Uids.attRelationshipToClient;
  static const String attRelationshipToClientOther = MgysdDhis2Uids.attRelationshipToClientOther;
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
    _Opt('Child', 'Child'),
    _Opt('Adult', 'Adult / Elderly Person'),
  ];

  static const List<_Opt> yesNoOptions = [
    _Opt('Yes', 'Yes'),
    _Opt('No', 'No'),
  ];

  static const List<_Opt> yesNoUnknownOptions = [
    _Opt('Yes', 'Yes'),
    _Opt('No', 'No'),
    _Opt('Unknown', 'Unknown'),
  ];

  static const List<_Opt> sexOptions = [
    _Opt('Male', 'Male'),
    _Opt('Female', 'Female'),
  ];

  static const List<_MgysdCountryCodeOption> _phoneCountryOptions = [
    _MgysdCountryCodeOption(
      code: 'LS',
      label: 'Lesotho (+266)',
      dialCode: '+266',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['2', '5', '6'],
      disallowedNationalPrefixes: ['54', '55'],
      prefixHint: 'Lesotho numbers must start with 2, 5 or 6. Prefixes 54 and 55 are not allowed',
    ),
    _MgysdCountryCodeOption(
      code: 'ZA',
      label: 'South Africa (+27)',
      dialCode: '+27',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: [
        '60', '61', '62', '63', '64', '65', '66', '67', '68',
        '71', '72', '73', '74', '76', '78', '79', '81', '82', '83', '84',
      ],
      prefixHint: 'South African mobile numbers usually start with 6, 7 or 8 ranges such as 60, 71 or 82',
    ),
    _MgysdCountryCodeOption(
      code: 'ZW',
      label: 'Zimbabwe (+263)',
      dialCode: '+263',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['71', '73', '77', '78'],
      prefixHint: 'Zimbabwe mobile numbers must start with 71, 73, 77 or 78',
    ),
    _MgysdCountryCodeOption(
      code: 'MZ',
      label: 'Mozambique (+258)',
      dialCode: '+258',
      minNationalDigits: 8,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['82', '83', '84', '85', '86', '87'],
      prefixHint: 'Mozambique mobile numbers must start with 82, 83, 84, 85, 86 or 87',
    ),
    _MgysdCountryCodeOption(
      code: 'BW',
      label: 'Botswana (+267)',
      dialCode: '+267',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['71', '72', '73', '74', '75', '76'],
      prefixHint: 'Botswana mobile numbers must start with 71, 72, 73, 74, 75 or 76',
    ),
    _MgysdCountryCodeOption(
      code: 'NA',
      label: 'Namibia (+264)',
      dialCode: '+264',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['81', '82', '83', '84', '85'],
      prefixHint: 'Namibia mobile/electronic communications numbers must start with 81, 82, 83, 84 or 85',
    ),
    _MgysdCountryCodeOption(
      code: 'SZ',
      label: 'Eswatini (+268)',
      dialCode: '+268',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['75', '76', '77', '78', '79'],
      prefixHint: 'Eswatini mobile numbers must start with 75, 76, 77, 78 or 79',
    ),
    _MgysdCountryCodeOption(
      code: 'ZM',
      label: 'Zambia (+260)',
      dialCode: '+260',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['76', '77', '95', '96', '97'],
      prefixHint: 'Zambia mobile numbers must start with 76, 77, 95, 96 or 97',
    ),
    _MgysdCountryCodeOption(
      code: 'MW',
      label: 'Malawi (+265)',
      dialCode: '+265',
      minNationalDigits: 7,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['1', '3', '7', '8', '9'],
      prefixHint: 'Malawi numbers must start with an allocated range such as 1, 3, 7, 8 or 9',
    ),
    _MgysdCountryCodeOption(
      code: 'US',
      label: 'USA/Canada (+1)',
      dialCode: '+1',
      minNationalDigits: 10,
      maxNationalDigits: 10,
      useNanpRules: true,
      prefixHint: 'USA/Canada numbers must follow NANP format: area code and exchange code start with 2-9',
    ),
    _MgysdCountryCodeOption(
      code: 'GB',
      label: 'United Kingdom (+44)',
      dialCode: '+44',
      minNationalDigits: 10,
      maxNationalDigits: 10,
      allowedNationalPrefixes: ['7'],
      prefixHint: 'UK mobile numbers must start with 7 after the +44 country code',
    ),
    _MgysdCountryCodeOption(
      code: 'INTL',
      label: 'Other country (use + code)',
      dialCode: '+',
      minNationalDigits: 8,
      maxNationalDigits: 15,
    ),
  ];

  static const List<_Opt> nationalityOptions = [
    _Opt('Mosotho', 'Mosotho'),
    _Opt('South African', 'South African'),
    _Opt('Zimbabwean', 'Zimbabwean'),
    _Opt('Other', 'Other'),
  ];

  static const List<_Opt> homeLanguageOptions = [
    _Opt('Sesotho', 'Sesotho'),
    _Opt('English', 'English'),
    _Opt('Xhosa', 'Xhosa'),
    _Opt('Other', 'Other'),
  ];

  static const List<_Opt> gradeOptions = [
    _Opt('PRE_SCHOOL','Pre-School'),
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

  static const List<_Opt> schoolLevelOptions = [
    _Opt('Pre-School', 'Pre-School'),
    _Opt('Primary', 'Primary'),
    _Opt('Secondary', 'Secondary'),
    _Opt('High School', 'High School'),
    _Opt('Tertiary', 'Tertiary'),
  ];

  static const List<_Opt> primaryGradeOptions = [
    _Opt('1', 'Grade 1'),
    _Opt('2', 'Grade 2'),
    _Opt('3', 'Grade 3'),
    _Opt('4', 'Grade 4'),
    _Opt('5', 'Grade 5'),
    _Opt('6', 'Grade 6'),
    _Opt('7', 'Grade 7'),
  ];

  static const List<_Opt> secondaryGradeOptions = [
    _Opt('8', 'Grade 8'),
    _Opt('9', 'Grade 9'),
    _Opt('10', 'Grade 10'),
  ];

  static const List<_Opt> highSchoolGradeOptions = [
    _Opt('11', 'Grade 11'),
    _Opt('12', 'Grade 12'),
  ];

  static const List<_Opt> notInSchoolStatusOptions = [
    _Opt('Never attended school', 'Never attended school'),
    _Opt('No longer in school', 'No longer in school'),
  ];

  static const List<_Opt> highestLevelAchievedOptions = [
    _Opt('Primary', 'Primary'),
    _Opt('Secondary', 'Secondary'),
    _Opt('High School', 'High School'),
    _Opt('Tertiary', 'Tertiary'),
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
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> riskServicesAccessedOptions = [
    _Opt('HEALTH_SERVICES', 'Health services'),
    _Opt('POLICE_SERVICES', 'Police services'),
    _Opt('PSYCHOSOCIAL_SUPPORT', 'Psychosocial support'),
    _Opt('SHELTER_PLACE_OF_SAFETY', 'Shelter / place of safety'),
    _Opt('TRANSPORT_ASSISTANCE', 'Transport assistance'),
    _Opt('FOOD_ASSISTANCE', 'Food assistance'),
    _Opt('LEGAL_SUPPORT', 'Legal support'),
    _Opt('OTHER', 'Other'),
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
    _Opt('NO RISK', 'No Risk'),
    _Opt('LOW RISK', 'Low Risk'),
    _Opt('MEDIUM RISK', 'Medium Risk'),
    _Opt('HIGH RISK', 'High Risk'),
  ];

  static const List<_Opt> selfCareDomains = [
    _Opt('GROOMING', 'Grooming'),
    _Opt('DRESSING', 'Dressing'),
    _Opt('FEEDING', 'Feeding'),
    _Opt('BATHING', 'Bathing'),
    _Opt('TOILETING', 'Toileting'),
    _Opt('LAUNDRY', 'Laundry'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> disabilityTypeOptions = [
    _Opt('HEARING_LOSS', 'Hearing loss'),
    _Opt('BLINDNESS', 'Blindness'),
    _Opt('SPEECH_IMPAIRMENT', 'Speech impairment'),
    _Opt('MOBILITY_IMPAIRMENT', 'Mobility impairment'),
    _Opt('VISUAL_IMPAIRMENT', 'Visual impairment'),
    _Opt('ALBINISM', 'Albinism'),
    _Opt('DEAF', 'Deaf'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> assistiveDeviceOptions = [
    _Opt('WHEELCHAIR', 'Wheelchair'),
    _Opt('HEARING_AID', 'Hearing aid'),
    _Opt('SPECTACLES', 'Spectacles'),
    _Opt('CRUTCHES', 'Crutches'),
    _Opt('WHITE_CANE', 'White cane'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> rehabilitationServiceOptions = [
    _Opt('PHYSIOTHERAPY', 'Physiotherapy'),
    _Opt('COUNSELLING', 'Counselling'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> employabilityBarrierOptions = [
    _Opt('LACK_OF_SKILLS_TRAINING', 'Lack of skills / training'),
    _Opt('DISABILITY', 'Disability'),
    _Opt('SUBSTANCE_ABUSE', 'Substance abuse'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_Opt> skillsDevelopmentOptions = [
    _Opt('ECONOMICAL', 'Economical'),
    _Opt('POLITICAL', 'Political'),
    _Opt('SOCIAL', 'Social'),
    _Opt('COMMUNITY', 'Community'),
    _Opt('OTHER', 'Other'),
  ];

  static const List<_ReasonGroup> groupedReasons = [
    _ReasonGroup(
      code: 'ABUSE',
      title: 'Abuse',
      options: [
        _Opt('ABUSE_PHYSICAL', 'Physical abuse'),
        _Opt('ABUSE_EMOTIONAL', 'Emotional abuse'),
        _Opt('ABUSE_SEXUAL', 'Sexual abuse'),
        _Opt('ABUSE_INCEST', 'Incest'),
        _Opt('DOMESTIC_VIOLENCE', 'Domestic violence'),
        _Opt('HUMAN_TRAFFICKING', 'Human trafficking / Trafficking in Persons'),
      ],
    ),
    _ReasonGroup(
      code: 'CARE_OR_PROTECTION',
      title: 'In need of care or protection',
      options: [
        _Opt('CARE_NEGLECT', 'Neglect'),
        _Opt('CARE_ABANDONMENT', 'Abandonment'),
        _Opt('CARE_ORPHANS', 'Orphans'),
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

  bool get _isAdultOrElderly => _clientCategory == 'Adult';
  bool get _isChild => _clientCategory == 'Child';
  bool get _isDisabledYes => _isDisabled == 'Yes';
  bool get _showGuardianOption => _isDisabledYes;
  bool get _disabilityAutoDetected =>
      _usesAssistiveDevice == 'Yes' || _hasDisabilityDiagnosis == 'Yes';

  void _syncDisabilityStatus() {
    final diagnosis = _hasDisabilityDiagnosis.trim();
    final device = _usesAssistiveDevice.trim();

    if (diagnosis == 'Yes' || device == 'Yes') {
      _isDisabled = 'Yes';
    } else if (diagnosis == 'No' && device == 'No') {
      _isDisabled = 'No';
    } else {
      _isDisabled = '';
    }

    if (!_showGuardianOption) {
      for (final nextOfKin in _nextOfKins) {
        if (nextOfKin.relationship == 'GUARDIAN') {
          nextOfKin.relationship = '';
        }
      }
    }
    if (!_isDisabledYes) {
      _personalAssistantNameController.clear();
      _personalAssistantSurnameController.clear();
      _personalAssistantSex = '';
      _personalAssistantRelationshipController.clear();
      _personalAssistantDobController.clear();
      _personalAssistantOccupationController.clear();
      _personalAssistantPhoneController.clear();
    }
  }
  bool get _reasonOtherSelected => _selectedReasonOptions.contains('OTHER');

  int? get _clientAge => int.tryParse(_clientAgeController.text.trim());


  Future<Map<String, String>> _loadAttributes(
      Database db,
      String teiId,
      ) async {
    final values = <String, String>{};
    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        where: 'trackedEntityInstance = ?',
        whereArgs: [teiId],
      );
      for (final row in rows) {
        final key = (row['attribute'] ?? '').toString();
        if (key.isEmpty) continue;
        values[key] = (row['value'] ?? '').toString();
      }
    } catch (_) {}
    return values;
  }

  Future<String> _loadPrimaryClientTei(
      Database db,
      String householdTei,
      ) async {
    try {
      final rows = await db.query(
        'mgysd_household_member',
        columns: ['memberTei'],
        where: 'householdTei = ? AND isPrimaryClient = ?',
        whereArgs: [householdTei, 1],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return (rows.first['memberTei'] ?? '').toString().trim();
      }
    } catch (_) {}
    return '';
  }

  void _setJsonSet(Set<String> target, String raw) {
    target.clear();
    if (raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        target.addAll(decoded.map((value) => value.toString()));
        return;
      }
    } catch (_) {}
    target.addAll(
      raw.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty),
    );
  }

  Future<void> _loadExistingCase() async {
    final householdTei = (widget.existingHouseholdTei ?? '').trim();
    if (householdTei.isEmpty) return;

    setState(() => _loadingExistingCase = true);
    try {
      final db = await _db();
      final household = await _loadAttributes(db, householdTei);
      final clientTei = await _loadPrimaryClientTei(db, householdTei);
      final client = clientTei.isEmpty
          ? <String, String>{}
          : await _loadAttributes(db, clientTei);

      _fileNumberController.text = household[attHouseholdFileNumber] ?? '';
      _districtController.text = household[attHouseholdDistrict] ?? '';
      _communityCouncilController.text =
          household[attHouseholdCommunityCouncil] ?? '';
      _villageController.text = household[attHouseholdVillage] ?? '';
      _physicalAddressController.text = household[attHouseholdAddress] ?? '';

      _selectedDistrictName = _districtController.text.trim();
      _selectedCommunityCouncilName = _communityCouncilController.text.trim();

      _reasonOtherController.text =
          household[attReasonForEnrolmentOther] ?? '';
      _setJsonSet(
        _selectedReasonOptions,
        household[attReasonForEnrolment] ?? '',
      );

      _clientFirstNameController.text = client[attFirstName] ?? '';
      _clientSurnameController.text = client[attLastName] ?? '';
      _clientDobController.text = client[attDob] ?? '';
      _clientAgeController.text = client[attAge] ?? '';
      _phoneController.text = client[attPhone] ?? '';
      _alternativePhoneController.text = client[attAlternativePhone] ?? '';
      _identityNumberController.text = client[attIdentityNumber] ?? '';
      _clientCategory = client[attClientCategory] ?? '';
      _isDisabled = client[attIsDisabled] ?? '';
      _sex = client[attSex] ?? '';
      _nationality = client[attNationality] ?? '';
      _homeLanguage = client[attHomeLanguage] ?? '';
      _isClientInSchool = client[attIsClientInSchool] ?? '';
      _grade = client[attGrade] ?? '';
      _schoolAttendanceStatus = client[attSchoolAttendanceStatus] ?? '';
      _isAdultEmployed = client[attIsAdultEmployed] ?? '';
      _schoolNameController.text = client[attSchoolName] ?? '';
      _employerNameController.text = client[attEmployerName] ?? '';

      _riskAssessmentDateController.text =
          household[attRiskAssessmentDate] ??
              client[attRiskAssessmentDate] ??
              '';
      _riskSocialWorkerController.text =
          household[attRiskAssessmentSocialWorker] ??
              client[attRiskAssessmentSocialWorker] ??
              '';
      _riskReportSource =
          household[attRiskAssessmentReportSource] ??
              client[attRiskAssessmentReportSource] ??
              '';
      _riskHasActionTaken =
          household[attRiskAssessmentHasActionTaken] ??
              client[attRiskAssessmentHasActionTaken] ??
              '';
      _riskNoActionReason =
          household[attRiskAssessmentNoActionReason] ??
              client[attRiskAssessmentNoActionReason] ??
              '';
      _riskFamilyBackground =
          household[attRiskFamilyBackground] ??
              client[attRiskFamilyBackground] ??
              '';
      _riskFamilyBackgroundNotesController.text =
          household[attRiskFamilyBackgroundNotes] ??
              client[attRiskFamilyBackgroundNotes] ??
              '';
      _riskCaregiverWellbeing =
          household[attRiskCaregiverWellbeing] ??
              client[attRiskCaregiverWellbeing] ??
              '';
      _riskCaregiverWellbeingNotesController.text =
          household[attRiskCaregiverWellbeingNotes] ??
              client[attRiskCaregiverWellbeingNotes] ??
              '';
      _riskExtendedFamilyRelationships =
          household[attRiskExtendedFamilyRelationships] ??
              client[attRiskExtendedFamilyRelationships] ??
              '';
      _riskExtendedFamilyNotesController.text =
          household[attRiskExtendedFamilyNotes] ??
              client[attRiskExtendedFamilyNotes] ??
              '';
      _riskClientRelationships =
          household[attRiskClientRelationships] ??
              client[attRiskClientRelationships] ??
              '';
      _riskClientRelationshipsNotesController.text =
          household[attRiskClientRelationshipsNotes] ??
              client[attRiskClientRelationshipsNotes] ??
              '';
      _riskLivingCircumstances =
          household[attRiskLivingCircumstances] ??
              client[attRiskLivingCircumstances] ??
              '';
      _riskLivingCircumstancesNotesController.text =
          household[attRiskLivingCircumstancesNotes] ??
              client[attRiskLivingCircumstancesNotes] ??
              '';
      _riskHousing =
          household[attRiskHousing] ?? client[attRiskHousing] ?? '';
      _riskHousingNotesController.text =
          household[attRiskHousingNotes] ??
              client[attRiskHousingNotes] ??
              '';
      _riskPhysicalHealth =
          household[attRiskPhysicalHealth] ??
              client[attRiskPhysicalHealth] ??
              '';
      _riskPhysicalHealthNotesController.text =
          household[attRiskPhysicalHealthNotes] ??
              client[attRiskPhysicalHealthNotes] ??
              '';
      _riskNutrition =
          household[attRiskNutrition] ?? client[attRiskNutrition] ?? '';
      _riskNutritionNotesController.text =
          household[attRiskNutritionNotes] ??
              client[attRiskNutritionNotes] ??
              '';
      _riskEmotionalHealth =
          household[attRiskEmotionalHealth] ??
              client[attRiskEmotionalHealth] ??
              '';
      _riskEmotionalHealthNotesController.text =
          household[attRiskEmotionalHealthNotes] ??
              client[attRiskEmotionalHealthNotes] ??
              '';
      _riskSupervision =
          household[attRiskSupervision] ??
              client[attRiskSupervision] ??
              '';
      _riskSupervisionNotesController.text =
          household[attRiskSupervisionNotes] ??
              client[attRiskSupervisionNotes] ??
              '';
      _riskEducation =
          household[attRiskEducation] ?? client[attRiskEducation] ?? '';
      _riskEducationNotesController.text =
          household[attRiskEducationNotes] ??
              client[attRiskEducationNotes] ??
              '';
      _riskLevel =
          household[attRiskLevel] ?? client[attRiskLevel] ?? '';
      _riskReasonController.text =
          household[attRiskReason] ?? client[attRiskReason] ?? '';
      _riskImmediateReferralsController.text =
          household[attRiskImmediateReferrals] ??
              client[attRiskImmediateReferrals] ??
              '';
      _riskAdditionalNotesController.text =
          household[attRiskAdditionalNotes] ??
              client[attRiskAdditionalNotes] ??
              '';

      _setJsonSet(
        _riskEmergencyActionsTaken,
        household[attRiskAssessmentEmergencyActionsTaken] ??
            client[attRiskAssessmentEmergencyActionsTaken] ??
            '',
      );
      _setJsonSet(
        _riskServicesAccessed,
        household[attRiskAssessmentServicesAccessed] ??
            client[attRiskAssessmentServicesAccessed] ??
            '',
      );
      _setJsonSet(
        _riskNextSteps,
        household[attRiskNextSteps] ?? client[attRiskNextSteps] ?? '',
      );

      if (mounted) setState(() {});
    } catch (e) {
      AppUtil.showToastMessage(
        message: 'Failed to load saved Intake: $e',
      );
    } finally {
      if (mounted) setState(() => _loadingExistingCase = false);
    }
  }

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
    _loadLocationTree();
    if (widget.isEditing) {
      _loadExistingCase();
    }
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
    _nationalityOtherController.dispose();
    _schoolNameController.dispose();
    _employerNameController.dispose();
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
    _personalAssistantNameController.dispose();
    _personalAssistantSurnameController.dispose();
    _personalAssistantRelationshipController.dispose();
    _personalAssistantDobController.dispose();
    _personalAssistantOccupationController.dispose();
    _personalAssistantPhoneController.dispose();
    _reasonOtherController.dispose();
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
    _selfCareOtherController.dispose();
    _disabilityTypeOtherController.dispose();
    _assistiveDeviceOtherController.dispose();
    _rehabilitationServiceOtherController.dispose();
    _employabilityBarrierOtherController.dispose();
    _skillsDevelopmentOtherController.dispose();
    _riskEmergencyActionOtherController.dispose();
    _riskServicesAccessedOtherController.dispose();

    for (final item in _contactedPhoneNumbers) {
      item.dispose();
    }
    for (final item in _servicesAlreadyProvided) {
      item.dispose();
    }
    for (final item in _otherHouseholdMembers) {
      item.dispose();
    }
    for (final item in _caregivers) {
      item.dispose();
    }

    for (final item in _nextOfKins) {
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

  _MgysdCountryCodeOption _phoneCountryByCode(String code) {
    for (final option in _phoneCountryOptions) {
      if (option.code == code) return option;
    }
    return _phoneCountryOptions.first;
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _hasInvalidPhoneCharacters(String value) {
    return RegExp(r'[^0-9+\s\-\(\)]').hasMatch(value);
  }

  bool _hasValidNationalLength(
      String nationalDigits,
      _MgysdCountryCodeOption country,
      ) {
    return nationalDigits.length >= country.minNationalDigits &&
        nationalDigits.length <= country.maxNationalDigits;
  }

  bool _hasDisallowedNationalPrefix(
      String nationalDigits,
      _MgysdCountryCodeOption country,
      ) {
    if (country.code == 'INTL' || nationalDigits.isEmpty) return false;
    return country.disallowedNationalPrefixes.any(nationalDigits.startsWith);
  }

  bool _hasPossibleNetworkPrefix(
      String nationalDigits,
      _MgysdCountryCodeOption country,
      ) {
    if (country.code == 'INTL' || nationalDigits.isEmpty) return true;

    if (_hasDisallowedNationalPrefix(nationalDigits, country)) return false;

    if (country.useNanpRules) {
      if (nationalDigits.isNotEmpty &&
          !RegExp(r'^[2-9]').hasMatch(nationalDigits)) {
        return false;
      }
      if (nationalDigits.length >= 4 &&
          !RegExp(r'^[2-9][0-9]{2}[2-9]').hasMatch(nationalDigits)) {
        return false;
      }
      return true;
    }

    if (country.allowedNationalPrefixes.isEmpty) return true;

    return country.allowedNationalPrefixes.any((prefix) {
      return prefix.startsWith(nationalDigits) ||
          nationalDigits.startsWith(prefix);
    });
  }

  bool _hasValidNetworkPrefix(
      String nationalDigits,
      _MgysdCountryCodeOption country,
      ) {
    if (country.code == 'INTL') return true;

    if (_hasDisallowedNationalPrefix(nationalDigits, country)) return false;

    if (country.useNanpRules) {
      return RegExp(r'^[2-9][0-9]{2}[2-9][0-9]{6}$')
          .hasMatch(nationalDigits);
    }

    if (country.allowedNationalPrefixes.isEmpty) return true;

    return country.allowedNationalPrefixes.any(nationalDigits.startsWith);
  }

  String _phonePrefixMessage(_MgysdCountryCodeOption country) {
    return country.prefixHint.isNotEmpty
        ? country.prefixHint
        : 'Phone number prefix does not match selected country';
  }

  String _phoneLengthMessage(_MgysdCountryCodeOption country) {
    if (country.minNationalDigits == country.maxNationalDigits) {
      return '${country.label} numbers must have ${country.maxNationalDigits} digits after ${country.dialCode}';
    }

    return '${country.label} numbers must have ${country.minNationalDigits} to ${country.maxNationalDigits} digits after ${country.dialCode}';
  }

  void _validateNationalPhoneDigits(
      String nationalDigits,
      _MgysdCountryCodeOption country,
      ) {
    if (!_hasPossibleNetworkPrefix(nationalDigits, country)) {
      throw FormatException(_phonePrefixMessage(country));
    }

    if (!_hasValidNationalLength(nationalDigits, country)) {
      throw FormatException(_phoneLengthMessage(country));
    }

    if (!_hasValidNetworkPrefix(nationalDigits, country)) {
      throw FormatException(_phonePrefixMessage(country));
    }
  }

  String _normalisePhoneByCountryCode(String value, String countryCode) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final country = _phoneCountryByCode(countryCode);
    final compact = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final digits = _digitsOnly(compact);

    if (digits.isEmpty) {
      throw const FormatException('Phone number must contain digits');
    }

    if (country.code == 'INTL') {
      if (!compact.startsWith('+')) {
        throw const FormatException('International numbers must start with +');
      }
      if (digits.length < 8 || digits.length > 15) {
        throw const FormatException('International numbers must have 8 to 15 digits');
      }
      return '+$digits';
    }

    final dialDigits = country.dialCode.replaceAll('+', '');

    if (compact.startsWith('+')) {
      if (!digits.startsWith(dialDigits)) {
        throw const FormatException('Phone number country code does not match selected country');
      }
      final nationalDigits = digits.substring(dialDigits.length);
      _validateNationalPhoneDigits(nationalDigits, country);
      return '+$digits';
    }

    if (digits.startsWith(dialDigits)) {
      final nationalDigits = digits.substring(dialDigits.length);
      _validateNationalPhoneDigits(nationalDigits, country);
      return '+$digits';
    }

    final localDigits = digits.replaceFirst(RegExp(r'^0+'), '');
    _validateNationalPhoneDigits(localDigits, country);

    return '${country.dialCode}$localDigits';
  }

  String _normalisedPhoneNumber(String value, String countryCode) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    try {
      return _normalisePhoneByCountryCode(trimmed, countryCode);
    } catch (_) {
      return trimmed;
    }
  }

  String? _phoneValidator(
      String? value, {
        required bool requiredField,
        required String countryCode,
      }) {
    final text = (value ?? '').trim();
    if (!requiredField && text.isEmpty) return null;
    if (text.isEmpty) return 'Required';

    if (_hasInvalidPhoneCharacters(text)) {
      return 'Use numbers only';
    }

    final country = _phoneCountryByCode(countryCode);

    try {
      _normalisePhoneByCountryCode(text, countryCode);
      return null;
    } on FormatException catch (e) {
      if (country.code == 'INTL') {
        return e.message.isNotEmpty
            ? e.message
            : 'Start with + country code, e.g. +266...';
      }
      return e.message.isNotEmpty
          ? e.message
          : 'Enter a valid ${country.label} phone number';
    } catch (_) {
      if (country.code == 'INTL') {
        return 'Start with + country code, e.g. +266...';
      }
      return 'Enter a valid ${country.label} phone number';
    }
  }

  String? _identityNumberValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;

    final compact = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(compact)) {
      return 'Use letters and numbers only';
    }

    if (compact.length < 6 || compact.length > 20) {
      return 'Identity number must be 6 to 20 characters';
    }

    if (_nationality == 'South African' &&
        RegExp(r'^\d+$').hasMatch(compact) &&
        compact.length != 13) {
      return 'South African identity number must have 13 digits';
    }

    return null;
  }

  List<String> _normalisedDynamicPhoneValues(List<_DynamicTextItem> items) {
    return items
        .map((item) => _normalisedPhoneNumber(
      item.controller.text.trim(),
      item.phoneCountryCode,
    ))
        .where((value) => value.isNotEmpty)
        .toList();
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
      final age = _calculateAge(picked);
      setState(() {
        _selectedDob = picked;
        _clientDobController.text = _formatDate(picked);
        _clientAgeController.text = age.toString();
        _clientCategory = age < 18 ? 'Child' : 'Adult';
        if (!_isAdultOrElderly) {
          _isAdultEmployed = '';
          _employerNameController.clear();
        }
        if (_isAdultOrElderly) _grade = '';
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
      return _isChild && _sex == 'Female';
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
    });
  }

  void _addCaregiver() {
    setState(() {
      _caregivers.add(_CaregiverEntry(id: _newId()));
    });
  }

  void _removeCaregiver(int index) {
    setState(() {
      final item = _caregivers.removeAt(index);
      item.dispose();
    });
  }

  void _addNextOfKin() {
    setState(() {
      _nextOfKins.add(_NextOfKinEntry(id: _newId()));
    });
  }

  void _removeNextOfKin(int index) {
    setState(() {
      final item = _nextOfKins.removeAt(index);
      item.dispose();
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
    if (v.isEmpty || attribute.startsWith('ATTR_') || attribute.length != 11) return;
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mgysd_report_intake_link (
        id TEXT PRIMARY KEY,
        reportEvent TEXT,
        tei TEXT,
        enrollment TEXT,
        createdAt TEXT
      )
    ''');

    final tableInfo = await db.rawQuery(
      'PRAGMA table_info(mgysd_report_intake_link)',
    );
    final columns = tableInfo
        .map((row) => '${row['name'] ?? ''}')
        .where((name) => name.isNotEmpty)
        .toSet();

    Future<void> addColumn(String name) async {
      if (columns.contains(name)) return;
      await db.execute(
        'ALTER TABLE mgysd_report_intake_link ADD COLUMN $name TEXT',
      );
      columns.add(name);
    }

    for (final name in <String>[
      'reportEvent',
      'reportEventId',
      'tei',
      'teiId',
      'householdTei',
      'enrollment',
      'enrollmentId',
      'createdAt',
    ]) {
      await addColumn(name);
    }

    await db.delete(
      'mgysd_report_intake_link',
      where: 'reportEvent = ? OR reportEventId = ?',
      whereArgs: <Object?>[reportEventId, reportEventId],
    );

    await db.insert(
      'mgysd_report_intake_link',
      <String, Object?>{
        'id': _newId(),
        'reportEvent': reportEventId,
        'reportEventId': reportEventId,
        'tei': teiId,
        'teiId': teiId,
        'householdTei': teiId,
        'enrollment': enrollmentId,
        'enrollmentId': enrollmentId,
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

    if (_clientCategory.trim().isEmpty) {
      AppUtil.showToastMessage(
        message: 'Please enter the client\'s date of birth to determine client category.',
      );
      return;
    }

    if (_riskLevel.trim().isEmpty) {
      AppUtil.showToastMessage(
        message: 'Please select the initial risk level.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final db = await _db();

      final householdTeiId = widget.isEditing
          ? widget.existingHouseholdTei!.trim()
          : _newDhis2Uid();
      final assessedHouseholdEnrollmentId = widget.isEditing
          ? widget.existingAssessedEnrollment!.trim()
          : _newDhis2Uid();
      final existingPrimaryClientTei = widget.isEditing
          ? await _loadPrimaryClientTei(db, householdTeiId)
          : '';
      final clientTeiId = existingPrimaryClientTei.isNotEmpty
          ? existingPrimaryClientTei
          : _newDhis2Uid();

      // Intake always stops in the Assessed Households programme.
      // Risk level must never create Enrolled Household or member enrolments.
      const shouldEnrollForCaseManagement = false;
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
          attEmergencyContactedPhoneNumbers:
          jsonEncode(_normalisedDynamicPhoneValues(_contactedPhoneNumbers)),
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
        attNationalityOther: _nationalityOtherController.text,
        attPhone: _normalisedPhoneNumber(
          _phoneController.text,
          _clientPhoneCountryCode,
        ),
        attAlternativePhone: _normalisedPhoneNumber(
          _alternativePhoneController.text,
          _clientAlternativePhoneCountryCode,
        ),
        attIsClientInSchool: _isClientInSchool,
        attSchoolName: _schoolNameController.text,
        attGrade: _grade,
        attSchoolAttendanceStatus: _schoolAttendanceStatus,
        attIsAdultEmployed: _isAdultEmployed,
        attEmployerName: _employerNameController.text,
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
        attEmergencyContactedPhoneNumbers:
        jsonEncode(_normalisedDynamicPhoneValues(_contactedPhoneNumbers)),
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
        widget.reportedEventId == null
            ? ''
            : 'reportEvent:${widget.reportedEventId}',
      ].where((e) => e.isNotEmpty).join(' | ');

      await _saveEnrollmentOffline(
        db: db,
        enrollmentId: assessedHouseholdEnrollmentId,
        teiId: householdTeiId,
        programId: mgysdAssessedHouseholdsProgramId,
        orgUnit: orgUnit,
        searchableValue: householdSearchableValue,
      );

      // Initial Risk Assessment is a tracker EVENT, not a TEI attribute set.
      // Preserve one event per assessed-household enrollment and update it on edit.
      String initialRiskEventId = '';
      final existingRiskEvents = await db.query(
        'events',
        columns: ['event'],
        where: 'trackedEntityInstance = ? AND programStage = ?',
        whereArgs: [householdTeiId, MgysdDhis2Uids.initialRiskAssessmentStage],
        orderBy: 'eventDate DESC',
        limit: 1,
      );
      if (existingRiskEvents.isNotEmpty) {
        initialRiskEventId = (existingRiskEvents.first['event'] ?? '').toString();
      }
      if (initialRiskEventId.isEmpty) initialRiskEventId = _newDhis2Uid();

      await MgysdProgramStageEventHelper.saveProgramStageEvent(
        db: db,
        eventId: initialRiskEventId,
        status: 'COMPLETED',
        eventDate: _riskAssessmentDateController.text.trim().isEmpty
            ? DateTime.now().toIso8601String().substring(0, 10)
            : _riskAssessmentDateController.text.trim(),
        orgUnit: orgUnit,
        program: MgysdDhis2Uids.assessedHouseholdsProgram,
        programStage: MgysdDhis2Uids.initialRiskAssessmentStage,
        trackedEntityInstance: householdTeiId,
        enrollment: assessedHouseholdEnrollmentId,
        dataValues: {
          MgysdDhis2Uids.deRiskSocialWorker: _riskSocialWorkerController.text,
          MgysdDhis2Uids.deRiskFamilyBackground: _riskFamilyBackground,
          MgysdDhis2Uids.deRiskFamilyBackgroundNotes: _riskFamilyBackgroundNotesController.text,
          MgysdDhis2Uids.deRiskExtendedFamilyRelationships: _riskExtendedFamilyRelationships,
          MgysdDhis2Uids.deRiskExtendedFamilyNotes: _riskExtendedFamilyNotesController.text,
          MgysdDhis2Uids.deRiskClientRelationships: _riskClientRelationships,
          MgysdDhis2Uids.deRiskClientRelationshipsNotes: _riskClientRelationshipsNotesController.text,
          MgysdDhis2Uids.deRiskLivingCircumstances: _riskLivingCircumstances,
          MgysdDhis2Uids.deRiskLivingCircumstancesNotes: _riskLivingCircumstancesNotesController.text,
          MgysdDhis2Uids.deRiskHousing: _riskHousing,
          MgysdDhis2Uids.deRiskHousingNotes: _riskHousingNotesController.text,
          MgysdDhis2Uids.deRiskPhysicalHealth: _riskPhysicalHealth,
          MgysdDhis2Uids.deRiskPhysicalHealthNotes: _riskPhysicalHealthNotesController.text,
          MgysdDhis2Uids.deRiskNutrition: _riskNutrition,
          MgysdDhis2Uids.deRiskNutritionNotes: _riskNutritionNotesController.text,
          MgysdDhis2Uids.deRiskEmotionalHealth: _riskEmotionalHealth,
          MgysdDhis2Uids.deRiskEmotionalHealthNotes: _riskEmotionalHealthNotesController.text,
          MgysdDhis2Uids.deRiskSupervision: _riskSupervision,
          MgysdDhis2Uids.deRiskSupervisionNotes: _riskSupervisionNotesController.text,
          MgysdDhis2Uids.deRiskEducation: _riskEducation,
          MgysdDhis2Uids.deRiskEducationNotes: _riskEducationNotesController.text,
          MgysdDhis2Uids.deRiskLevel: _riskLevel,
          MgysdDhis2Uids.deRiskReason: _riskReasonController.text,
          MgysdDhis2Uids.deRiskImmediateReferrals: _riskImmediateReferralsController.text,
          MgysdDhis2Uids.deRiskSelfCare: _riskCaregiverWellbeing,
          MgysdDhis2Uids.deRiskDisabilityDiagnosis: _isDisabled,
          MgysdDhis2Uids.deRiskAssistiveDevices: _riskServicesAccessed.join(', '),
          MgysdDhis2Uids.deRiskRehabilitationServices: _riskEmergencyActionsTaken.join(', '),
        },
      );

      // Enforce the Intake boundary even when editing older records that were
      // incorrectly enrolled by previous versions.
      await db.delete(
        'enrollment',
        where: 'trackedEntityInstance = ? AND program = ?',
        whereArgs: [householdTeiId, mgysdEnrolledHouseholdsProgramId],
      );
      try {
        final linkedMembers = await db.query(
          'mgysd_household_member',
          columns: ['memberTei'],
          where: 'householdTei = ?',
          whereArgs: [householdTeiId],
        );
        for (final linkedMember in linkedMembers) {
          final memberTei =
          (linkedMember['memberTei'] ?? '').toString().trim();
          if (memberTei.isEmpty) continue;
          await db.delete(
            'enrollment',
            where: 'trackedEntityInstance = ? AND program = ?',
            whereArgs: [memberTei, mgysdFamilyMembersProgramId],
          );
        }
      } catch (_) {}

      if (widget.isEditing) {
        // Edit mode is update-only. The existing Household TEI, primary Client
        // TEI and Assessed Household enrollment have already been updated above.
        // Do not create relationships, household-member records or person TEIs.
        AppUtil.showToastMessage(
          message: 'Intake and Initial Risk Assessment updated.',
        );
        if (mounted) Navigator.pop(context, true);
        return;
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
          enrollInFamilyMembersProgram: false,
          attrs: {
            attFirstName: _fatherFirstNameController.text,
            attLastName: _fatherSurnameController.text,
            attDob: _fatherDobController.text,
            attOccupation: _fatherOccupationController.text,
            attPhone: _normalisedPhoneNumber(
              _fatherPhoneController.text,
              _fatherPhoneCountryCode,
            ),
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
          enrollInFamilyMembersProgram: false,
          attrs: {
            attFirstName: _motherFirstNameController.text,
            attLastName: _motherSurnameController.text,
            attDob: _motherDobController.text,
            attOccupation: _motherOccupationController.text,
            attPhone: _normalisedPhoneNumber(
              _motherPhoneController.text,
              _motherPhoneCountryCode,
            ),
            attSex: 'FEMALE',
            attRelationshipToClient: 'MOTHER',
            attMotherAlive: _motherAlive,
            attMotherLivingWithChild: _motherLivingWithChild,
            attMotherWhyNotLiving: _motherWhyNotLivingController.text,
          },
        );
      }

      for (final caregiver in _caregivers.where((c) => c.hasAnyData)) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: 'CAREGIVER',
          enrollInFamilyMembersProgram: false,
          attrs: {
            attFirstName: caregiver.nameController.text,
            attLastName: caregiver.surnameController.text,
            attSex: caregiver.sex,
            attRelationshipToClient: caregiver.relationshipController.text,
            attDob: caregiver.dobController.text,
            attOccupation: caregiver.occupationController.text,
            attPhone: _normalisedPhoneNumber(
              caregiver.phoneController.text,
              caregiver.phoneCountryCode,
            ),
          },
        );
      }

      for (final nextOfKin in _nextOfKins.where((n) => n.hasAnyData)) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: nextOfKin.relationship.isEmpty ? 'NEXT_OF_KIN' : nextOfKin.relationship,
          enrollInFamilyMembersProgram: false,
          attrs: {
            attFirstName: nextOfKin.firstNameController.text,
            attLastName: nextOfKin.surnameController.text,
            attPhone: _normalisedPhoneNumber(
              nextOfKin.phoneController.text,
              nextOfKin.phoneCountryCode,
            ),
            attRelationshipToClient: nextOfKin.relationship,
            attRelationshipToClientOther: nextOfKin.relationshipOtherController.text,
          },
        );
      }

      if (_personalAssistantHasData()) {
        await _savePersonAsFamilyMember(
          db: db,
          householdTeiId: householdTeiId,
          orgUnit: orgUnit,
          memberRole: 'PERSONAL_ASSISTANT',
          enrollInFamilyMembersProgram: false,
          attrs: {
            attFirstName: _personalAssistantNameController.text,
            attLastName: _personalAssistantSurnameController.text,
            attSex: _personalAssistantSex,
            attRelationshipToClient:
            _personalAssistantRelationshipController.text,
            attDob: _personalAssistantDobController.text,
            attOccupation: _personalAssistantOccupationController.text,
            attPhone: _normalisedPhoneNumber(
              _personalAssistantPhoneController.text,
              _personalAssistantPhoneCountryCode,
            ),
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
          enrollInFamilyMembersProgram: false,
          attrs: {
            attFirstName: member.firstNameController.text,
            attLastName: member.surnameController.text,
            attDob: member.dobController.text,
            attAge: member.ageController.text,
            attSex: member.sex,
            attRelationshipToClient: member.relationshipToClient,
            attRelationshipToClientOther: member.relationshipOtherController.text,
            attOccupation: member.occupationController.text,
            attPhone: _normalisedPhoneNumber(
              member.contactsController.text,
              member.contactsCountryCode,
            ),
            attHasDisability: member.hasDisability,
            attDisabilitySpecify: member.disabilitySpecifyController.text,
          },
        );
      }

      AppUtil.showToastMessage(
        message: widget.isEditing
            ? 'Intake and Initial Risk Assessment updated.'
            : 'Household saved in MGYSD Assessed Households.',
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      AppUtil.showToastMessage(message: 'Failed to save case: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _collapsibleCardHeader({
    required String title,
    required String summary,
    required bool isExpanded,
    required VoidCallback onToggle,
    required VoidCallback onDelete,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onToggle,
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    summary.trim().isEmpty ? title : summary,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          color: Colors.redAccent,
        ),
      ],
    );
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
    bool enabled = true,
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
      onChanged: enabled ? onChanged : null,
      validator: (v) {
        if (!requiredField) return null;
        if ((v ?? '').trim().isEmpty) return 'Required';
        return null;
      },
      decoration: InputDecoration(
        label: requiredField
            ? RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: label),
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        )
            : null,
        labelText: requiredField ? null : label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey),
        filled: true,
        fillColor: enabled ? const Color(0xFFF3F7FA) : const Color(0xFFF1F5F9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.18)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.65)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    bool requiredField = false,
  }) {
    return GestureDetector(
      onTap: () => _pickDateFor(controller),
      child: AbsorbPointer(
        child: _Input(
          controller: controller,
          label: label,
          hint: hint,
          suffixIcon: const Icon(Icons.date_range),
          requiredField: requiredField,
          validator: requiredField
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ),
    );
  }

  Widget _requiredInputLabel(String label, {required bool requiredField}) {
    if (!requiredField) return Text(label);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  InputDecoration _phoneDecoration(
      String label, {
        required String hint,
        required bool requiredField,
      }) {
    return InputDecoration(
      label: _requiredInputLabel(label, requiredField: requiredField),
      hintText: hint,
      errorMaxLines: 4,
      helperMaxLines: 4,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.blueGrey,
      ),
      hintStyle: TextStyle(
        color: Colors.blueGrey.withOpacity(0.82),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF3F7FA),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.24)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.withOpacity(0.65)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.withOpacity(0.85), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  String _countryDisplayName(_MgysdCountryCodeOption country) {
    final label = country.label.trim();
    final bracketIndex = label.indexOf(' (');
    if (bracketIndex > 0) return label.substring(0, bracketIndex);
    return label;
  }

  String _countryFlag(_MgysdCountryCodeOption country) {
    switch (country.code) {
      case 'LS':
        return '🇱🇸';
      case 'ZA':
        return '🇿🇦';
      case 'ZW':
        return '🇿🇼';
      case 'MZ':
        return '🇲🇿';
      case 'BW':
        return '🇧🇼';
      case 'NA':
        return '🇳🇦';
      case 'SZ':
        return '🇸🇿';
      case 'ZM':
        return '🇿🇲';
      case 'MW':
        return '🇲🇼';
      case 'US':
        return '🇺🇸';
      case 'GB':
        return '🇬🇧';
      case 'INTL':
        return '🌐';
      default:
        return '🌐';
    }
  }

  String _phoneFieldLabel(String label, _MgysdCountryCodeOption country) {
    if (country.code == 'INTL') return label;

    if (country.minNationalDigits == country.maxNationalDigits) {
      return '$label (${country.maxNationalDigits} digits)';
    }

    return '$label (${country.minNationalDigits}-${country.maxNationalDigits} digits)';
  }

  String _formatPhoneTextForSelectedCountry(String value, String countryCode) {
    final country = _phoneCountryByCode(countryCode);
    return _MgysdPhoneNumberInputFormatter(country).formatEditUpdate(
      const TextEditingValue(),
      TextEditingValue(text: value),
    ).text;
  }

  void _formatPhoneControllerForSelectedCountry(
      TextEditingController controller,
      String countryCode,
      ) {
    final formatted = _formatPhoneTextForSelectedCountry(
      controller.text,
      countryCode,
    );

    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }

  Future<String?> _showCountryPicker({
    required String selectedCode,
  }) async {
    String query = '';

    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            final normalizedQuery = query.trim().toLowerCase();
            final countries = normalizedQuery.isEmpty
                ? _phoneCountryOptions
                : _phoneCountryOptions.where((country) {
              final countryName = _countryDisplayName(country).toLowerCase();
              final label = country.label.toLowerCase();
              final dialCode = country.dialCode.toLowerCase();
              final code = country.code.toLowerCase();

              return countryName.contains(normalizedQuery) ||
                  label.contains(normalizedQuery) ||
                  dialCode.contains(normalizedQuery) ||
                  code.contains(normalizedQuery);
            }).toList();

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 620,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.82,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select Country',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              FocusScope.of(dialogContext).unfocus();
                              Navigator.of(dialogContext, rootNavigator: true).pop();
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search by country or code (e.g. Lesotho or +266)',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blueGrey.withOpacity(0.25),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.color,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (value) => setModalState(() {
                          query = value;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: countries.isEmpty
                            ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No countries found'),
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          itemCount: countries.length,
                          itemBuilder: (itemContext, index) {
                            final country = countries[index];
                            final selected = country.code == selectedCode;

                            return Material(
                              color: selected
                                  ? widget.color.withOpacity(0.10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  FocusScope.of(dialogContext).unfocus();
                                  Navigator.of(dialogContext, rootNavigator: true)
                                      .pop(country.code);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _countryFlag(country),
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _countryDisplayName(country),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: selected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        country.dialCode,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _countryCodeSelectorButton({
    required String value,
    required void Function(String?) onChanged,
  }) {
    final country = _phoneCountryByCode(value);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (_countryPickerBusy) return;
        _countryPickerBusy = true;

        final selectedCode = await _showCountryPicker(
          selectedCode: country.code,
        );

        _countryPickerBusy = false;

        if (!mounted || selectedCode == null || selectedCode == value) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          onChanged(selectedCode);
        });
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _countryFlag(country),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 6),
              Text(
                country.dialCode,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneInputField({
    required String label,
    required TextEditingController controller,
    required String countryCode,
    required void Function(String?) onCountryChanged,
    required bool requiredField,
  }) {
    final country = _phoneCountryByCode(countryCode);
    final phoneHint = country.code == 'INTL'
        ? 'Start with + country code'
        : country.minNationalDigits == country.maxNationalDigits
        ? 'Phone Number (${country.maxNationalDigits} digits)'
        : 'Phone Number (${country.minNationalDigits}-${country.maxNationalDigits} digits)';

    final phoneField = TextFormField(
      controller: controller,
      decoration: _phoneDecoration(
        _phoneFieldLabel(label, country),
        hint: phoneHint,
        requiredField: requiredField,
      ),
      keyboardType: country.code == 'INTL'
          ? TextInputType.phone
          : TextInputType.number,
      inputFormatters: [
        _MgysdPhoneNumberInputFormatter(country),
      ],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => _phoneValidator(
        value,
        requiredField: requiredField,
        countryCode: countryCode,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: _countryCodeSelectorButton(
            value: countryCode,
            onChanged: onCountryChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: phoneField),
      ],
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Identified Concerns',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'These are the specific concerns identified for this client.',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  ..._visibleGroupedReasons().map(_reasonGroupCard).toList(),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                  child: keyboardType == TextInputType.phone
                      ? _phoneInputField(
                    controller: item.controller,
                    label: '$label ${index + 1}',
                    countryCode: item.phoneCountryCode,
                    requiredField: false,
                    onCountryChanged: (value) {
                      setState(() => item.phoneCountryCode = value ?? 'LS');
                      _formatPhoneControllerForSelectedCountry(
                        item.controller,
                        item.phoneCountryCode,
                      );
                    },
                  )
                      : _Input(
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
    TextEditingController? otherController,
  }) {
    final showOther = otherController != null && selectedValues.contains('OTHER');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
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
          if (showOther) ...[
            const SizedBox(height: 10),
            _Input(
              controller: otherController,
              label: 'Specify other',
              hint: 'Enter details',
              validator: (v) {
                if (showOther && (v == null || v.trim().isEmpty)) {
                  return 'Please specify';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _yesNoGatedMultiSelect({
    required String title,
    required String subtitle,
    required String gateValue,
    required void Function(String?) onGateChanged,
    required String revealOn,
    required List<_Opt> options,
    required Set<String> selectedValues,
    required TextEditingController otherController,
  }) {
    final showOther = selectedValues.contains('OTHER');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Yes / No',
            value: gateValue,
            options: yesNoOptions,
            requiredField: true,
            onChanged: (v) {
              onGateChanged(v);
              if (v != revealOn) {
                setState(() {
                  selectedValues.clear();
                  otherController.clear();
                });
              }
            },
          ),
          if (gateValue == revealOn) ...[
            const SizedBox(height: 10),
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
            if (showOther) ...[
              const SizedBox(height: 10),
              _Input(
                controller: otherController,
                label: 'Specify other',
                hint: 'Enter details',
                validator: (v) {
                  if (showOther && (v == null || v.trim().isEmpty)) {
                    return 'Please specify';
                  }
                  return null;
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  ////
  List<_Opt> _availableHouseholdMembersForRisk() {
    final List<_Opt> members = [];

    final clientName = '${_clientFirstNameController.text.trim()} ${_clientSurnameController.text.trim()}'.trim();
    if (clientName.isNotEmpty) {
      members.add(_Opt('CLIENT', 'Client: $clientName'));
    }

    if (_fatherAlive == 'Yes') {
      final fatherName = '${_fatherFirstNameController.text.trim()} ${_fatherSurnameController.text.trim()}'.trim();
      if (fatherName.isNotEmpty) {
        members.add(_Opt('Father', 'Father: $fatherName'));
      }
    }

    if (_motherAlive == 'Yes') {
      final motherName = '${_motherFirstNameController.text.trim()} ${_motherSurnameController.text.trim()}'.trim();
      if (motherName.isNotEmpty) {
        members.add(_Opt('Mother', 'Mother: $motherName'));
      }
    }

    for (final caregiver in _caregivers) {
      final caregiverName = '${caregiver.nameController.text.trim()} ${caregiver.surnameController.text.trim()}'.trim();
      if (caregiverName.isNotEmpty) {
        members.add(_Opt(caregiver.id, 'Caregiver: $caregiverName'));
      }
    }

    final personalAssistantName = '${_personalAssistantNameController.text.trim()} ${_personalAssistantSurnameController.text.trim()}'.trim();
    if (personalAssistantName.isNotEmpty) {
      members.add(_Opt('PERSONAL_ASSISTANT', 'Personal Assistant: $personalAssistantName'));
    }

    for (final member in _otherHouseholdMembers) {
      final memberName = '${member.firstNameController.text.trim()} ${member.surnameController.text.trim()}'.trim();
      if (memberName.isNotEmpty) {
        members.add(_Opt(member.id, memberName));
      }
    }

    return members;
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
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
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
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
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
                label: 'Case Worker',
                hint: 'Name of case worker',
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
            _riskDomainItem(
              title: 'Family background',
              value: _riskFamilyBackground,
              options: riskFamilyBackgroundOptions,
              onChanged: (v) => setState(() => _riskFamilyBackground = v ?? ''),
              notesController: _riskFamilyBackgroundNotesController,
            ),
            if (_caregivers.isNotEmpty)
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

  Widget _buildAdditionalAssessmentSection(Color primary) {
    return MaterialCard(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(
              color: primary,
              title: 'Additional Assessment',
              subtitle: 'Self-care, disability, assistive devices, rehabilitation and employability.',
              icon: Icons.accessible_outlined,
            ),
            const SizedBox(height: 12),
            _yesNoGatedMultiSelect(
              title: 'Self-Care',
              subtitle: 'Is the client able to perform daily tasks on their own? e.g. grooming, dressing, feeding, bathing, toileting, laundry.',
              gateValue: _selfCareIndependent,
              onGateChanged: (v) => setState(() => _selfCareIndependent = v ?? ''),
              revealOn: 'NO',
              options: selfCareDomains,
              selectedValues: _selfCareDomainsNeeded,
              otherController: _selfCareOtherController,
            ),
            _yesNoGatedMultiSelect(
              title: 'Disability diagnosis',
              subtitle: 'Any form of disability? e.g. hearing loss, blindness, speech impairment, mobility impairment, vision impairment, albinism, deaf.',
              gateValue: _hasDisabilityDiagnosis,
              onGateChanged: (v) => setState(() {
                _hasDisabilityDiagnosis = v ?? '';
                _syncDisabilityStatus();
              }),
              revealOn: 'YES',
              options: disabilityTypeOptions,
              selectedValues: _disabilityTypes,
              otherController: _disabilityTypeOtherController,
            ),
            _yesNoGatedMultiSelect(
              title: 'Assistive devices',
              subtitle: 'Is there any assistive device the client is using? e.g. wheelchair, hearing aid, spectacles, crutches, white cane.',
              gateValue: _usesAssistiveDevice,
              onGateChanged: (v) => setState(() {
                _usesAssistiveDevice = v ?? '';
                _syncDisabilityStatus();
              }),
              revealOn: 'YES',
              options: assistiveDeviceOptions,
              selectedValues: _assistiveDevices,
              otherController: _assistiveDeviceOtherController,
            ),
            _yesNoGatedMultiSelect(
              title: 'Rehabilitation services',
              subtitle: 'Does the client receive any rehabilitation services? e.g. physiotherapy, counselling.',
              gateValue: _receivesRehabilitationServices,
              onGateChanged: (v) => setState(() => _receivesRehabilitationServices = v ?? ''),
              revealOn: 'YES',
              options: rehabilitationServiceOptions,
              selectedValues: _rehabilitationServices,
              otherController: _rehabilitationServiceOtherController,
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employability',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'What barriers does the client face in finding a job?',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12.5, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: employabilityBarrierOptions
                        .map((option) => _riskChoiceChip(
                      option: option,
                      selectedValues: _employabilityBarriers,
                    ))
                        .toList(),
                  ),
                  if (_employabilityBarriers.contains('OTHER')) ...[
                    const SizedBox(height: 10),
                    _Input(
                      controller: _employabilityBarrierOtherController,
                      label: 'Specify other',
                      hint: 'Enter other barrier',
                      validator: (v) {
                        if (_employabilityBarriers.contains('OTHER') &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Please specify';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Skills development',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'What skills does the client have to improve his/her livelihood/wellbeing?',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12.5, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skillsDevelopmentOptions
                        .map((option) => _riskChoiceChip(
                      option: option,
                      selectedValues: _skillsDevelopmentAreas,
                    ))
                        .toList(),
                  ),
                  if (_skillsDevelopmentAreas.contains('OTHER')) ...[
                    const SizedBox(height: 10),
                    _Input(
                      controller: _skillsDevelopmentOtherController,
                      label: 'Specify other',
                      hint: 'Enter other skill area',
                      validator: (v) {
                        if (_skillsDevelopmentAreas.contains('OTHER') &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Please specify';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: primary.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, color: primary, size: 19),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Auto disability result',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Auto-populated from disability diagnosis and assistive device responses.',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12.3, height: 1.3, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  _dropdown(
                    label: 'Client has disability',
                    value: _isDisabled,
                    options: yesNoOptions,
                    requiredField: true,
                    enabled: false,
                    onChanged: (_) {},
                  ),
                ],
              ),
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
    required String phoneCountryCode,
    required void Function(String value) onPhoneCountryChanged,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
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
          if (aliveValue == 'Yes') ...[
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
            if (livingWithChildValue != 'Yes' &&
                livingWithChildValue.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _Input(
                controller: whyNotLivingController,
                label: 'Why?',
                hint: 'Explain why not living with the child',
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _phoneInputField(
                controller: phoneController,
                label: 'Phone Number',
                countryCode: phoneCountryCode,
                requiredField: false,
                onCountryChanged: (value) {
                  onPhoneCountryChanged(value ?? 'LS');
                  _formatPhoneControllerForSelectedCountry(
                    phoneController,
                    value ?? 'LS',
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }


  Widget _caregiverCard(int index, _CaregiverEntry caregiver) {
    final summary = '${caregiver.nameController.text.trim()} ${caregiver.surnameController.text.trim()}'.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _collapsibleCardHeader(
            title: 'Caregiver ${index + 1}',
            summary: summary,
            isExpanded: caregiver.isExpanded,
            onToggle: () => setState(() => caregiver.isExpanded = !caregiver.isExpanded),
            onDelete: () => _removeCaregiver(index),
          ),
          if (caregiver.isExpanded) ...[
            const SizedBox(height: 10),
            _row2(
              _Input(
                controller: caregiver.nameController,
                label: 'Name',
                hint: 'Caregiver name',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              _Input(
                controller: caregiver.surnameController,
                label: 'Surname',
                hint: 'Caregiver surname',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 10),
            _row2(
              _dropdown(
                label: 'Sex',
                value: caregiver.sex,
                options: sexOptions,
                requiredField: true,
                onChanged: (v) => setState(() => caregiver.sex = v ?? ''),
              ),
              _Input(
                controller: caregiver.relationshipController,
                label: 'Relationship with client',
                hint: 'e.g. Aunt, Grandmother',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 10),
            _row2(
              _dateInput(
                controller: caregiver.dobController,
                label: 'Date of Birth',
                hint: 'Pick date',
                requiredField: true,
              ),
              _Input(
                controller: caregiver.occupationController,
                label: 'Occupation',
                hint: 'Enter occupation',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 10),
            _phoneInputField(
              controller: caregiver.phoneController,
              label: 'Phone Number',
              countryCode: caregiver.phoneCountryCode,
              requiredField: true,
              onCountryChanged: (value) {
                setState(() => caregiver.phoneCountryCode = value ?? 'LS');
                _formatPhoneControllerForSelectedCountry(
                  caregiver.phoneController,
                  caregiver.phoneCountryCode,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _nextOfKinCard(int index, _NextOfKinEntry nextOfKin) {
    final isOther = nextOfKin.relationship == 'OTHER';
    final summary = '${nextOfKin.firstNameController.text.trim()} ${nextOfKin.surnameController.text.trim()}'.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _collapsibleCardHeader(
            title: 'Next of Kin ${index + 1}',
            summary: summary,
            isExpanded: nextOfKin.isExpanded,
            onToggle: () => setState(() => nextOfKin.isExpanded = !nextOfKin.isExpanded),
            onDelete: () => _removeNextOfKin(index),
          ),
          if (nextOfKin.isExpanded) ...[
            const SizedBox(height: 10),
            _row2(
              _Input(
                controller: nextOfKin.firstNameController,
                label: 'First name',
                hint: 'Next of kin first name',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              _Input(
                controller: nextOfKin.surnameController,
                label: 'Surname',
                hint: 'Next of kin surname',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 10),
            _phoneInputField(
              controller: nextOfKin.phoneController,
              label: 'Phone Number',
              countryCode: nextOfKin.phoneCountryCode,
              requiredField: true,
              onCountryChanged: (value) {
                setState(() => nextOfKin.phoneCountryCode = value ?? 'LS');
                _formatPhoneControllerForSelectedCountry(
                  nextOfKin.phoneController,
                  nextOfKin.phoneCountryCode,
                );
              },
            ),
            const SizedBox(height: 10),
            _Input(
              controller: nextOfKin.physicalAddressController,
              label: 'Physical Address',
              hint: 'Describe physical address',
              maxLines: 3,
              requiredField: true,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'Relationship to Client',
              value: nextOfKin.relationship,
              options: _nextOfKinRelationshipOptions(),
              requiredField: true,
              onChanged: (v) {
                setState(() {
                  nextOfKin.relationship = v ?? '';
                  if (nextOfKin.relationship != 'OTHER') {
                    nextOfKin.relationshipOtherController.clear();
                  }
                });
              },
            ),
            if (isOther) ...[
              const SizedBox(height: 10),
              _Input(
                controller: nextOfKin.relationshipOtherController,
                label: 'Specify other relationship',
                hint: 'Enter relationship',
                validator: (v) {
                  if (isOther && (v == null || v.trim().isEmpty)) {
                    return 'Please specify relationship';
                  }
                  return null;
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _caregiverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Caregivers',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...List.generate(
          _caregivers.length,
              (index) => _caregiverCard(index, _caregivers[index]),
        ),
        OutlinedButton.icon(
          onPressed: _addCaregiver,
          icon: const Icon(Icons.add),
          label: const Text('Add caregiver'),
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.color,
            side: BorderSide(color: widget.color),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _personalAssistantSection() {
    if (!_isDisabledYes) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
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
          _phoneInputField(
            controller: _personalAssistantPhoneController,
            label: 'Phone Number',
            countryCode: _personalAssistantPhoneCountryCode,
            requiredField: false,
            onCountryChanged: (value) {
              setState(() => _personalAssistantPhoneCountryCode = value ?? 'LS');
              _formatPhoneControllerForSelectedCountry(
                _personalAssistantPhoneController,
                _personalAssistantPhoneCountryCode,
              );
            },
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
            if (_isChild) ...[
              _parentSection(
                title: 'Father',
                aliveValue: _fatherAlive,
                onAliveChanged: (value) {
                  setState(() {
                    _fatherAlive = value;
                    if (_fatherAlive != 'Yes') {
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
                    if (_fatherLivingWithChild == 'Yes') {
                      _fatherWhyNotLivingController.clear();
                      _fatherPhoneController.clear();
                    }
                  });
                },
                whyNotLivingController: _fatherWhyNotLivingController,
                phoneController: _fatherPhoneController,
                phoneCountryCode: _fatherPhoneCountryCode,
                onPhoneCountryChanged: (value) {
                  setState(() => _fatherPhoneCountryCode = value);
                },
              ),
              _parentSection(
                title: 'Mother',
                aliveValue: _motherAlive,
                onAliveChanged: (value) {
                  setState(() {
                    _motherAlive = value;
                    if (_motherAlive != 'Yes') {
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
                    if (_motherLivingWithChild == 'Yes') {
                      _motherWhyNotLivingController.clear();
                      _motherPhoneController.clear();
                    }
                  });
                },
                whyNotLivingController: _motherWhyNotLivingController,
                phoneController: _motherPhoneController,
                phoneCountryCode: _motherPhoneCountryCode,
                onPhoneCountryChanged: (value) {
                  setState(() => _motherPhoneCountryCode = value);
                },
              ),
            ],
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

    final summary = '${member.firstNameController.text.trim()} ${member.surnameController.text.trim()}'.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _collapsibleCardHeader(
            title: 'Household Member ${index + 1}',
            summary: summary,
            isExpanded: member.isExpanded,
            onToggle: () => setState(() => member.isExpanded = !member.isExpanded),
            onDelete: () => _removeOtherHouseholdMember(index),
          ),
          if (member.isExpanded) ...[
            const SizedBox(height: 10),
            _row2(
              _Input(
                controller: member.firstNameController,
                label: 'First name',
                hint: 'Enter first name',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              _Input(
                controller: member.surnameController,
                label: 'Surname',
                hint: 'Enter surname',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    requiredField: true,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                requiredField: true,
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
                requiredField: true,
                onChanged: (v) {
                  setState(() {
                    member.relationshipToClient = v ?? '';
                    if (member.relationshipToClient != 'OTHER') {
                      member.relationshipOtherController.clear();
                    }
                  });
                },
              ),
            ),
            if (member.relationshipToClient == 'OTHER') ...[
              const SizedBox(height: 10),
              _Input(
                controller: member.relationshipOtherController,
                label: 'Specify other relationship',
                hint: 'Enter relationship to client',
                validator: (v) {
                  if (member.relationshipToClient == 'OTHER' &&
                      (v == null || v.trim().isEmpty)) {
                    return 'Please specify relationship';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 10),
            _row2(
              _Input(
                controller: member.occupationController,
                label: 'Occupation',
                hint: 'Enter occupation',
                requiredField: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              _phoneInputField(
                controller: member.contactsController,
                label: 'Contacts',
                countryCode: member.contactsCountryCode,
                requiredField: true,
                onCountryChanged: (value) {
                  setState(() => member.contactsCountryCode = value ?? 'LS');
                  _formatPhoneControllerForSelectedCountry(
                    member.contactsController,
                    member.contactsCountryCode,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'Any Disability?',
              value: member.hasDisability,
              options: yesNoOptions,
              requiredField: true,
              onChanged: (v) {
                setState(() {
                  member.hasDisability = v ?? '';
                  if (member.hasDisability != 'Yes') {
                    member.disabilitySpecifyController.clear();
                  }
                });
              },
            ),
            if (member.hasDisability == 'Yes') ...[
              const SizedBox(height: 10),
              _Input(
                controller: member.disabilitySpecifyController,
                label: 'Specify disability',
                hint: 'Describe disability',
                maxLines: 3,
              ),
            ],
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


  Widget _partTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return MaterialCard(
      body: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.10),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 12.2,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _subPartTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Icon(icon, color: color, size: 20),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [child],
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
              ? 'Intake & Risk Assessment'
              : 'Enroll Client Case',
          activeInterventionProgram: activeInterventionProgram,
          disableSelectionOfActiveIntervention: false,
        ),
      ),
      body: SubPageBody(
        body: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
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
                  _partTile(
                    title: 'Part 1: Risk Assessment and Reasons for Enrolment',
                    subtitle: 'Start with assessment, then confirm why the client is enrolled.',
                    icon: Icons.fact_check_outlined,
                    color: primary,
                    initiallyExpanded: true,
                    children: [
                      _subPartTile(
                        title: '1.1 Initial Assessment',
                        subtitle: 'Capture risk level and key assessment domains.',
                        icon: Icons.health_and_safety_outlined,
                        color: primary,
                        child: _buildInitialRiskAssessmentSection(primary),
                      ),
                      _subPartTile(
                        title: '1.2 Reasons for Enrolment',
                        subtitle: 'Select only the reason(s) that apply.',
                        icon: Icons.assignment_late_outlined,
                        color: primary,
                        child: _buildReasonSection(primary),
                      ),
                      _subPartTile(
                        title: '1.3 Additional Assessment',
                        subtitle: 'Disability, self-care, rehabilitation and employability.',
                        icon: Icons.accessibility_new_outlined,
                        color: primary,
                        child: _buildAdditionalAssessmentSection(primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _partTile(
                    title: 'Part 2: Household, Client and Education',
                    subtitle: 'Location, client identity, school and employment details.',
                    icon: Icons.home_work_outlined,
                    color: primary,
                    initiallyExpanded: true,
                    children: [
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
                              _Input(
                                controller: _identityNumberController,
                                label: 'Identity Number',
                                hint: 'National ID / document number',
                                keyboardType: TextInputType.text,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9\s-]'),
                                  ),
                                ],
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                validator: _identityNumberValidator,
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
                                onChanged: (v) {
                                  setState(() {
                                    _nationality = v ?? '';
                                    if (_nationality != 'OTHER') {
                                      _nationalityOtherController.clear();
                                    }
                                  });
                                },
                              ),
                              if (_nationality == 'OTHER') ...[
                                const SizedBox(height: 10),
                                _Input(
                                  controller: _nationalityOtherController,
                                  label: 'Specify other nationality',
                                  hint: 'Enter nationality',
                                  validator: (v) {
                                    if (_nationality == 'OTHER' &&
                                        (v == null || v.trim().isEmpty)) {
                                      return 'Please specify nationality';
                                    }
                                    return null;
                                  },
                                ),
                              ],
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
                                _phoneInputField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  countryCode: _clientPhoneCountryCode,
                                  requiredField: false,
                                  onCountryChanged: (value) {
                                    setState(() => _clientPhoneCountryCode = value ?? 'LS');
                                    _formatPhoneControllerForSelectedCountry(
                                      _phoneController,
                                      _clientPhoneCountryCode,
                                    );
                                  },
                                ),
                                _phoneInputField(
                                  controller: _alternativePhoneController,
                                  label: 'Alternative Phone Number',
                                  countryCode: _clientAlternativePhoneCountryCode,
                                  requiredField: false,
                                  onCountryChanged: (value) {
                                    setState(() => _clientAlternativePhoneCountryCode = value ?? 'LS');
                                    _formatPhoneControllerForSelectedCountry(
                                      _alternativePhoneController,
                                      _clientAlternativePhoneCountryCode,
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EEF4),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.blueGrey.withOpacity(0.22)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _clientCategory.isEmpty
                                          ? Icons.info_outline
                                          : Icons.check_circle_outline,
                                      color: Colors.blueGrey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Client category',
                                            style: TextStyle(color: Colors.blueGrey, fontSize: 12.5),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _clientCategory.isEmpty
                                                ? 'Not yet determined — pick the Date of Birth above'
                                                : (_isChild ? 'Child' : 'Adult / Elderly Person'),
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                    _notInSchoolStatus = '';
                                    _highestLevelAchieved = '';
                                    if (_isClientInSchool != 'YES') {
                                      _schoolNameController.clear();
                                      _grade = '';
                                      _schoolLevel = '';
                                    }
                                  });
                                },
                              ),
                              if (_isClientInSchool == 'Yes') ...[
                                const SizedBox(height: 10),
                                _Input(
                                  controller: _schoolNameController,
                                  label: 'Name of School',
                                  hint: 'Enter school name',
                                ),
                                if (!_isAdultOrElderly) ...[
                                  const SizedBox(height: 10),
                                  _dropdown(
                                    label: 'Level of school',
                                    value: _schoolLevel,
                                    options: schoolLevelOptions,
                                    requiredField: true,
                                    onChanged: (v) {
                                      setState(() {
                                        _schoolLevel = v ?? '';
                                        _grade = '';
                                      });
                                    },
                                  ),
                                  if (_schoolLevel == 'PRIMARY') ...[
                                    const SizedBox(height: 10),
                                    _dropdown(
                                      label: 'Grade',
                                      value: _grade,
                                      options: primaryGradeOptions,
                                      requiredField: true,
                                      onChanged: (v) =>
                                          setState(() => _grade = v ?? ''),
                                    ),
                                  ],
                                  if (_schoolLevel == 'SECONDARY') ...[
                                    const SizedBox(height: 10),
                                    _dropdown(
                                      label: 'Grade',
                                      value: _grade,
                                      options: secondaryGradeOptions,
                                      requiredField: true,
                                      onChanged: (v) =>
                                          setState(() => _grade = v ?? ''),
                                    ),
                                  ],
                                  if (_schoolLevel == 'HIGH_SCHOOL') ...[
                                    const SizedBox(height: 10),
                                    _dropdown(
                                      label: 'Grade',
                                      value: _grade,
                                      options: highSchoolGradeOptions,
                                      requiredField: true,
                                      onChanged: (v) =>
                                          setState(() => _grade = v ?? ''),
                                    ),
                                  ],
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
                              if (_isClientInSchool == 'No') ...[
                                const SizedBox(height: 10),
                                _dropdown(
                                  label: 'School attendance Status',
                                  value: _schoolAttendanceStatus,
                                  options: notInSchoolAttendanceOptions,
                                  requiredField: true,
                                  onChanged: (v) {
                                    setState(() {
                                      _schoolAttendanceStatus = v ?? '';
                                      if (_schoolAttendanceStatus != 'NO_LONGER_IN_SCHOOL') {
                                        _highestLevelAchieved = '';
                                      }
                                    });
                                  },
                                ),
                                if (_schoolAttendanceStatus == 'NO_LONGER_IN_SCHOOL') ...[
                                  const SizedBox(height: 10),
                                  _dropdown(
                                    label: 'Highest level achieved',
                                    value: _highestLevelAchieved,
                                    options: highestLevelAchievedOptions,
                                    requiredField: true,
                                    onChanged: (v) => setState(
                                            () => _highestLevelAchieved = v ?? ''),
                                  ),
                                ],
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
                                      if (_isAdultEmployed != 'Yes') {
                                        _employerNameController.clear();
                                      }
                                    });
                                  },
                                ),
                                if (_isAdultEmployed == 'Yes') ...[
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  _partTile(
                    title: 'Part 3: Family and Household Members',
                    subtitle: 'Next of kin, parents, caregivers and household members.',
                    icon: Icons.family_restroom_outlined,
                    color: primary,
                    children: [
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
                                'Capture the main contact person(s) linked to the client.',
                                icon: Icons.contact_phone_outlined,
                              ),
                              const SizedBox(height: 12),
                              ...List.generate(
                                _nextOfKins.length,
                                    (index) => _nextOfKinCard(index, _nextOfKins[index]),
                              ),
                              OutlinedButton.icon(
                                onPressed: _addNextOfKin,
                                icon: const Icon(Icons.add),
                                label: const Text('Add next of kin'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: widget.color,
                                  side: BorderSide(color: widget.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFamilyInformationSection(primary),
                      const SizedBox(height: 12),
                      _buildOtherHouseholdMembersSection(primary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_saving || _loadingExistingCase) ? null : _saveCase,
                        icon: _saving
                            ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : widget.isEditing
                              ? 'Update Intake and Initial Risk Assessment'
                              : 'Save Intake and Initial Risk Assessment',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: primary.withOpacity(0.65),
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
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
    this.requiredField = false,
    this.inputFormatters,
    this.autovalidateMode,
    this.onChanged,
  }) : super(key: key);

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final int maxLines;
  final bool readOnly;
  final TextInputType? keyboardType;
  final bool requiredField;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      decoration: InputDecoration(
        label: requiredField
            ? RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: label),
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        )
            : null,
        labelText: requiredField ? null : label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey),
        errorMaxLines: 4,
        helperMaxLines: 4,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.blueGrey.withOpacity(0.82), fontSize: 13, fontWeight: FontWeight.w500),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF3F7FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.65)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.85), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}