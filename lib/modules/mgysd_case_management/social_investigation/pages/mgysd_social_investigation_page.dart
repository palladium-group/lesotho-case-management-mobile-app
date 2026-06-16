import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:sqflite/sqflite.dart';

class MgysdSocialInvestigationPage extends StatefulWidget {
  const MgysdSocialInvestigationPage({
    Key? key,
    required this.color,
    required this.mgysdCase,
    this.householdTei,
    this.householdName,
    this.clientName,
  }) : super(key: key);

  final Color color;
  final MgysdCase mgysdCase;
  final String? householdTei;
  final String? householdName;
  final String? clientName;

  @override
  State<MgysdSocialInvestigationPage> createState() =>
      _MgysdSocialInvestigationPageState();
}

class _PersonSummary {
  final String tei;
  final String role;
  final bool isPrimaryClient;
  final Map<String, TextEditingController> controllers;

  _PersonSummary({
    required this.tei,
    required this.role,
    required this.isPrimaryClient,
    required this.controllers,
  });

  String get fullName {
    final first = controllers['firstName']?.text.trim() ?? '';
    final last = controllers['surname']?.text.trim() ?? '';
    final name = ('$first $last').trim();
    return name.isEmpty ? role : name;
  }

  Map<String, dynamic> toJson() {
    return {
      'tei': tei,
      'role': role,
      'isPrimaryClient': isPrimaryClient,
      'values': controllers.map((key, value) => MapEntry(key, value.text.trim())),
    };
  }

  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }
}


class _OrgUnitOption {
  final String id;
  final String name;
  final String parent;
  final int level;

  const _OrgUnitOption({
    required this.id,
    required this.name,
    required this.parent,
    required this.level,
  });
}

class _ChildWellbeingEntry {
  final String id;
  final TextEditingController childNameController;
  final TextEditingController dateController;
  final TextEditingController notesController;

  int? safeAtHome;
  int? listenedTo;
  int? treatedFairly;
  int? talkingTogether;
  int? havingFunTogether;
  int? learningTogether;
  int? goodFriend;
  int? friendsNice;
  int? enjoySchool;
  int? safeAtSchool;
  int? likeLooks;
  int? selfConfident;
  int? opportunities;
  int? lifeGoingWell;
  int? happy;
  int? positiveFuture;
  String hasAnotherChild;

  _ChildWellbeingEntry({
    required this.id,
    String childName = '',
    String date = '',
    String notes = '',
    this.safeAtHome,
    this.listenedTo,
    this.treatedFairly,
    this.talkingTogether,
    this.havingFunTogether,
    this.learningTogether,
    this.goodFriend,
    this.friendsNice,
    this.enjoySchool,
    this.safeAtSchool,
    this.likeLooks,
    this.selfConfident,
    this.opportunities,
    this.lifeGoingWell,
    this.happy,
    this.positiveFuture,
    this.hasAnotherChild = '',
  })  : childNameController = TextEditingController(text: childName),
        dateController = TextEditingController(text: date),
        notesController = TextEditingController(text: notes);

  bool get hasAnyData {
    return childNameController.text.trim().isNotEmpty ||
        dateController.text.trim().isNotEmpty ||
        notesController.text.trim().isNotEmpty ||
        safeAtHome != null ||
        listenedTo != null ||
        treatedFairly != null ||
        talkingTogether != null ||
        havingFunTogether != null ||
        learningTogether != null ||
        goodFriend != null ||
        friendsNice != null ||
        enjoySchool != null ||
        safeAtSchool != null ||
        likeLooks != null ||
        selfConfident != null ||
        opportunities != null ||
        lifeGoingWell != null ||
        happy != null ||
        positiveFuture != null ||
        hasAnotherChild.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childName': childNameController.text.trim(),
      'date': dateController.text.trim(),
      'safeAtHome': safeAtHome,
      'listenedTo': listenedTo,
      'treatedFairly': treatedFairly,
      'talkingTogether': talkingTogether,
      'havingFunTogether': havingFunTogether,
      'learningTogether': learningTogether,
      'goodFriend': goodFriend,
      'friendsNice': friendsNice,
      'enjoySchool': enjoySchool,
      'safeAtSchool': safeAtSchool,
      'likeLooks': likeLooks,
      'selfConfident': selfConfident,
      'opportunities': opportunities,
      'lifeGoingWell': lifeGoingWell,
      'happy': happy,
      'positiveFuture': positiveFuture,
      'hasAnotherChild': hasAnotherChild,
      'notes': notesController.text.trim(),
    };
  }

  void dispose() {
    childNameController.dispose();
    dateController.dispose();
    notesController.dispose();
  }
}

class _MgysdSocialInvestigationPageState
    extends State<MgysdSocialInvestigationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _parentCaseId;
  late final String _eventId;

  bool _loading = true;
  bool _saving = false;
  String _savedStatus = 'NOT_STARTED';

  String _clientTei = '';
  String _caseOrgUnit = '';
  String _householdTei = '';

  List<_OrgUnitOption> _allOrgUnits = [];
  List<_OrgUnitOption> _districtOrgUnits = [];
  List<_OrgUnitOption> _communityCouncilOrgUnits = [];

  final TextEditingController _householdFileNumberController = TextEditingController();
  final TextEditingController _householdDistrictController = TextEditingController();
  final TextEditingController _householdCommunityCouncilController = TextEditingController();
  final TextEditingController _householdVillageController = TextEditingController();
  final TextEditingController _householdAddressController = TextEditingController();

  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _socialWorkerFirstNameController = TextEditingController();
  final TextEditingController _socialWorkerSurnameController = TextEditingController();
  final TextEditingController _socialWorkerPhoneController = TextEditingController();
  final TextEditingController _supervisorFirstNameController = TextEditingController();
  final TextEditingController _supervisorSurnameController = TextEditingController();
  final TextEditingController _supervisorPhoneController = TextEditingController();

  final List<_PersonSummary> _familyMembers = [];

  String _incidentPattern = '';
  final TextEditingController _specificIncidentDateController = TextEditingController();
  final TextEditingController _ongoingStartDateController = TextEditingController();
  final TextEditingController _incidentDistrictController = TextEditingController();
  final TextEditingController _incidentCommunityCouncilController = TextEditingController();
  final TextEditingController _incidentVillageController = TextEditingController();
  final TextEditingController _ongoingNotesController = TextEditingController();

  final TextEditingController _changesSinceInitialReasonController = TextEditingController();
  final TextEditingController _changesSinceInitialObservationsController = TextEditingController();
  String _changedSinceInitialAssessment = '';

  String _physicalHealthRating = '';
  final TextEditingController _physicalHealthObservationsController = TextEditingController();
  final TextEditingController _physicalHealthStrengthsController = TextEditingController();
  final TextEditingController _physicalHealthChallengesController = TextEditingController();

  String _emotionalHealthRating = '';
  final TextEditingController _emotionalHealthObservationsController = TextEditingController();
  final TextEditingController _emotionalHealthStrengthsController = TextEditingController();
  final TextEditingController _emotionalHealthChallengesController = TextEditingController();

  String _educationRating = '';
  final TextEditingController _educationObservationsController = TextEditingController();
  final TextEditingController _educationStrengthsController = TextEditingController();
  final TextEditingController _educationChallengesController = TextEditingController();

  final TextEditingController _behaviouralObservationsController = TextEditingController();
  final TextEditingController _behaviouralStrengthsController = TextEditingController();
  final TextEditingController _behaviouralChallengesController = TextEditingController();

  final TextEditingController _identityObservationsController = TextEditingController();
  final TextEditingController _identityStrengthsController = TextEditingController();
  final TextEditingController _identityChallengesController = TextEditingController();

  String _familyBackgroundRating = '';
  final TextEditingController _familyBackgroundObservationsController = TextEditingController();
  final TextEditingController _familyBackgroundStrengthsController = TextEditingController();
  final TextEditingController _familyBackgroundChallengesController = TextEditingController();

  String _caregiverWellbeingRating = '';
  final TextEditingController _caregiverWellbeingObservationsController = TextEditingController();
  final TextEditingController _caregiverWellbeingStrengthsController = TextEditingController();
  final TextEditingController _caregiverWellbeingChallengesController = TextEditingController();

  String _extendedFamilyRating = '';
  final TextEditingController _extendedFamilyObservationsController = TextEditingController();
  final TextEditingController _extendedFamilyStrengthsController = TextEditingController();
  final TextEditingController _extendedFamilyChallengesController = TextEditingController();

  String _parentSiblingRelationshipRating = '';
  final TextEditingController _parentSiblingObservationsController = TextEditingController();
  final TextEditingController _parentSiblingStrengthsController = TextEditingController();
  final TextEditingController _parentSiblingChallengesController = TextEditingController();

  final TextEditingController _peerRelationshipObservationsController = TextEditingController();
  final TextEditingController _peerRelationshipStrengthsController = TextEditingController();
  final TextEditingController _peerRelationshipChallengesController = TextEditingController();

  final TextEditingController _alternativeCareObservationsController = TextEditingController();
  final TextEditingController _alternativeCareStrengthsController = TextEditingController();
  final TextEditingController _alternativeCareChallengesController = TextEditingController();

  String _housingRating = '';
  final TextEditingController _housingObservationsController = TextEditingController();
  final TextEditingController _housingStrengthsController = TextEditingController();
  final TextEditingController _housingChallengesController = TextEditingController();

  String _socialInclusionRating = '';
  final TextEditingController _socialInclusionObservationsController = TextEditingController();
  final TextEditingController _socialInclusionStrengthsController = TextEditingController();
  final TextEditingController _socialInclusionChallengesController = TextEditingController();

  final TextEditingController _childOverallSafetyController = TextEditingController();
  final TextEditingController _childCarePreferenceController = TextEditingController();
  final TextEditingController _childFutureSafetyIdeasController = TextEditingController();
  final TextEditingController _childCommunicationConsiderationsController = TextEditingController();

  final List<_ChildWellbeingEntry> _childWellbeingEntries = [];

  bool _showChildWellbeingIndicators = false;
  bool _showChildVoiceSection = false;

  static const String _stageKey = 'social_investigation';
  static const String _tableName = 'mgysd_social_investigation';

  static const List<String> _yesNoOptions = ['YES', 'NO'];
  static const Map<String, String> _yesNoLabels = {
    'YES': 'Yes',
    'NO': 'No',
  };

  static const List<String> _sexOptions = ['MALE', 'FEMALE'];
  static const Map<String, String> _sexLabels = {
    'MALE': 'Male',
    'FEMALE': 'Female',
  };

  static const List<String> _disabilityOptions = ['YES', 'NO'];


  static const List<String> _nationalityOptions = [
    'Lesotho',
    'South African',
    'Other',
  ];
  static const Map<String, String> _nationalityLabels = {
    'Lesotho': 'Lesotho',
    'South African': 'South African',
    'Other': 'Other',
  };

  static const List<String> _homeLanguageOptions = [
    'Sesotho',
    'English',
    'Xhosa',
    'Other',
  ];
  static const Map<String, String> _homeLanguageLabels = {
    'Sesotho': 'Sesotho',
    'English': 'English',
    'Xhosa': 'Xhosa',
    'Other': 'Other',
  };

  static const List<String> _clientCategoryOptions = [
    'CHILD',
    'ADULT_ELDERLY_PERSON',
  ];
  static const Map<String, String> _clientCategoryLabels = {
    'CHILD': 'Child',
    'ADULT_ELDERLY_PERSON': 'Adult / Elderly Person',
  };

  static const List<String> _relationshipToClientOptions = [
    'CLIENT',
    'MOTHER',
    'FATHER',
    'CAREGIVER',
    'GUARDIAN',
    'PERSONAL_ASSISTANT',
    'SIBLING',
    'GRANDPARENT',
    'AUNT_UNCLE',
    'OTHER_HOUSEHOLD_MEMBER',
    'OTHER',
  ];
  static const Map<String, String> _relationshipToClientLabels = {
    'CLIENT': 'Client',
    'MOTHER': 'Mother',
    'FATHER': 'Father',
    'CAREGIVER': 'Caregiver',
    'GUARDIAN': 'Guardian',
    'PERSONAL_ASSISTANT': 'Personal Assistant',
    'SIBLING': 'Sibling',
    'GRANDPARENT': 'Grandparent',
    'AUNT_UNCLE': 'Aunt / Uncle',
    'OTHER_HOUSEHOLD_MEMBER': 'Other household member',
    'OTHER': 'Other',
  };

  static const List<String> _gradeOptions = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11',
  ];

  static const List<String> _schoolAttendanceOptions = [
    'GOOD_ATTENDANCE',
    'POOR_ATTENDANCE',
    'NO_LONGER_IN_SCHOOL',
    'NEVER_ATTENDED_SCHOOL',
  ];
  static const Map<String, String> _schoolAttendanceLabels = {
    'GOOD_ATTENDANCE': 'Good attendance',
    'POOR_ATTENDANCE': 'Poor attendance',
    'NO_LONGER_IN_SCHOOL': 'No longer in school',
    'NEVER_ATTENDED_SCHOOL': 'Never attended school',
  };

  static const List<String> _aliveOptions = ['YES', 'NO', 'UNKNOWN'];
  static const Map<String, String> _aliveLabels = {
    'YES': 'Yes',
    'NO': 'No',
    'UNKNOWN': 'Unknown',
  };

  static const List<String> _incidentPatternOptions = ['SPECIFIC_DAY', 'LONG_TERM_ONGOING'];
  static const Map<String, String> _incidentPatternLabels = {
    'SPECIFIC_DAY': 'Specific day',
    'LONG_TERM_ONGOING': 'Long-term / ongoing concern',
  };

  static const List<String> _physicalHealthOptions = [
    'GOOD_STABLE',
    'CONCERNS_RECEIVING_SUPPORT',
    'FRAGILE_INCONSISTENT',
    'SIGNIFICANT_ISSUES',
  ];
  static const Map<String, String> _physicalHealthLabels = {
    'GOOD_STABLE': 'In good health / stable',
    'CONCERNS_RECEIVING_SUPPORT': 'Health or wellbeing concerns but receiving support',
    'FRAGILE_INCONSISTENT': 'Fragile / inconsistent',
    'SIGNIFICANT_ISSUES': 'Significant issues',
  };

  static const List<String> _emotionalHealthOptions = [
    'GOOD_STABLE',
    'CONCERNS_RECEIVING_SUPPORT',
    'FRAGILE_INCONSISTENT',
    'SIGNIFICANT_ISSUES_POOR',
  ];
  static const Map<String, String> _emotionalHealthLabels = {
    'GOOD_STABLE': 'In good health / stable',
    'CONCERNS_RECEIVING_SUPPORT': 'Health or wellbeing concerns but receiving support',
    'FRAGILE_INCONSISTENT': 'Fragile / inconsistent',
    'SIGNIFICANT_ISSUES_POOR': 'Significant issues / poor',
  };

  static const List<String> _educationOptions = [
    'STABLE_GOOD',
    'REASONABLE_INCONSISTENT',
    'LEARNING_DISABILITIES',
    'ONGOING_CONCERNS',
    'SIGNIFICANT_ISSUES_DROPOUT',
  ];
  static const Map<String, String> _educationLabels = {
    'STABLE_GOOD': 'Stable / good',
    'REASONABLE_INCONSISTENT': 'Reasonable but inconsistent',
    'LEARNING_DISABILITIES': 'Learning disabilities',
    'ONGOING_CONCERNS': 'Ongoing concerns',
    'SIGNIFICANT_ISSUES_DROPOUT': 'Significant issues, including school or training drop out',
  };

  static const List<String> _familyBackgroundOptions = [
    'STABLE',
    'RECENT_CHANGES',
    'ONGOING_CHALLENGES',
    'UNPREDICTABLE_VIOLENT_CONTEXT',
  ];
  static const Map<String, String> _familyBackgroundLabels = {
    'STABLE': 'Stable',
    'RECENT_CHANGES': 'Recent changes - drop in family income / household members / family wellbeing',
    'ONGOING_CHALLENGES': 'Ongoing challenges',
    'UNPREDICTABLE_VIOLENT_CONTEXT': 'Unpredictable or violent context',
  };

  static const List<String> _caregiverWellbeingOptions = [
    'GOOD_STABLE',
    'CONCERNS_RECEIVING_SUPPORT',
    'FRAGILE_INCONSISTENT',
    'SIGNIFICANT_ISSUES',
  ];
  static const Map<String, String> _caregiverWellbeingLabels = {
    'GOOD_STABLE': 'In good health / stable',
    'CONCERNS_RECEIVING_SUPPORT': 'Health or wellbeing concerns but receiving support',
    'FRAGILE_INCONSISTENT': 'Fragile / inconsistent',
    'SIGNIFICANT_ISSUES': 'Significant issues',
  };

  static const List<String> _relationshipOptions = [
    'STABLE_GOOD',
    'INCONSISTENT',
    'NON_EXISTENT_DYSFUNCTIONAL',
  ];
  static const Map<String, String> _relationshipLabels = {
    'STABLE_GOOD': 'Stable / good',
    'INCONSISTENT': 'Inconsistent',
    'NON_EXISTENT_DYSFUNCTIONAL': 'Non-existent / dysfunctional',
  };

  static const List<String> _parentSiblingRelationshipOptions = [
    'STABLE_GOOD',
    'INCONSISTENT',
    'NON_EXISTING_POOR',
  ];
  static const Map<String, String> _parentSiblingRelationshipLabels = {
    'STABLE_GOOD': 'Stable / good',
    'INCONSISTENT': 'Inconsistent',
    'NON_EXISTING_POOR': 'Non-existing / poor',
  };

  static const List<String> _housingOptions = [
    'STABLE_GOOD',
    'SAFE_SUFFICIENT',
    'INCONSISTENT',
    'UNSTABLE_UNSAFE',
  ];
  static const Map<String, String> _housingLabels = {
    'STABLE_GOOD': 'Stable / good',
    'SAFE_SUFFICIENT': 'Safe / sufficient',
    'INCONSISTENT': 'Inconsistent',
    'UNSTABLE_UNSAFE': 'Unstable / unsafe',
  };

  static const List<String> _socialInclusionOptions = [
    'ACTIVE_ENGAGED',
    'INCONSISTENT_SOMEWHAT_INVOLVED',
    'ISOLATED_POOR_CONNECTIONS',
  ];
  static const Map<String, String> _socialInclusionLabels = {
    'ACTIVE_ENGAGED': 'Active and socially engaged / peer networks / religious or community activities',
    'INCONSISTENT_SOMEWHAT_INVOLVED': 'Inconsistent / somewhat involved',
    'ISOLATED_POOR_CONNECTIONS': 'Isolated / poor connections',
  };

  @override
  void initState() {
    super.initState();
    _parentCaseId = widget.mgysdCase.id.split('__').first;
    _eventId = _resolveEventId(widget.mgysdCase.id);
    _eventDateController.text = _today();
    _loadData();
  }

  @override
  void dispose() {
    _householdFileNumberController.dispose();
    _householdDistrictController.dispose();
    _householdCommunityCouncilController.dispose();
    _householdVillageController.dispose();
    _householdAddressController.dispose();
    _eventDateController.dispose();
    _socialWorkerFirstNameController.dispose();
    _socialWorkerSurnameController.dispose();
    _socialWorkerPhoneController.dispose();
    _supervisorFirstNameController.dispose();
    _supervisorSurnameController.dispose();
    _supervisorPhoneController.dispose();
    for (final member in _familyMembers) { member.dispose(); }
    _specificIncidentDateController.dispose();
    _ongoingStartDateController.dispose();
    _incidentDistrictController.dispose();
    _incidentCommunityCouncilController.dispose();
    _incidentVillageController.dispose();
    _ongoingNotesController.dispose();
    _changesSinceInitialReasonController.dispose();
    _changesSinceInitialObservationsController.dispose();
    _physicalHealthObservationsController.dispose();
    _physicalHealthStrengthsController.dispose();
    _physicalHealthChallengesController.dispose();
    _emotionalHealthObservationsController.dispose();
    _emotionalHealthStrengthsController.dispose();
    _emotionalHealthChallengesController.dispose();
    _educationObservationsController.dispose();
    _educationStrengthsController.dispose();
    _educationChallengesController.dispose();
    _behaviouralObservationsController.dispose();
    _behaviouralStrengthsController.dispose();
    _behaviouralChallengesController.dispose();
    _identityObservationsController.dispose();
    _identityStrengthsController.dispose();
    _identityChallengesController.dispose();
    _familyBackgroundObservationsController.dispose();
    _familyBackgroundStrengthsController.dispose();
    _familyBackgroundChallengesController.dispose();
    _caregiverWellbeingObservationsController.dispose();
    _caregiverWellbeingStrengthsController.dispose();
    _caregiverWellbeingChallengesController.dispose();
    _extendedFamilyObservationsController.dispose();
    _extendedFamilyStrengthsController.dispose();
    _extendedFamilyChallengesController.dispose();
    _parentSiblingObservationsController.dispose();
    _parentSiblingStrengthsController.dispose();
    _parentSiblingChallengesController.dispose();
    _peerRelationshipObservationsController.dispose();
    _peerRelationshipStrengthsController.dispose();
    _peerRelationshipChallengesController.dispose();
    _alternativeCareObservationsController.dispose();
    _alternativeCareStrengthsController.dispose();
    _alternativeCareChallengesController.dispose();
    _housingObservationsController.dispose();
    _housingStrengthsController.dispose();
    _housingChallengesController.dispose();
    _socialInclusionObservationsController.dispose();
    _socialInclusionStrengthsController.dispose();
    _socialInclusionChallengesController.dispose();
    _childOverallSafetyController.dispose();
    _childCarePreferenceController.dispose();
    _childFutureSafetyIdeasController.dispose();
    _childCommunicationConsiderationsController.dispose();
    for (final entry in _childWellbeingEntries) { entry.dispose(); }
    super.dispose();
  }

  String _resolveEventId(String rawId) {
    final parts = rawId.split('__');
    if (parts.length >= 3 && parts.last.trim().length == 11) return parts.last.trim();
    if (rawId.trim().length == 11 && !rawId.contains('__')) return rawId.trim();
    return AppUtil.getUid();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  String _today() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => controller.text = _formatDate(picked));
  }

  int _calculateAgeFromDob(String dobText) {
    final dob = DateTime.tryParse(dobText.trim());
    if (dob == null) return 0;
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _pickDobAndCalculateAge(_PersonSummary member) async {
    final dobController = member.controllers['dob'];
    final ageController = member.controllers['age'];
    if (dobController == null || ageController == null) return;
    await _pickDate(dobController);
    final age = _calculateAgeFromDob(dobController.text);
    setState(() => ageController.text = age == 0 ? '' : age.toString());
  }

  String _normaliseOptionValue(String value, List<String> options) {
    final v = value.trim();
    if (v.isEmpty) return '';
    if (options.contains(v)) return v;
    final upper = v.toUpperCase().replaceAll(' ', '_').replaceAll('/', '_');
    for (final option in options) {
      if (option.toUpperCase() == upper) return option;
    }
    for (final option in options) {
      if (option.toUpperCase().replaceAll('_', ' ') == v.toUpperCase()) {
        return option;
      }
    }
    return v;
  }


  String _normaliseNationality(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    final upper = v.toUpperCase().replaceAll('_', ' ');
    if (upper == 'LESOTHO' || upper == 'MOSOTHO' || upper == 'BASOTHO') {
      return 'Lesotho';
    }
    if (upper == 'SOUTH AFRICAN' || upper == 'SOUTH AFRICA' || upper == 'RSA') {
      return 'South African';
    }
    if (upper == 'OTHER') return 'Other';
    return _nationalityOptions.contains(v) ? v : 'Other';
  }

  String _normaliseHomeLanguage(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    final upper = v.toUpperCase().replaceAll('_', ' ');
    if (upper == 'SESOTHO') return 'Sesotho';
    if (upper == 'ENGLISH') return 'English';
    if (upper == 'XHOSA') return 'Xhosa';
    if (upper == 'OTHER') return 'Other';
    return _homeLanguageOptions.contains(v) ? v : 'Other';
  }

  String _text(dynamic value) => (value ?? '').toString().trim();
  TextEditingController _c([String value = '']) => TextEditingController(text: value);

  Future<Map<String, String>> _loadAttrs(Database db, String tei) async {
    final rows = await db.query(
      'tracked_entity_instance_attribute',
      columns: ['attribute', 'value'],
      where: 'trackedEntityInstance = ?',
      whereArgs: [tei],
    );
    final map = <String, String>{};
    for (final row in rows) {
      final key = _text(row['attribute']);
      final value = _text(row['value']);
      if (key.isNotEmpty) map[key] = value;
    }
    return map;
  }

  Future<Map<String, String>> _resolveSavedInvestigationContext(Database db) async {
    try {
      final rows = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [_eventId],
        limit: 1,
      );
      if (rows.isEmpty) return <String, String>{};

      final row = rows.first;
      final payloadText = _text(row['payloadJson']);
      Map<String, dynamic> payload = <String, dynamic>{};
      if (payloadText.isNotEmpty) {
        try {
          final decoded = jsonDecode(payloadText);
          if (decoded is Map<String, dynamic>) payload = decoded;
        } catch (_) {}
      }

      return {
        'parentCaseId': _text(row['parentCaseId']).isNotEmpty
            ? _text(row['parentCaseId'])
            : _text(row['rootCaseId']).isNotEmpty
            ? _text(row['rootCaseId'])
            : _text(payload['parentCaseId']),
        'clientTei': _text(payload['clientTei']),
        'householdTei': _text(row['householdTei']).isNotEmpty
            ? _text(row['householdTei'])
            : _text(payload['householdTei']),
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String> _primaryClientTeiFromHousehold(Database db, String householdTei) async {
    try {
      final primaryRows = await db.query(
        'mgysd_household_member',
        columns: ['memberTei'],
        where: 'householdTei = ? AND isPrimaryClient = ?',
        whereArgs: [householdTei, 'true'],
        limit: 1,
      );
      if (primaryRows.isNotEmpty) {
        final tei = _text(primaryRows.first['memberTei']);
        if (tei.isNotEmpty) return tei;
      }

      final fallbackRows = await db.query(
        'mgysd_household_member',
        columns: ['memberTei'],
        where: 'householdTei = ? AND memberRole = ?',
        whereArgs: [householdTei, 'CLIENT'],
        limit: 1,
      );
      if (fallbackRows.isNotEmpty) {
        final tei = _text(fallbackRows.first['memberTei']);
        if (tei.isNotEmpty) return tei;
      }
    } catch (_) {}
    return '';
  }

  String get _eventOwnerTei {
    if (_householdTei.trim().isNotEmpty) return _householdTei.trim();
    return _clientTei.trim();
  }


  String _pickUserField(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = _text(row[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<void> _loadCurrentUserIntoSocialWorker(Database db) async {
    try {
      final rows = await db.query('current_user');
      if (rows.isEmpty) return;

      Map<String, Object?> row = rows.first;
      for (final candidate in rows) {
        final login = _text(candidate['isLogin']).toLowerCase();
        if (login == '1' || login == 'true' || login == 'yes') {
          row = candidate;
          break;
        }
      }

      final fullName = _pickUserField(row, [
        'name',
        'displayName',
        'fullName',
        'username',
      ]);
      final phone = _pickUserField(row, [
        'phoneNumber',
        'phone',
        'telephone',
        'mobile',
      ]);

      final firstNameFromColumn = _pickUserField(row, [
        'firstName',
        'firstname',
        'givenName',
      ]);
      final surnameFromColumn = _pickUserField(row, [
        'surname',
        'lastName',
        'lastname',
        'familyName',
      ]);

      final parts = fullName.split(' ').where((p) => p.trim().isNotEmpty).toList();
      final firstName = firstNameFromColumn.isNotEmpty
          ? firstNameFromColumn
          : (parts.isNotEmpty ? parts.first : _text(row['username']));
      final surname = surnameFromColumn.isNotEmpty
          ? surnameFromColumn
          : (parts.length > 1 ? parts.sublist(1).join(' ') : '');

      // Current user is the allocated social worker. Always refresh these
      // fields from the logged-in user so saved drafts do not keep stale names.
      _socialWorkerFirstNameController.text = firstName;
      _socialWorkerSurnameController.text = surname;
      _socialWorkerPhoneController.text = phone;
    } catch (_) {}
  }

  Future<void> _loadOfflineOrgUnits(Database db) async {
    try {
      final rows = await db.query(
        'organisation_unit',
        columns: ['id', 'name', 'parent', 'level'],
        orderBy: 'level ASC, name ASC',
      );

      final units = rows.map((row) {
        return _OrgUnitOption(
          id: _text(row['id']),
          name: _text(row['name']),
          parent: _text(row['parent']),
          level: int.tryParse(_text(row['level'])) ?? 0,
        );
      }).where((unit) => unit.id.isNotEmpty && unit.name.isNotEmpty).toList();

      if (units.isEmpty) return;

      final levels = units.map((u) => u.level).where((l) => l > 0).toSet().toList()
        ..sort();

      int districtLevel = levels.length >= 2 ? levels[1] : levels.first;
      int ccLevel = levels.length >= 3 ? levels[2] : districtLevel + 1;

      _allOrgUnits = units;
      _districtOrgUnits = units.where((u) => u.level == districtLevel).toList();
      _communityCouncilOrgUnits = units.where((u) => u.level == ccLevel).toList();

      if (_districtOrgUnits.isEmpty) _districtOrgUnits = units;
      if (_communityCouncilOrgUnits.isEmpty) _communityCouncilOrgUnits = units;
    } catch (_) {}
  }

  List<_OrgUnitOption> _communityCouncilsFor(String districtNameOrId) {
    final selected = districtNameOrId.trim();
    if (selected.isEmpty) return _communityCouncilOrgUnits;

    _OrgUnitOption? district;
    for (final item in _districtOrgUnits) {
      if (item.id == selected || item.name.toLowerCase() == selected.toLowerCase()) {
        district = item;
        break;
      }
    }

    if (district == null) return _communityCouncilOrgUnits;
    final children = _communityCouncilOrgUnits
        .where((item) => item.parent == district!.id)
        .toList();
    return children.isEmpty ? _communityCouncilOrgUnits : children;
  }

  Future<void> _loadData() async {
    try {
      final db = await _db();
      final savedContext = await _resolveSavedInvestigationContext(db);

      final savedParentCaseId = _text(savedContext['parentCaseId']);
      if (savedParentCaseId.isNotEmpty && savedParentCaseId != _eventId) {
        _parentCaseId = savedParentCaseId;
      }

      _householdTei = (widget.householdTei ?? '').trim();
      if (_householdTei.isEmpty) {
        _householdTei = _text(savedContext['householdTei']);
      }
      _clientTei = _text(savedContext['clientTei']);

      final enrollmentRows = await db.query(
        'enrollment',
        where: 'enrollment = ?',
        whereArgs: [_parentCaseId],
        limit: 1,
      );
      if (enrollmentRows.isNotEmpty) {
        final enrollment = enrollmentRows.first;
        final enrolledTei = _text(enrollment['trackedEntityInstance']);
        _caseOrgUnit = _text(enrollment['orgUnit']);

        if (_householdTei.isEmpty) {
          _householdTei = enrolledTei;
        }

        if (_clientTei.isEmpty) {
          final primaryClient = await _primaryClientTeiFromHousehold(db, _householdTei);
          _clientTei = primaryClient.isNotEmpty ? primaryClient : enrolledTei;
        }
      }

      if (_householdTei.isEmpty && _clientTei.isNotEmpty) {
        final hhRows = await db.query(
          'mgysd_household_member',
          columns: ['householdTei'],
          where: 'memberTei = ?',
          whereArgs: [_clientTei],
          limit: 1,
        );
        if (hhRows.isNotEmpty) _householdTei = _text(hhRows.first['householdTei']);
      }

      if (_clientTei.isEmpty && _householdTei.isNotEmpty) {
        _clientTei = await _primaryClientTeiFromHousehold(db, _householdTei);
      }

      await _loadOfflineOrgUnits(db);
      await _loadHouseholdSummary(db);
      await _loadIntakeSummary(db);
      await _loadSavedForm(db);
      await _loadCurrentUserIntoSocialWorker(db);
    } catch (e) {
      _showSnack('Failed to load social investigation: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHouseholdSummary(Database db) async {
    if (_householdTei.trim().isEmpty) return;

    final attrs = await _loadAttrs(db, _householdTei);
    _householdFileNumberController.text = attrs[MgysdDhis2Uids.attHouseholdFileNumber] ?? '';
    _householdDistrictController.text = attrs[MgysdDhis2Uids.attHouseholdDistrict] ?? '';
    _householdCommunityCouncilController.text = attrs[MgysdDhis2Uids.attHouseholdCommunityCouncil] ?? '';
    _householdVillageController.text = attrs[MgysdDhis2Uids.attHouseholdVillage] ?? '';
    _householdAddressController.text = attrs[MgysdDhis2Uids.attHouseholdAddress] ?? '';
  }

  Future<void> _loadIntakeSummary(Database db) async {
    _familyMembers.clear();
    if (_clientTei.isNotEmpty) {
      final attrs = await _loadAttrs(db, _clientTei);
      _familyMembers.add(_personFromAttrs(tei: _clientTei, role: 'CLIENT', isPrimaryClient: true, attrs: attrs));
    }
    if (_householdTei.isEmpty) return;
    final rows = await db.query('mgysd_household_member', where: 'householdTei = ?', whereArgs: [_householdTei]);
    for (final row in rows) {
      final memberTei = _text(row['memberTei']);
      if (memberTei.isEmpty || memberTei == _clientTei) continue;
      final attrs = await _loadAttrs(db, memberTei);
      _familyMembers.add(_personFromAttrs(
        tei: memberTei,
        role: _text(row['memberRole']).isEmpty ? 'HOUSEHOLD_MEMBER' : _text(row['memberRole']),
        isPrimaryClient: false,
        attrs: attrs,
      ));
    }
  }

  _PersonSummary _personFromAttrs({required String tei, required String role, required bool isPrimaryClient, required Map<String, String> attrs}) {
    return _PersonSummary(
      tei: tei,
      role: role,
      isPrimaryClient: isPrimaryClient,
      controllers: {
        'firstName': _c(attrs[MgysdDhis2Uids.attFirstName] ?? ''),
        'surname': _c(attrs[MgysdDhis2Uids.attLastName] ?? ''),
        'dob': _c(attrs[MgysdDhis2Uids.attDob] ?? ''),
        'age': _c((attrs[MgysdDhis2Uids.attAge] ?? '').trim().isNotEmpty
            ? attrs[MgysdDhis2Uids.attAge] ?? ''
            : (_calculateAgeFromDob(attrs[MgysdDhis2Uids.attDob] ?? '') == 0
            ? ''
            : _calculateAgeFromDob(attrs[MgysdDhis2Uids.attDob] ?? '').toString())),
        'sex': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attSex] ?? '', _sexOptions)),
        'phone': _c(attrs[MgysdDhis2Uids.attPhone] ?? ''),
        'alternativePhone': _c(attrs[MgysdDhis2Uids.attAlternativePhone] ?? ''),
        'occupation': _c(attrs[MgysdDhis2Uids.attOccupation] ?? ''),
        'relationshipToClient': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attRelationshipToClient] ?? role, _relationshipToClientOptions)),
        'hasDisability': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attHasDisability] ?? attrs[MgysdDhis2Uids.attIsDisabled] ?? '', _disabilityOptions)),
        'disabilitySpecify': _c(attrs[MgysdDhis2Uids.attDisabilitySpecify] ?? ''),
        'clientCategory': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attClientCategory] ?? '', _clientCategoryOptions)),
        'identityNumber': _c(attrs[MgysdDhis2Uids.attIdentityNumber] ?? ''),
        'nationality': _c(_normaliseNationality(attrs[MgysdDhis2Uids.attNationality] ?? '')),
        'homeLanguage': _c(_normaliseHomeLanguage(attrs[MgysdDhis2Uids.attHomeLanguage] ?? '')),
        'isClientInSchool': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attIsClientInSchool] ?? '', _yesNoOptions)),
        'schoolName': _c(attrs[MgysdDhis2Uids.attSchoolName] ?? ''),
        'grade': _c(attrs[MgysdDhis2Uids.attGrade] ?? ''),
        'schoolAttendanceStatus': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attSchoolAttendanceStatus] ?? '', _schoolAttendanceOptions)),
        'isAdultEmployed': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attIsAdultEmployed] ?? '', _yesNoOptions)),
        'employerName': _c(attrs[MgysdDhis2Uids.attEmployerName] ?? ''),
        'fatherAlive': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attFatherAlive] ?? '', _aliveOptions)),
        'fatherLivingWithChild': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attFatherLivingWithChild] ?? '', _aliveOptions)),
        'fatherWhyNotLiving': _c(attrs[MgysdDhis2Uids.attFatherWhyNotLiving] ?? ''),
        'motherAlive': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attMotherAlive] ?? '', _aliveOptions)),
        'motherLivingWithChild': _c(_normaliseOptionValue(attrs[MgysdDhis2Uids.attMotherLivingWithChild] ?? '', _aliveOptions)),
        'motherWhyNotLiving': _c(attrs[MgysdDhis2Uids.attMotherWhyNotLiving] ?? ''),
      },
    );
  }

  Future<void> _loadSavedForm(Database db) async {
    final rows = await db.query(_tableName, where: 'id = ?', whereArgs: [_eventId], limit: 1);
    if (rows.isEmpty) return;
    final row = rows.first;
    final payload = jsonDecode(_text(row['payloadJson']).isEmpty ? '{}' : _text(row['payloadJson'])) as Map<String, dynamic>;
    _savedStatus = _text(row['status']).isEmpty ? 'DRAFT' : _text(row['status']);
    _eventDateController.text = _text(payload['eventDate']).isEmpty ? _today() : _text(payload['eventDate']);

    final part1 = (payload['part1'] ?? {}) as Map<String, dynamic>;
    _socialWorkerFirstNameController.text = _text(part1['socialWorkerFirstName']);
    _socialWorkerSurnameController.text = _text(part1['socialWorkerSurname']);
    _socialWorkerPhoneController.text = _text(part1['socialWorkerPhone']);
    _supervisorFirstNameController.text = _text(part1['supervisorFirstName']);
    _supervisorSurnameController.text = _text(part1['supervisorSurname']);
    _supervisorPhoneController.text = _text(part1['supervisorPhone']);

    final part2 = (payload['part2'] ?? {}) as Map<String, dynamic>;
    _incidentPattern = _text(part2['incidentPattern']);
    _specificIncidentDateController.text = _text(part2['specificIncidentDate']);
    _ongoingStartDateController.text = _text(part2['ongoingStartDate']);
    _incidentDistrictController.text = _text(part2['incidentDistrict']);
    _incidentCommunityCouncilController.text = _text(part2['incidentCommunityCouncil']);
    _incidentVillageController.text = _text(part2['village']);
    _ongoingNotesController.text = _text(part2['notes']);

    final part3 = (payload['part3'] ?? {}) as Map<String, dynamic>;
    _changedSinceInitialAssessment = _text(part3['changedSinceInitialAssessment']);
    _changesSinceInitialReasonController.text = _text(part3['changeReason']);
    _changesSinceInitialObservationsController.text = _text(part3['additionalObservations']);
    _loadDomain(payload: part3, key: 'physicalHealth', ratingSetter: (v) => _physicalHealthRating = v, observations: _physicalHealthObservationsController, strengths: _physicalHealthStrengthsController, challenges: _physicalHealthChallengesController);
    _loadDomain(payload: part3, key: 'emotionalHealth', ratingSetter: (v) => _emotionalHealthRating = v, observations: _emotionalHealthObservationsController, strengths: _emotionalHealthStrengthsController, challenges: _emotionalHealthChallengesController);
    _loadDomain(payload: part3, key: 'education', ratingSetter: (v) => _educationRating = v, observations: _educationObservationsController, strengths: _educationStrengthsController, challenges: _educationChallengesController);
    _loadDomain(payload: part3, key: 'behaviouralDevelopment', ratingSetter: (_) {}, observations: _behaviouralObservationsController, strengths: _behaviouralStrengthsController, challenges: _behaviouralChallengesController);
    _loadDomain(payload: part3, key: 'identity', ratingSetter: (_) {}, observations: _identityObservationsController, strengths: _identityStrengthsController, challenges: _identityChallengesController);
    _loadDomain(payload: part3, key: 'familyBackground', ratingSetter: (v) => _familyBackgroundRating = v, observations: _familyBackgroundObservationsController, strengths: _familyBackgroundStrengthsController, challenges: _familyBackgroundChallengesController);
    _loadDomain(payload: part3, key: 'caregiverWellbeing', ratingSetter: (v) => _caregiverWellbeingRating = v, observations: _caregiverWellbeingObservationsController, strengths: _caregiverWellbeingStrengthsController, challenges: _caregiverWellbeingChallengesController);
    _loadDomain(payload: part3, key: 'extendedFamily', ratingSetter: (v) => _extendedFamilyRating = v, observations: _extendedFamilyObservationsController, strengths: _extendedFamilyStrengthsController, challenges: _extendedFamilyChallengesController);
    _loadDomain(payload: part3, key: 'parentSiblingRelationship', ratingSetter: (v) => _parentSiblingRelationshipRating = v, observations: _parentSiblingObservationsController, strengths: _parentSiblingStrengthsController, challenges: _parentSiblingChallengesController);
    _loadDomain(payload: part3, key: 'peerRelationship', ratingSetter: (_) {}, observations: _peerRelationshipObservationsController, strengths: _peerRelationshipStrengthsController, challenges: _peerRelationshipChallengesController);
    _loadDomain(payload: part3, key: 'alternativeCare', ratingSetter: (_) {}, observations: _alternativeCareObservationsController, strengths: _alternativeCareStrengthsController, challenges: _alternativeCareChallengesController);
    _loadDomain(payload: part3, key: 'housing', ratingSetter: (v) => _housingRating = v, observations: _housingObservationsController, strengths: _housingStrengthsController, challenges: _housingChallengesController);
    _loadDomain(payload: part3, key: 'socialInclusion', ratingSetter: (v) => _socialInclusionRating = v, observations: _socialInclusionObservationsController, strengths: _socialInclusionStrengthsController, challenges: _socialInclusionChallengesController);

    final part4 = (payload['part4'] ?? {}) as Map<String, dynamic>;
    _childOverallSafetyController.text = _text(part4['overallSafety']);
    _childCarePreferenceController.text = _text(part4['carePreference']);
    _childFutureSafetyIdeasController.text = _text(part4['futureSafetyIdeas']);
    _childCommunicationConsiderationsController.text = _text(part4['communicationConsiderations']);
    _showChildVoiceSection = _childOverallSafetyController.text.trim().isNotEmpty ||
        _childCarePreferenceController.text.trim().isNotEmpty ||
        _childFutureSafetyIdeasController.text.trim().isNotEmpty ||
        _childCommunicationConsiderationsController.text.trim().isNotEmpty;

    final children = (payload['childWellbeing'] ?? []) as List<dynamic>;
    if (children.isNotEmpty) {
      _showChildWellbeingIndicators = true;
      for (final entry in _childWellbeingEntries) { entry.dispose(); }
      _childWellbeingEntries.clear();
      for (final raw in children) {
        final item = (raw ?? {}) as Map<String, dynamic>;
        _childWellbeingEntries.add(_ChildWellbeingEntry(
          id: _text(item['id']).isEmpty ? AppUtil.getUid() : _text(item['id']),
          childName: _text(item['childName']),
          date: _text(item['date']),
          notes: _text(item['notes']),
          safeAtHome: _intOrNull(item['safeAtHome']),
          listenedTo: _intOrNull(item['listenedTo']),
          treatedFairly: _intOrNull(item['treatedFairly']),
          talkingTogether: _intOrNull(item['talkingTogether']),
          havingFunTogether: _intOrNull(item['havingFunTogether']),
          learningTogether: _intOrNull(item['learningTogether']),
          goodFriend: _intOrNull(item['goodFriend']),
          friendsNice: _intOrNull(item['friendsNice']),
          enjoySchool: _intOrNull(item['enjoySchool']),
          safeAtSchool: _intOrNull(item['safeAtSchool']),
          likeLooks: _intOrNull(item['likeLooks']),
          selfConfident: _intOrNull(item['selfConfident']),
          opportunities: _intOrNull(item['opportunities']),
          lifeGoingWell: _intOrNull(item['lifeGoingWell']),
          happy: _intOrNull(item['happy']),
          positiveFuture: _intOrNull(item['positiveFuture']),
          hasAnotherChild: _text(item['hasAnotherChild']),
        ));
      }
    }
  }

  int? _intOrNull(dynamic value) => value == null ? null : int.tryParse(value.toString());

  void _loadDomain({required Map<String, dynamic> payload, required String key, required void Function(String value) ratingSetter, required TextEditingController observations, required TextEditingController strengths, required TextEditingController challenges}) {
    final domain = (payload[key] ?? {}) as Map<String, dynamic>;
    ratingSetter(_text(domain['rating']));
    observations.text = _text(domain['observations']);
    strengths.text = _text(domain['strengths']);
    challenges.text = _text(domain['challenges']);
  }

  Map<String, dynamic> _domainPayload({String rating = '', required TextEditingController observations, required TextEditingController strengths, required TextEditingController challenges}) {
    return {
      'rating': rating,
      'observations': observations.text.trim(),
      'strengths': strengths.text.trim(),
      'challenges': challenges.text.trim(),
    };
  }

  Map<String, dynamic> _payload(String status) {
    return {
      'eventId': _eventId,
      'parentCaseId': _parentCaseId,
      'eventDate': _eventDateController.text.trim(),
      'status': status,
      'clientTei': _clientTei,
      'householdTei': _householdTei,
      'part1': {
        'intro': 'This form is completed for all clients who have been assessed using the intake and risk assessment form and have been assigned to a social worker for protective services.',
        'socialWorkerFirstName': _socialWorkerFirstNameController.text.trim(),
        'socialWorkerSurname': _socialWorkerSurnameController.text.trim(),
        'socialWorkerPhone': _socialWorkerPhoneController.text.trim(),
        'supervisorFirstName': _supervisorFirstNameController.text.trim(),
        'supervisorSurname': _supervisorSurnameController.text.trim(),
        'supervisorPhone': _supervisorPhoneController.text.trim(),
        'householdSummary': {
          'tei': _householdTei,
          'fileNumber': _householdFileNumberController.text.trim(),
          'district': _householdDistrictController.text.trim(),
          'communityCouncil': _householdCommunityCouncilController.text.trim(),
          'village': _householdVillageController.text.trim(),
          'physicalAddress': _householdAddressController.text.trim(),
        },
        'clientAndFamilySummary': _familyMembers.map((member) => member.toJson()).toList(),
      },
      'part2': {
        'incidentPattern': _incidentPattern,
        'specificIncidentDate': _specificIncidentDateController.text.trim(),
        'ongoingStartDate': _ongoingStartDateController.text.trim(),
        'incidentDistrict': _incidentDistrictController.text.trim(),
        'incidentCommunityCouncil': _incidentCommunityCouncilController.text.trim(),
        'village': _incidentVillageController.text.trim(),
        'notes': _ongoingNotesController.text.trim(),
      },
      'part3': {
        'changedSinceInitialAssessment': _changedSinceInitialAssessment,
        'changeReason': _changesSinceInitialReasonController.text.trim(),
        'additionalObservations': _changesSinceInitialObservationsController.text.trim(),
        'physicalHealth': _domainPayload(rating: _physicalHealthRating, observations: _physicalHealthObservationsController, strengths: _physicalHealthStrengthsController, challenges: _physicalHealthChallengesController),
        'emotionalHealth': _domainPayload(rating: _emotionalHealthRating, observations: _emotionalHealthObservationsController, strengths: _emotionalHealthStrengthsController, challenges: _emotionalHealthChallengesController),
        'education': _domainPayload(rating: _educationRating, observations: _educationObservationsController, strengths: _educationStrengthsController, challenges: _educationChallengesController),
        'behaviouralDevelopment': _domainPayload(observations: _behaviouralObservationsController, strengths: _behaviouralStrengthsController, challenges: _behaviouralChallengesController),
        'identity': _domainPayload(observations: _identityObservationsController, strengths: _identityStrengthsController, challenges: _identityChallengesController),
        'familyBackground': _domainPayload(rating: _familyBackgroundRating, observations: _familyBackgroundObservationsController, strengths: _familyBackgroundStrengthsController, challenges: _familyBackgroundChallengesController),
        'caregiverWellbeing': _domainPayload(rating: _caregiverWellbeingRating, observations: _caregiverWellbeingObservationsController, strengths: _caregiverWellbeingStrengthsController, challenges: _caregiverWellbeingChallengesController),
        'extendedFamily': _domainPayload(rating: _extendedFamilyRating, observations: _extendedFamilyObservationsController, strengths: _extendedFamilyStrengthsController, challenges: _extendedFamilyChallengesController),
        'parentSiblingRelationship': _domainPayload(rating: _parentSiblingRelationshipRating, observations: _parentSiblingObservationsController, strengths: _parentSiblingStrengthsController, challenges: _parentSiblingChallengesController),
        'peerRelationship': _domainPayload(observations: _peerRelationshipObservationsController, strengths: _peerRelationshipStrengthsController, challenges: _peerRelationshipChallengesController),
        'alternativeCare': _domainPayload(observations: _alternativeCareObservationsController, strengths: _alternativeCareStrengthsController, challenges: _alternativeCareChallengesController),
        'housing': _domainPayload(rating: _housingRating, observations: _housingObservationsController, strengths: _housingStrengthsController, challenges: _housingChallengesController),
        'socialInclusion': _domainPayload(rating: _socialInclusionRating, observations: _socialInclusionObservationsController, strengths: _socialInclusionStrengthsController, challenges: _socialInclusionChallengesController),
      },
      'part4': {
        'overallSafety': _childOverallSafetyController.text.trim(),
        'carePreference': _childCarePreferenceController.text.trim(),
        'futureSafetyIdeas': _childFutureSafetyIdeasController.text.trim(),
        'communicationConsiderations': _childCommunicationConsiderationsController.text.trim(),
      },
      'childWellbeing': _childWellbeingEntries.where((entry) => entry.hasAnyData).map((entry) => entry.toJson()).toList(),
    };
  }
  Future<void> _saveHouseholdEditsToTei(Database db) async {
    if (_householdTei.trim().isEmpty) return;

    await _saveAttr(db, _householdTei, MgysdDhis2Uids.attHouseholdFileNumber, _householdFileNumberController.text);
    await _saveAttr(db, _householdTei, MgysdDhis2Uids.attHouseholdDistrict, _householdDistrictController.text);
    await _saveAttr(db, _householdTei, MgysdDhis2Uids.attHouseholdCommunityCouncil, _householdCommunityCouncilController.text);
    await _saveAttr(db, _householdTei, MgysdDhis2Uids.attHouseholdVillage, _householdVillageController.text);
    await _saveAttr(db, _householdTei, MgysdDhis2Uids.attHouseholdAddress, _householdAddressController.text);
  }

  Future<void> _saveSummaryEditsToIntakeTeis(Database db) async {
    await _saveHouseholdEditsToTei(db);

    for (final member in _familyMembers) {
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attFirstName, member.controllers['firstName']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attLastName, member.controllers['surname']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attDob, member.controllers['dob']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attAge, member.controllers['age']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attSex, member.controllers['sex']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attPhone, member.controllers['phone']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attAlternativePhone, member.controllers['alternativePhone']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attOccupation, member.controllers['occupation']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attRelationshipToClient, member.controllers['relationshipToClient']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attHasDisability, member.controllers['hasDisability']?.text ?? '');
      await _saveAttr(db, member.tei, MgysdDhis2Uids.attDisabilitySpecify, member.controllers['disabilitySpecify']?.text ?? '');
      if (member.isPrimaryClient) {
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attClientCategory, member.controllers['clientCategory']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attIdentityNumber, member.controllers['identityNumber']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attNationality, member.controllers['nationality']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attHomeLanguage, member.controllers['homeLanguage']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attIsClientInSchool, member.controllers['isClientInSchool']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attSchoolName, member.controllers['schoolName']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attGrade, member.controllers['grade']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attSchoolAttendanceStatus, member.controllers['schoolAttendanceStatus']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attIsAdultEmployed, member.controllers['isAdultEmployed']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attEmployerName, member.controllers['employerName']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attFatherAlive, member.controllers['fatherAlive']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attFatherLivingWithChild, member.controllers['fatherLivingWithChild']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attFatherWhyNotLiving, member.controllers['fatherWhyNotLiving']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attMotherAlive, member.controllers['motherAlive']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attMotherLivingWithChild, member.controllers['motherLivingWithChild']?.text ?? '');
        await _saveAttr(db, member.tei, MgysdDhis2Uids.attMotherWhyNotLiving, member.controllers['motherWhyNotLiving']?.text ?? '');
      }
    }
  }

  Future<void> _saveAttr(Database db, String tei, String attribute, String value) async {
    final v = value.trim();
    if (tei.trim().isEmpty || attribute.trim().isEmpty) return;
    final existing = await db.query(
      'tracked_entity_instance_attribute',
      columns: ['id'],
      where: 'trackedEntityInstance = ? AND attribute = ?',
      whereArgs: [tei, attribute],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update('tracked_entity_instance_attribute', {'value': v}, where: 'trackedEntityInstance = ? AND attribute = ?', whereArgs: [tei, attribute]);
    } else if (v.isNotEmpty) {
      await db.insert('tracked_entity_instance_attribute', {'id': AppUtil.getUid(), 'trackedEntityInstance': tei, 'attribute': attribute, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    try {
      await db.update('tracked_entity_instance', {'syncStatus': 'not-synced'}, where: 'trackedEntityInstance = ?', whereArgs: [tei]);
    } catch (_) {}
  }

  Future<void> _saveProgramStageEventRow({required Database db, required String status, required String eventDate}) async {
    await db.insert(
      'events',
      {
        'id': _eventId,
        'event': _eventId,
        'eventDate': eventDate,
        'program': MgysdDhis2Uids.caseManagementTrackerProgram,
        'programStage': MgysdDhis2Uids.socialInvestigationStage,
        'trackedEntityInstance': _eventOwnerTei,
        'status': status,
        'orgUnit': _caseOrgUnit,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    try {
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      return rows.any((row) => (row['name'] ?? '').toString() == column);
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureCarePlanLinkColumns(Database db) async {
    final columns = <String, String>{
      'socialInvestigationId': "ALTER TABLE mgysd_care_plan ADD COLUMN socialInvestigationId TEXT DEFAULT ''",
      'carePlanStatus': "ALTER TABLE mgysd_care_plan ADD COLUMN carePlanStatus TEXT DEFAULT ''",
      'createdAt': "ALTER TABLE mgysd_care_plan ADD COLUMN createdAt TEXT DEFAULT ''",
      'syncStatus': "ALTER TABLE mgysd_care_plan ADD COLUMN syncStatus TEXT DEFAULT 'not-synced'",
    };

    for (final entry in columns.entries) {
      if (!await _columnExists(db, 'mgysd_care_plan', entry.key)) {
        try {
          await db.execute(entry.value);
        } catch (_) {}
      }
    }
  }

  Future<void> _ensureCarePlanForSocialInvestigation(Database db, String status) async {
    if (status != 'COMPLETED') return;

    await _ensureCarePlanLinkColumns(db);

    final nowIso = DateTime.now().toIso8601String();
    final carePlanId = 'CP_$_eventId';

    final existing = await db.query(
      'mgysd_care_plan',
      columns: ['id'],
      where: 'socialInvestigationId = ? OR id = ?',
      whereArgs: [_eventId, carePlanId],
      limit: 1,
    );

    if (existing.isNotEmpty) return;

    final payload = {
      'carePlanId': carePlanId,
      'socialInvestigationId': _eventId,
      'caseId': _parentCaseId,
      'householdTei': _householdTei,
      'status': 'ACTIVE',
      'createdFrom': 'social_investigation',
      'createdAt': nowIso,
    };

    await db.insert(
      'mgysd_care_plan',
      {
        'id': carePlanId,
        'caseId': _parentCaseId,
        'householdTei': _householdTei,
        'planDate': _eventDateController.text.trim().isNotEmpty ? _eventDateController.text.trim() : _today(),
        'status': 'DRAFT',
        'carePlanStatus': 'ACTIVE',
        'socialInvestigationId': _eventId,
        'payloadJson': jsonEncode(payload),
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventOwnerTei.isEmpty) {
      _showSnack('Household/client TEI not found. Please refresh the case and try again.');
      return;
    }
    if (_caseOrgUnit.isEmpty) {
      _showSnack('Case org unit not found. Please check the intake case.');
      return;
    }
    if (_incidentPattern.isEmpty) {
      _showSnack('Please select whether the concern is specific or ongoing.');
      return;
    }
    setState(() => _saving = true);
    try {
      final db = await _db();
      final nowIso = DateTime.now().toIso8601String();
      final eventDate = _eventDateController.text.trim().isNotEmpty ? _eventDateController.text.trim() : _today();
      await _saveSummaryEditsToIntakeTeis(db);
      await _saveProgramStageEventRow(db: db, status: status, eventDate: eventDate);
      await db.insert(
        _tableName,
        {
          'id': _eventId,
          'caseId': _eventId,
          'parentCaseId': _parentCaseId,
          'rootCaseId': _parentCaseId,
          'householdTei': _householdTei,
          'investigationDate': eventDate,
          'stageKey': _stageKey,
          'status': status,
          'payloadJson': jsonEncode(_payload(status)),
          'syncStatus': 'not-synced',
          'updatedAt': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _ensureCarePlanForSocialInvestigation(db, status);

      if (!mounted) return;
      setState(() => _savedStatus = status);
      _showSnack(status == 'COMPLETED' ? 'Social Investigation completed.' : 'Social Investigation saved as draft.');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Failed to save Social Investigation: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addChildWellbeingEntry() {
    setState(() {
      _showChildWellbeingIndicators = true;
      _childWellbeingEntries.add(_ChildWellbeingEntry(id: AppUtil.getUid(), date: _today()));
    });
  }

  void _removeChildWellbeingEntry(int index) {
    setState(() {
      final item = _childWellbeingEntries.removeAt(index);
      item.dispose();
      if (_childWellbeingEntries.isEmpty) {
        _showChildWellbeingIndicators = false;
      }
    });
  }

  void _addChildVoiceSection() {
    setState(() => _showChildVoiceSection = true);
  }

  void _removeChildVoiceSection() {
    setState(() {
      _showChildVoiceSection = false;
      _childOverallSafetyController.clear();
      _childCarePreferenceController.clear();
      _childFutureSafetyIdeasController.clear();
      _childCommunicationConsiderationsController.clear();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _labelFor(String code, Map<String, String> labels) => labels[code] ?? code;

  Widget _surface({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: widget.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.assignment_outlined, color: widget.color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15.8, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.blueGrey, height: 1.35, fontSize: 12.5)),
          ])),
        ],
      ),
    );
  }

  Widget _input(TextEditingController controller, String label, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, bool readOnly = false, VoidCallback? onTap, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF9FBFD), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      ),
    );
  }

  Widget _dropdown({required String label, required String value, required List<String> options, required void Function(String value) onChanged, Map<String, String>? labels, bool requiredField = false}) {
    final safeValue = options.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        items: options.map((option) => DropdownMenuItem<String>(value: option, child: Text(labels == null ? option : _labelFor(option, labels), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
        validator: (v) { if (!requiredField) return null; if ((v ?? '').trim().isEmpty) return 'Required'; return null; },
        decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF9FBFD), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      ),
    );
  }


  Widget _controllerDropdown({
    required TextEditingController controller,
    required String label,
    required List<String> options,
    required Map<String, String> labels,
    bool requiredField = false,
  }) {
    final value = options.contains(controller.text.trim()) ? controller.text.trim() : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        items: options
            .map((option) => DropdownMenuItem<String>(
          value: option,
          child: Text(labels[option] ?? option, overflow: TextOverflow.ellipsis),
        ))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() => controller.text = v);
        },
        validator: (v) {
          if (!requiredField) return null;
          if ((v ?? '').trim().isEmpty) return 'Required';
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF9FBFD),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _orgUnitDropdown({
    required TextEditingController controller,
    required String label,
    required List<_OrgUnitOption> options,
    bool requiredField = false,
    VoidCallback? afterChanged,
  }) {
    final current = controller.text.trim();
    String? value;
    for (final item in options) {
      if (item.id == current || item.name.toLowerCase() == current.toLowerCase()) {
        value = item.name;
        break;
      }
    }

    if (options.isEmpty) {
      return _input(controller, label, validator: requiredField ? (v) => (v ?? '').trim().isEmpty ? 'Required' : null : null);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        items: options
            .map((option) => DropdownMenuItem<String>(
          value: option.name,
          child: Text(option.name, overflow: TextOverflow.ellipsis),
        ))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            controller.text = v;
            if (afterChanged != null) afterChanged();
          });
        },
        validator: (v) {
          if (!requiredField) return null;
          if ((v ?? '').trim().isEmpty) return 'Required';
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF9FBFD),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _two(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 620) return Column(children: [a, b]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    });
  }
  Widget _statusChip() {
    Color color = Colors.blueGrey;
    String label = 'Not started';
    if (_savedStatus == 'DRAFT') { color = Colors.orange; label = 'Draft'; }
    else if (_savedStatus == 'COMPLETED') { color = Colors.green; label = 'Completed'; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(999)), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)));
  }

  Widget _header() {
    final clientName = (widget.clientName ?? widget.mgysdCase.fullName).trim();
    return _surface(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 24, backgroundColor: widget.color.withOpacity(0.12), child: Icon(Icons.fact_check_outlined, color: widget.color)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(clientName.isEmpty ? widget.mgysdCase.caseNo : clientName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Case: ${widget.mgysdCase.caseNo}', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
        if ((widget.householdName ?? '').trim().isNotEmpty) Text('Household: ${widget.householdName}', style: const TextStyle(color: Colors.blueGrey)),
      ])),
      _statusChip(),
    ]));
  }

  Widget _part1() {
    return _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Part 1: Summary Data', 'This form is completed for all clients who have been assessed using the intake and risk assessment form and have been assigned to a social worker for protective services.'),
      _two(
        _input(_socialWorkerFirstNameController, 'Name of Social Worker Allocated to case', readOnly: true, validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
        _input(_socialWorkerSurnameController, 'Surname of Social Worker Allocated to case', readOnly: true, validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
      ),
      _input(_socialWorkerPhoneController, 'Phone Number of Social Worker Allocated to case', keyboardType: TextInputType.phone, readOnly: true),
      _two(_input(_supervisorFirstNameController, "Name of Social Worker's Supervisor"), _input(_supervisorSurnameController, "Surname of Social Worker's Supervisor")),
      _input(_supervisorPhoneController, "Phone Number of Social Worker's Supervisor", keyboardType: TextInputType.phone),
      const SizedBox(height: 10),
      _householdSummaryCard(),
      const SizedBox(height: 10),
      const Text('Summary Information on Client and Family', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      ..._familyMembers.map(_personSummaryCard).toList(),
    ]));
  }

  Widget _householdSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.045),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: widget.color.withOpacity(0.16)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 10),
        leading: CircleAvatar(
          backgroundColor: widget.color.withOpacity(0.12),
          child: Icon(Icons.home_work_outlined, color: widget.color),
        ),
        title: const Text(
          'Household Information',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Editable household registration and location details'),
        children: [
          _input(_householdFileNumberController, 'File Number'),
          _two(
            _orgUnitDropdown(
              controller: _householdDistrictController,
              label: 'District / Org Unit',
              options: _districtOrgUnits,
              afterChanged: () => _householdCommunityCouncilController.clear(),
            ),
            _orgUnitDropdown(
              controller: _householdCommunityCouncilController,
              label: 'Community Council / Org Unit',
              options: _communityCouncilsFor(_householdDistrictController.text),
            ),
          ),
          _input(_householdVillageController, 'Village'),
          _input(_householdAddressController, 'Physical Address', maxLines: 3),
        ],
      ),
    );
  }

  Widget _personSummaryCard(_PersonSummary member) {
    final title = member.isPrimaryClient ? 'Client' : member.role;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: member.isPrimaryClient ? widget.color.withOpacity(0.045) : const Color(0xFFF9FBFD), borderRadius: BorderRadius.circular(15), border: Border.all(color: member.isPrimaryClient ? widget.color.withOpacity(0.16) : Colors.blueGrey.withOpacity(0.10))),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 10),
        title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(title),
        children: [
          _two(
            _input(member.controllers['firstName']!, 'First Name', validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
            _input(member.controllers['surname']!, 'Surname', validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          ),
          _two(
            _input(member.controllers['dob']!, 'Date of Birth', readOnly: true, onTap: () => _pickDobAndCalculateAge(member), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
            _input(member.controllers['age']!, 'Age', keyboardType: TextInputType.number, readOnly: true),
          ),
          _two(
            _controllerDropdown(controller: member.controllers['sex']!, label: 'Sex', options: _sexOptions, labels: _sexLabels, requiredField: true),
            _input(member.controllers['phone']!, 'Phone Number', keyboardType: TextInputType.phone),
          ),
          _input(member.controllers['alternativePhone']!, 'Alternative Phone Number', keyboardType: TextInputType.phone),
          _two(
            _input(member.controllers['occupation']!, 'Occupation'),
            _controllerDropdown(controller: member.controllers['relationshipToClient']!, label: 'Relationship to Client', options: _relationshipToClientOptions, labels: _relationshipToClientLabels, requiredField: true),
          ),
          _two(
            _controllerDropdown(controller: member.controllers['hasDisability']!, label: 'Disability', options: _disabilityOptions, labels: _yesNoLabels, requiredField: true),
            _input(member.controllers['disabilitySpecify']!, 'Disability Specify', maxLines: 2),
          ),
          if (member.isPrimaryClient) ...[
            _two(
              _controllerDropdown(controller: member.controllers['clientCategory']!, label: 'Client Category', options: _clientCategoryOptions, labels: _clientCategoryLabels),
              _input(member.controllers['identityNumber']!, 'Identity Number'),
            ),
            _two(
              _controllerDropdown(controller: member.controllers['nationality']!, label: 'Nationality', options: _nationalityOptions, labels: _nationalityLabels, requiredField: true),
              _controllerDropdown(controller: member.controllers['homeLanguage']!, label: 'Home Language', options: _homeLanguageOptions, labels: _homeLanguageLabels, requiredField: true),
            ),
            _two(
              _controllerDropdown(controller: member.controllers['isClientInSchool']!, label: 'Is Client in School?', options: _yesNoOptions, labels: _yesNoLabels),
              _input(member.controllers['schoolName']!, 'Name of School'),
            ),
            _two(
              _controllerDropdown(controller: member.controllers['grade']!, label: 'Grade', options: _gradeOptions, labels: const {}),
              _controllerDropdown(controller: member.controllers['schoolAttendanceStatus']!, label: 'School Attendance Status', options: _schoolAttendanceOptions, labels: _schoolAttendanceLabels),
            ),
            _two(
              _controllerDropdown(controller: member.controllers['isAdultEmployed']!, label: 'Is Adult Employed?', options: _yesNoOptions, labels: _yesNoLabels),
              _input(member.controllers['employerName']!, 'Employer Name'),
            ),
            const Divider(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text('Father / Mother Intake Status', style: TextStyle(fontWeight: FontWeight.w900))),
            const SizedBox(height: 8),
            _two(
              _controllerDropdown(controller: member.controllers['fatherAlive']!, label: 'Is Father Alive?', options: _aliveOptions, labels: _aliveLabels),
              _controllerDropdown(controller: member.controllers['fatherLivingWithChild']!, label: 'Is Father Living with Child?', options: _aliveOptions, labels: _aliveLabels),
            ),
            _input(member.controllers['fatherWhyNotLiving']!, 'Why is Father not living with Child?', maxLines: 2),
            _two(
              _controllerDropdown(controller: member.controllers['motherAlive']!, label: 'Is Mother Alive?', options: _aliveOptions, labels: _aliveLabels),
              _controllerDropdown(controller: member.controllers['motherLivingWithChild']!, label: 'Is Mother Living with Child?', options: _aliveOptions, labels: _aliveLabels),
            ),
            _input(member.controllers['motherWhyNotLiving']!, 'Why is Mother not living with Child?', maxLines: 2),
          ],
        ],
      ),
    );
  }

  Widget _part2() {
    return _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Part 2: Case Details', 'Capture whether the incident was specific or long-term, including location and notes.'),
      _input(_eventDateController, 'Investigation Event Date', readOnly: true, onTap: () => _pickDate(_eventDateController), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
      _dropdown(label: 'Did the violation/incident take place on a specific day or is it a long-term / ongoing concern?', value: _incidentPattern, options: _incidentPatternOptions, labels: _incidentPatternLabels, requiredField: true, onChanged: (v) => setState(() => _incidentPattern = v)),
      if (_incidentPattern == 'SPECIFIC_DAY') _input(_specificIncidentDateController, 'Date of Incident', readOnly: true, onTap: () => _pickDate(_specificIncidentDateController)),
      if (_incidentPattern == 'LONG_TERM_ONGOING') _input(_ongoingStartDateController, 'Date when the problem started', readOnly: true, onTap: () => _pickDate(_ongoingStartDateController)),
      _two(_input(_incidentDistrictController, 'Location: District'), _input(_incidentCommunityCouncilController, 'Location: Community Council')),
      _input(_incidentVillageController, 'Village'),
      if (_incidentPattern == 'LONG_TERM_ONGOING') _input(_ongoingNotesController, 'Notes', maxLines: 4),
    ]));
  }

  Widget _domainSection({required String title, required String subtitle, required String rating, required List<String> options, required Map<String, String> labels, required void Function(String value) onRatingChanged, required TextEditingController observations, required TextEditingController strengths, required TextEditingController challenges}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FBFD), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueGrey.withOpacity(0.10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14.8, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.blueGrey, height: 1.35, fontSize: 12)),
        const SizedBox(height: 10),
        _dropdown(label: '$title rating', value: rating, options: options, labels: labels, onChanged: onRatingChanged),
        _input(observations, 'Observations / notes', maxLines: 4),
        _two(_input(strengths, 'Strengths', maxLines: 3), _input(challenges, 'Challenges', maxLines: 3)),
      ]),
    );
  }

  Widget _narrativeDomain({required String title, required String subtitle, required TextEditingController observations, required TextEditingController strengths, required TextEditingController challenges}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FBFD), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueGrey.withOpacity(0.10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14.8, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.blueGrey, height: 1.35, fontSize: 12)),
        const SizedBox(height: 10),
        _input(observations, 'Observations / notes', maxLines: 4),
        _two(_input(strengths, 'Strengths', maxLines: 3), _input(challenges, 'Challenges', maxLines: 3)),
      ]),
    );
  }

  Widget _part3() {
    return _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Part 3: Social Investigation', 'Record amendments to intake data and comprehensive information about risks, strengths, opportunities and desired wellbeing outcomes.'),
      _dropdown(label: 'Has the assessment changed since initial assessment?', value: _changedSinceInitialAssessment, options: _yesNoOptions, onChanged: (v) => setState(() => _changedSinceInitialAssessment = v)),
      _input(_changesSinceInitialReasonController, 'Reason for any change from initial assessment', maxLines: 3),
      _input(_changesSinceInitialObservationsController, 'Additional observations', maxLines: 3),
      _domainSection(title: 'Client physical health', subtitle: 'Client access to health information and services, caregiver input, disability/rehabilitation barriers and support.', rating: _physicalHealthRating, options: _physicalHealthOptions, labels: _physicalHealthLabels, onRatingChanged: (v) => setState(() => _physicalHealthRating = v), observations: _physicalHealthObservationsController, strengths: _physicalHealthStrengthsController, challenges: _physicalHealthChallengesController),
      _domainSection(title: 'Client emotional health', subtitle: 'Emotional wellbeing, support, stressors, distress and protective factors.', rating: _emotionalHealthRating, options: _emotionalHealthOptions, labels: _emotionalHealthLabels, onRatingChanged: (v) => setState(() => _emotionalHealthRating = v), observations: _emotionalHealthObservationsController, strengths: _emotionalHealthStrengthsController, challenges: _emotionalHealthChallengesController),
      _domainSection(title: 'Education', subtitle: 'Client and caregiver expectations, education support, learning development and barriers.', rating: _educationRating, options: _educationOptions, labels: _educationLabels, onRatingChanged: (v) => setState(() => _educationRating = v), observations: _educationObservationsController, strengths: _educationStrengthsController, challenges: _educationChallengesController),
      _narrativeDomain(title: 'Emotional and behavioural development', subtitle: 'Attachments, discipline, guidance, feelings, behaviour, and support from family members.', observations: _behaviouralObservationsController, strengths: _behaviouralStrengthsController, challenges: _behaviouralChallengesController),
      _narrativeDomain(title: 'Identity', subtitle: 'Self-image, self-esteem, confidence, goals, aspirations, risk awareness and daily activities.', observations: _identityObservationsController, strengths: _identityStrengthsController, challenges: _identityChallengesController),
      _domainSection(title: 'Family background and composition', subtitle: 'Household composition, changes, disruption, risks, caring adults and economic support potential.', rating: _familyBackgroundRating, options: _familyBackgroundOptions, labels: _familyBackgroundLabels, onRatingChanged: (v) => setState(() => _familyBackgroundRating = v), observations: _familyBackgroundObservationsController, strengths: _familyBackgroundStrengthsController, challenges: _familyBackgroundChallengesController),
      _domainSection(title: 'Parent / caregiver / guardian health and wellbeing', subtitle: 'Health issues affecting capacity to protect and care for the client.', rating: _caregiverWellbeingRating, options: _caregiverWellbeingOptions, labels: _caregiverWellbeingLabels, onRatingChanged: (v) => setState(() => _caregiverWellbeingRating = v), observations: _caregiverWellbeingObservationsController, strengths: _caregiverWellbeingStrengthsController, challenges: _caregiverWellbeingChallengesController),
      _domainSection(title: 'Extended family relationships', subtitle: 'Extended family support, tensions, family mechanisms and positive role models.', rating: _extendedFamilyRating, options: _relationshipOptions, labels: _relationshipLabels, onRatingChanged: (v) => setState(() => _extendedFamilyRating = v), observations: _extendedFamilyObservationsController, strengths: _extendedFamilyStrengthsController, challenges: _extendedFamilyChallengesController),
      _domainSection(title: 'Client relationships with parents and siblings', subtitle: 'Care and support from parents/siblings, relationship stress, non-biological parents and sources of support.', rating: _parentSiblingRelationshipRating, options: _parentSiblingRelationshipOptions, labels: _parentSiblingRelationshipLabels, onRatingChanged: (v) => setState(() => _parentSiblingRelationshipRating = v), observations: _parentSiblingObservationsController, strengths: _parentSiblingStrengthsController, challenges: _parentSiblingChallengesController),
      _narrativeDomain(title: 'Client relationship with peers and community', subtitle: 'Friendships, bullying, safe places, church/youth/community involvement and livelihood context.', observations: _peerRelationshipObservationsController, strengths: _peerRelationshipStrengthsController, challenges: _peerRelationshipChallengesController),
      _narrativeDomain(title: 'Client relationships if in alternative care', subtitle: 'Caregiving changes, permanency plan, voice in living arrangements and wellbeing impacts.', observations: _alternativeCareObservationsController, strengths: _alternativeCareStrengthsController, challenges: _alternativeCareChallengesController),
      _domainSection(title: 'Housing and environmental safety', subtitle: 'Housing type, safety, space, environment, recreation and accessibility.', rating: _housingRating, options: _housingOptions, labels: _housingLabels, onRatingChanged: (v) => setState(() => _housingRating = v), observations: _housingObservationsController, strengths: _housingStrengthsController, challenges: _housingChallengesController),
      _domainSection(title: 'Social, religious and cultural inclusion', subtitle: 'Community/religious interaction, social isolation, stigma and sources of community support.', rating: _socialInclusionRating, options: _socialInclusionOptions, labels: _socialInclusionLabels, onRatingChanged: (v) => setState(() => _socialInclusionRating = v), observations: _socialInclusionObservationsController, strengths: _socialInclusionStrengthsController, challenges: _socialInclusionChallengesController),
    ]));
  }
  Widget _optionalAddCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onAdd,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: widget.color.withOpacity(0.12),
            child: Icon(icon, color: widget.color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12.4,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color.withOpacity(0.45)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _part4() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Part 4: Child Participation',
            'Only add these sections when they are relevant and the child can safely participate. Child Wellbeing Indicators come before Child Voice.',
          ),
          if (!_showChildWellbeingIndicators)
            _optionalAddCard(
              title: 'Child Wellbeing Indicators',
              subtitle: 'Add scoring indicators when you want to capture the child wellbeing scale.',
              icon: Icons.monitor_heart_outlined,
              onAdd: _addChildWellbeingEntry,
            ),
          if (_showChildWellbeingIndicators) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Child Wellbeing Indicators',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addChildWellbeingEntry,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add child'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(
              _childWellbeingEntries.length,
                  (index) => _childWellbeingCard(index, _childWellbeingEntries[index]),
            ),
            const SizedBox(height: 12),
          ],
          if (!_showChildVoiceSection)
            _optionalAddCard(
              title: "Child's Voice",
              subtitle: 'Add this when the child has been consulted and it is appropriate to record their views.',
              icon: Icons.record_voice_over_outlined,
              onAdd: _addChildVoiceSection,
            ),
          if (_showChildVoiceSection) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFD),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Child's Voice",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: _removeChildVoiceSection,
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _input(_childOverallSafetyController, 'Overall sense of safety', maxLines: 3),
                  _input(_childCarePreferenceController, 'Who the child wants to be cared for by', maxLines: 3),
                  _input(_childFutureSafetyIdeasController, 'Ideas for how to stay safe and make things good in the future', maxLines: 4),
                  _input(_childCommunicationConsiderationsController, 'Communication considerations', maxLines: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreDropdown({required String label, required int? value, required void Function(int? value) onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<int>(
        value: value,
        isExpanded: true,
        items: [1, 2, 3, 4, 5].map((score) => DropdownMenuItem<int>(value: score, child: Text('$score'))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, helperText: '1 Never / not at all • 5 Always', filled: true, fillColor: const Color(0xFFF9FBFD), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      ),
    );
  }

  Widget _childWellbeingCard(int index, _ChildWellbeingEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FBFD), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueGrey.withOpacity(0.10))),
      child: Column(children: [
        Row(children: [Expanded(child: Text('Child Wellbeing Entry ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900))), IconButton(onPressed: () => _removeChildWellbeingEntry(index), icon: const Icon(Icons.delete_outline), color: Colors.redAccent)]),
        _two(_input(entry.childNameController, 'Child name'), _input(entry.dateController, 'Date', readOnly: true, onTap: () => _pickDate(entry.dateController))),
        _scoreDropdown(label: 'I feel safe at home', value: entry.safeAtHome, onChanged: (v) => setState(() => entry.safeAtHome = v)),
        _scoreDropdown(label: 'My parents / people who look after me listen to me', value: entry.listenedTo, onChanged: (v) => setState(() => entry.listenedTo = v)),
        _scoreDropdown(label: 'My parents / people who look after me treat me fairly', value: entry.treatedFairly, onChanged: (v) => setState(() => entry.treatedFairly = v)),
        _two(_scoreDropdown(label: 'Talking together', value: entry.talkingTogether, onChanged: (v) => setState(() => entry.talkingTogether = v)), _scoreDropdown(label: 'Having fun together', value: entry.havingFunTogether, onChanged: (v) => setState(() => entry.havingFunTogether = v))),
        _scoreDropdown(label: 'Learning together', value: entry.learningTogether, onChanged: (v) => setState(() => entry.learningTogether = v)),
        _two(_scoreDropdown(label: 'I have at least one good friend', value: entry.goodFriend, onChanged: (v) => setState(() => entry.goodFriend = v)), _scoreDropdown(label: 'My friends are usually nice to me', value: entry.friendsNice, onChanged: (v) => setState(() => entry.friendsNice = v))),
        _two(_scoreDropdown(label: 'I enjoy school', value: entry.enjoySchool, onChanged: (v) => setState(() => entry.enjoySchool = v)), _scoreDropdown(label: 'I feel safe and supported at school', value: entry.safeAtSchool, onChanged: (v) => setState(() => entry.safeAtSchool = v))),
        _two(_scoreDropdown(label: 'I like the way I look', value: entry.likeLooks, onChanged: (v) => setState(() => entry.likeLooks = v)), _scoreDropdown(label: 'I feel self-confident', value: entry.selfConfident, onChanged: (v) => setState(() => entry.selfConfident = v))),
        _scoreDropdown(label: 'I have opportunities to improve my life', value: entry.opportunities, onChanged: (v) => setState(() => entry.opportunities = v)),
        _two(_scoreDropdown(label: 'My life is going well', value: entry.lifeGoingWell, onChanged: (v) => setState(() => entry.lifeGoingWell = v)), _scoreDropdown(label: 'I am happy', value: entry.happy, onChanged: (v) => setState(() => entry.happy = v))),
        _scoreDropdown(label: 'I feel positive about my future', value: entry.positiveFuture, onChanged: (v) => setState(() => entry.positiveFuture = v)),
        _dropdown(label: 'Is there any other child in the family?', value: entry.hasAnotherChild, options: _yesNoOptions, onChanged: (v) => setState(() => entry.hasAnotherChild = v)),
        _input(entry.notesController, 'Notes / comments', maxLines: 4),
      ]),
    );
  }

  Widget _actions() {
    return Row(children: [
      Expanded(child: OutlinedButton(onPressed: _saving ? null : () => _save('DRAFT'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: widget.color), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), child: const Text('Save Draft'))),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton(onPressed: _saving ? null : () => _save('COMPLETED'), style: ElevatedButton.styleFrom(backgroundColor: widget.color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), child: Text(_saving ? 'Saving...' : 'Mark Complete'))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(backgroundColor: widget.color, title: const Text('Social Investigation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            _part1(),
            _part2(),
            _part3(),
            _part4(),
            _actions(),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}
