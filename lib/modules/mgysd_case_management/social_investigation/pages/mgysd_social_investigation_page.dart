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

class _ExternalInformantEntry {
  final String id;

  // Section B – Informant details
  final TextEditingController firstNameController;
  final TextEditingController surnameController;
  final TextEditingController ageController;
  String gender;
  String relationshipToClient;
  final TextEditingController relationshipToClientOtherController;
  String occupation;
  final TextEditingController occupationOtherController;
  String contactCountryCode;
  final TextEditingController contactCountryCodeOtherController;
  final TextEditingController contactNumberController;
  final TextEditingController physicalAddressController;

  // Section C – Purpose of interview
  final Set<String> purposeOfInterview;
  final TextEditingController purposeOfInterviewOtherController;

  // Section D – Knowledge of client
  String howLongKnown;
  final TextEditingController currentSituationUnderstandingController;
  bool showResponsibleForCare;
  final TextEditingController responsibleForCareFirstNameController;
  final TextEditingController responsibleForCareSurnameController;

  // Section E – Living conditions
  String housingConditionRating;
  final TextEditingController housingCommentsController;
  String basicNeedsRating;
  final TextEditingController basicNeedsDetailsController;
  String healthStatusRating;
  final TextEditingController healthStatusDetailsController;
  String accessHealthServices;
  final Set<String> healthServiceTypes;
  final TextEditingController healthServiceOtherController;
  String accessSocialSupport;
  final Set<String> socialSupportTypes;
  final TextEditingController socialSupportOtherController;
  String accessSchoolWork;
  final Set<String> schoolWorkTypes;
  final TextEditingController schoolWorkOtherController;
  final TextEditingController accessServicesCommentsController;

  // Section F – Safety
  final Set<String> abuseTypes;
  final TextEditingController abuseDetailsController;
  String signsOfNeglect;
  final Set<String> neglectTypes;
  final TextEditingController neglectTypeOtherController;
  final TextEditingController neglectDetailsController;
  final Set<String> riskFactors;
  final TextEditingController riskFactorOtherController;

  // Section G – Functioning
  final TextEditingController dailyFunctioningController;
  final Set<String> socialBehaviours;
  final TextEditingController behaviourCommentsController;

  // Section H – Social support
  String familySupportLevel;
  final TextEditingController familySupportExplainController;
  final TextEditingController communityPerceptionController;
  final TextEditingController knownHistoryController;

  // Section I – Opinions
  final TextEditingController keyChallengesController;
  final TextEditingController recommendationsController;

  // Section J – Reliability
  String informantCredibility;
  final TextEditingController credibilityReasonsController;

  // Section K – Social Worker Summary Notes
  final TextEditingController socialWorkerSummaryNotesController;

  // Section L – Risk Level Assessment
  String riskLevel;

  // Section M – Confidentiality: static text, no fields needed

  _ExternalInformantEntry({
    required this.id,
    String firstName = '',
    String surname = '',
    String age = '',
    this.gender = '',
    this.relationshipToClient = '',
    String relationshipToClientOther = '',
    this.occupation = '',
    String occupationOther = '',
    this.contactCountryCode = '',
    String contactCountryCodeOther = '',
    String contactNumber = '',
    String physicalAddress = '',
    Set<String>? purposeOfInterview,
    String purposeOfInterviewOther = '',
    this.howLongKnown = '',
    String currentSituationUnderstanding = '',
    bool? showResponsibleForCare,
    String responsibleForCareFirstName = '',
    String responsibleForCareSurname = '',
    this.housingConditionRating = '',
    String housingComments = '',
    this.basicNeedsRating = '',
    String basicNeedsDetails = '',
    this.healthStatusRating = '',
    String healthStatusDetails = '',
    this.accessHealthServices = '',
    Set<String>? healthServiceTypes,
    String healthServiceOther = '',
    this.accessSocialSupport = '',
    Set<String>? socialSupportTypes,
    String socialSupportOther = '',
    this.accessSchoolWork = '',
    Set<String>? schoolWorkTypes,
    String schoolWorkOther = '',
    String accessServicesComments = '',
    Set<String>? abuseTypes,
    String abuseDetails = '',
    this.signsOfNeglect = '',
    Set<String>? neglectTypes,
    String neglectTypeOther = '',
    String neglectDetails = '',
    Set<String>? riskFactors,
    String riskFactorOther = '',
    String dailyFunctioning = '',
    Set<String>? socialBehaviours,
    String behaviourComments = '',
    this.familySupportLevel = '',
    String familySupportExplain = '',
    String communityPerception = '',
    String knownHistory = '',
    String keyChallenges = '',
    String recommendations = '',
    this.informantCredibility = '',
    String credibilityReasons = '',
    String socialWorkerSummaryNotes = '',
    this.riskLevel = '',
  })  : firstNameController = TextEditingController(text: firstName),
        surnameController = TextEditingController(text: surname),
        ageController = TextEditingController(text: age),
        relationshipToClientOtherController = TextEditingController(text: relationshipToClientOther),
        occupationOtherController = TextEditingController(text: occupationOther),
        contactCountryCodeOtherController = TextEditingController(text: contactCountryCodeOther),
        contactNumberController = TextEditingController(text: contactNumber),
        physicalAddressController = TextEditingController(text: physicalAddress),
        purposeOfInterview = purposeOfInterview ?? {},
        purposeOfInterviewOtherController = TextEditingController(text: purposeOfInterviewOther),
        currentSituationUnderstandingController = TextEditingController(text: currentSituationUnderstanding),
        showResponsibleForCare = showResponsibleForCare ??
            (responsibleForCareFirstName.trim().isNotEmpty || responsibleForCareSurname.trim().isNotEmpty),
        responsibleForCareFirstNameController = TextEditingController(text: responsibleForCareFirstName),
        responsibleForCareSurnameController = TextEditingController(text: responsibleForCareSurname),
        housingCommentsController = TextEditingController(text: housingComments),
        basicNeedsDetailsController = TextEditingController(text: basicNeedsDetails),
        healthStatusDetailsController = TextEditingController(text: healthStatusDetails),
        healthServiceTypes = healthServiceTypes ?? {},
        healthServiceOtherController = TextEditingController(text: healthServiceOther),
        socialSupportTypes = socialSupportTypes ?? {},
        socialSupportOtherController = TextEditingController(text: socialSupportOther),
        schoolWorkTypes = schoolWorkTypes ?? {},
        schoolWorkOtherController = TextEditingController(text: schoolWorkOther),
        accessServicesCommentsController = TextEditingController(text: accessServicesComments),
        abuseTypes = abuseTypes ?? {},
        abuseDetailsController = TextEditingController(text: abuseDetails),
        neglectTypes = neglectTypes ?? {},
        neglectTypeOtherController = TextEditingController(text: neglectTypeOther),
        neglectDetailsController = TextEditingController(text: neglectDetails),
        riskFactors = riskFactors ?? {},
        riskFactorOtherController = TextEditingController(text: riskFactorOther),
        dailyFunctioningController = TextEditingController(text: dailyFunctioning),
        socialBehaviours = socialBehaviours ?? {},
        behaviourCommentsController = TextEditingController(text: behaviourComments),
        familySupportExplainController = TextEditingController(text: familySupportExplain),
        communityPerceptionController = TextEditingController(text: communityPerception),
        knownHistoryController = TextEditingController(text: knownHistory),
        keyChallengesController = TextEditingController(text: keyChallenges),
        recommendationsController = TextEditingController(text: recommendations),
        credibilityReasonsController = TextEditingController(text: credibilityReasons),
        socialWorkerSummaryNotesController = TextEditingController(text: socialWorkerSummaryNotes);

  String get fullName {
    final first = firstNameController.text.trim();
    final last = surnameController.text.trim();
    return ('$first $last').trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstNameController.text.trim(),
      'surname': surnameController.text.trim(),
      'age': ageController.text.trim(),
      'gender': gender,
      'relationshipToClient': relationshipToClient,
      'relationshipToClientOther': relationshipToClientOtherController.text.trim(),
      'occupation': occupation,
      'occupationOther': occupationOtherController.text.trim(),
      'contactCountryCode': contactCountryCode,
      'contactCountryCodeOther': contactCountryCodeOtherController.text.trim(),
      'contactNumber': contactNumberController.text.trim(),
      'physicalAddress': physicalAddressController.text.trim(),
      'purposeOfInterview': purposeOfInterview.toList(),
      'purposeOfInterviewOther': purposeOfInterviewOtherController.text.trim(),
      'howLongKnown': howLongKnown,
      'currentSituationUnderstanding': currentSituationUnderstandingController.text.trim(),
      'showResponsibleForCare': showResponsibleForCare,
      'responsibleForCareFirstName': responsibleForCareFirstNameController.text.trim(),
      'responsibleForCareSurname': responsibleForCareSurnameController.text.trim(),
      'housingConditionRating': housingConditionRating,
      'housingComments': housingCommentsController.text.trim(),
      'basicNeedsRating': basicNeedsRating,
      'basicNeedsDetails': basicNeedsDetailsController.text.trim(),
      'healthStatusRating': healthStatusRating,
      'healthStatusDetails': healthStatusDetailsController.text.trim(),
      'accessHealthServices': accessHealthServices,
      'healthServiceTypes': healthServiceTypes.toList(),
      'healthServiceOther': healthServiceOtherController.text.trim(),
      'accessSocialSupport': accessSocialSupport,
      'socialSupportTypes': socialSupportTypes.toList(),
      'socialSupportOther': socialSupportOtherController.text.trim(),
      'accessSchoolWork': accessSchoolWork,
      'schoolWorkTypes': schoolWorkTypes.toList(),
      'schoolWorkOther': schoolWorkOtherController.text.trim(),
      'accessServicesComments': accessServicesCommentsController.text.trim(),
      'abuseTypes': abuseTypes.toList(),
      'abuseDetails': abuseDetailsController.text.trim(),
      'signsOfNeglect': signsOfNeglect,
      'neglectTypes': neglectTypes.toList(),
      'neglectTypeOther': neglectTypeOtherController.text.trim(),
      'neglectDetails': neglectDetailsController.text.trim(),
      'riskFactors': riskFactors.toList(),
      'riskFactorOther': riskFactorOtherController.text.trim(),
      'dailyFunctioning': dailyFunctioningController.text.trim(),
      'socialBehaviours': socialBehaviours.toList(),
      'behaviourComments': behaviourCommentsController.text.trim(),
      'familySupportLevel': familySupportLevel,
      'familySupportExplain': familySupportExplainController.text.trim(),
      'communityPerception': communityPerceptionController.text.trim(),
      'knownHistory': knownHistoryController.text.trim(),
      'keyChallenges': keyChallengesController.text.trim(),
      'recommendations': recommendationsController.text.trim(),
      'informantCredibility': informantCredibility,
      'credibilityReasons': credibilityReasonsController.text.trim(),
      'socialWorkerSummaryNotes': socialWorkerSummaryNotesController.text.trim(),
      'riskLevel': riskLevel,
    };
  }

  void dispose() {
    firstNameController.dispose();
    surnameController.dispose();
    ageController.dispose();
    relationshipToClientOtherController.dispose();
    occupationOtherController.dispose();
    contactCountryCodeOtherController.dispose();
    contactNumberController.dispose();
    physicalAddressController.dispose();
    purposeOfInterviewOtherController.dispose();
    currentSituationUnderstandingController.dispose();
    responsibleForCareFirstNameController.dispose();
    responsibleForCareSurnameController.dispose();
    housingCommentsController.dispose();
    basicNeedsDetailsController.dispose();
    healthStatusDetailsController.dispose();
    healthServiceOtherController.dispose();
    socialSupportOtherController.dispose();
    schoolWorkOtherController.dispose();
    accessServicesCommentsController.dispose();
    abuseDetailsController.dispose();
    neglectTypeOtherController.dispose();
    neglectDetailsController.dispose();
    riskFactorOtherController.dispose();
    dailyFunctioningController.dispose();
    behaviourCommentsController.dispose();
    familySupportExplainController.dispose();
    communityPerceptionController.dispose();
    knownHistoryController.dispose();
    keyChallengesController.dispose();
    recommendationsController.dispose();
    credibilityReasonsController.dispose();
    socialWorkerSummaryNotesController.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form 5: Case Conference Record
// ─────────────────────────────────────────────────────────────────────────────
class _CaseConferenceEntry {
  final String id;

  // Header (auto-filled from Part 1)
  final TextEditingController conferenceDateController;
  final TextEditingController conferenceTimeController;
  String conferenceType;        // SCHEDULED | UNPLANNED
  String locationType;          // CLIENTS_HOME | OFFICE | OTHER
  final TextEditingController locationOtherController;
  String aimOfConference;
  final TextEditingController aimOtherController;

  // Non-family participants (name + agency) — starts empty
  final List<Map<String, TextEditingController>> nonFamilyParticipants;

  // Family participants (firstName + surname + relationship dropdown) — starts empty
  final List<Map<String, dynamic>> familyParticipants;

  // Discussion & outcomes
  final TextEditingController keyDiscussionPointsController;
  final TextEditingController keyOutcomesController;
  final TextEditingController observationsOnDynamicsController;

  // Client consultation
  String clientSpokenToIndividually;
  final TextEditingController clientConsultationOutcomeController;

  // Next conference / follow-up
  final TextEditingController nextConferenceDateController;
  String nextConferenceType;
  String nextConferenceLocation;
  final TextEditingController nextConferenceLocationOtherController;
  final TextEditingController nextConferencePurposeController;

  _CaseConferenceEntry({
    required this.id,
    String conferenceDate = '',
    String conferenceTime = '',
    this.conferenceType = '',
    this.locationType = '',
    String locationOther = '',
    this.aimOfConference = '',
    String aimOther = '',
    List<Map<String, TextEditingController>>? nonFamilyParticipants,
    List<Map<String, dynamic>>? familyParticipants,
    String keyDiscussionPoints = '',
    String keyOutcomes = '',
    String observationsOnDynamics = '',
    this.clientSpokenToIndividually = '',
    String clientConsultationOutcome = '',
    String nextConferenceDate = '',
    this.nextConferenceType = '',
    this.nextConferenceLocation = '',
    String nextConferenceLocationOther = '',
    String nextConferencePurpose = '',
  })  : conferenceDateController = TextEditingController(text: conferenceDate),
        conferenceTimeController = TextEditingController(text: conferenceTime),
        locationOtherController = TextEditingController(text: locationOther),
        aimOtherController = TextEditingController(text: aimOther),
        nonFamilyParticipants = nonFamilyParticipants ?? [],
        familyParticipants = familyParticipants ?? [],
        keyDiscussionPointsController = TextEditingController(text: keyDiscussionPoints),
        keyOutcomesController = TextEditingController(text: keyOutcomes),
        observationsOnDynamicsController = TextEditingController(text: observationsOnDynamics),
        clientConsultationOutcomeController = TextEditingController(text: clientConsultationOutcome),
        nextConferenceDateController = TextEditingController(text: nextConferenceDate),
        nextConferenceLocationOtherController = TextEditingController(text: nextConferenceLocationOther),
        nextConferencePurposeController = TextEditingController(text: nextConferencePurpose);

  static Map<String, TextEditingController> _newParticipantRow() =>
      {'name': TextEditingController(), 'agency': TextEditingController()};

  // family row: controllers for firstName, surname; String for relationship + relationshipOther
  static Map<String, dynamic> _newFamilyRow() => {
    'firstName': TextEditingController(),
    'surname': TextEditingController(),
    'relationship': '',
    'relationshipOther': TextEditingController(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'conferenceDate': conferenceDateController.text.trim(),
    'conferenceTime': conferenceTimeController.text.trim(),
    'conferenceType': conferenceType,
    'locationType': locationType,
    'locationOther': locationOtherController.text.trim(),
    'aimOfConference': aimOfConference,
    'aimOther': aimOtherController.text.trim(),
    'nonFamilyParticipants': nonFamilyParticipants
        .map((r) => {'name': r['name']!.text.trim(), 'agency': r['agency']!.text.trim()})
        .toList(),
    'familyParticipants': familyParticipants.map((r) => {
      'firstName': (r['firstName'] as TextEditingController).text.trim(),
      'surname': (r['surname'] as TextEditingController).text.trim(),
      'relationship': r['relationship'] as String,
      'relationshipOther': (r['relationshipOther'] as TextEditingController).text.trim(),
    }).toList(),
    'keyDiscussionPoints': keyDiscussionPointsController.text.trim(),
    'keyOutcomes': keyOutcomesController.text.trim(),
    'observationsOnDynamics': observationsOnDynamicsController.text.trim(),
    'clientSpokenToIndividually': clientSpokenToIndividually,
    'clientConsultationOutcome': clientConsultationOutcomeController.text.trim(),
    'nextConferenceDate': nextConferenceDateController.text.trim(),
    'nextConferenceType': nextConferenceType,
    'nextConferenceLocation': nextConferenceLocation,
    'nextConferenceLocationOther': nextConferenceLocationOtherController.text.trim(),
    'nextConferencePurpose': nextConferencePurposeController.text.trim(),
  };

  void dispose() {
    conferenceDateController.dispose();
    conferenceTimeController.dispose();
    locationOtherController.dispose();
    aimOtherController.dispose();
    for (final r in nonFamilyParticipants) { r['name']!.dispose(); r['agency']!.dispose(); }
    for (final r in familyParticipants) {
      (r['firstName'] as TextEditingController).dispose();
      (r['surname'] as TextEditingController).dispose();
      (r['relationshipOther'] as TextEditingController).dispose();
    }
    keyDiscussionPointsController.dispose();
    keyOutcomesController.dispose();
    observationsOnDynamicsController.dispose();
    clientConsultationOutcomeController.dispose();
    nextConferenceDateController.dispose();
    nextConferenceLocationOtherController.dispose();
    nextConferencePurposeController.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Self-contained phone input with searchable country picker.
// Owns its own State so the bottom sheet never touches the parent's setState.
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneInputField extends StatefulWidget {
  final _ExternalInformantEntry entry;
  final List<Map<String, dynamic>> countries;
  final Color accentColor;
  final void Function(String code) onCountryChanged;

  const _PhoneInputField({
    required this.entry,
    required this.countries,
    required this.accentColor,
    required this.onCountryChanged,
  });

  @override
  State<_PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<_PhoneInputField> {
  // Validate a phone number against the selected country's rules
  String? _validatePhone(String number, String dialCode) {
    if (number.trim().isEmpty) return null;
    Map<String, dynamic>? country;
    try {
      country = widget.countries.firstWhere(
              (c) => c['code'] == dialCode && c['name'] != 'Other');
    } catch (_) {
      return null;
    }
    final digits = number.trim().replaceAll(RegExp(r'\D'), '');
    final expectedDigits = country['digits'] as int;
    final validPrefixes = country['validPrefixes'] as List<dynamic>;
    if (validPrefixes.isNotEmpty &&
        !validPrefixes.any((p) => digits.startsWith(p.toString()))) {
      final prefixList = validPrefixes.map((p) => p.toString()).join(', ');
      return '${country['name']} numbers must start with $prefixList';
    }
    if (expectedDigits > 0 && digits.length != expectedDigits) {
      return '${country['name']} numbers must be $expectedDigits digits';
    }
    return null;
  }

  Map<String, dynamic>? get _selectedCountry {
    final code = widget.entry.contactCountryCode;
    if (code.isEmpty) return null;
    try {
      return widget.countries.firstWhere(
              (c) => c['code'] == code && c['name'] != 'Other');
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPicker() async {
    final TextEditingController searchCtrl = TextEditingController();
    // Use a ValueNotifier so the ListView rebuilds without touching any
    // external setState at all during the sheet's lifetime.
    final filteredNotifier =
    ValueNotifier<List<Map<String, dynamic>>>(List.from(widget.countries));

    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Select Country',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (q) {
                      final lower = q.trim().toLowerCase();
                      filteredNotifier.value = widget.countries.where((c) {
                        return (c['name'] as String)
                            .toLowerCase()
                            .contains(lower) ||
                            (c['code'] as String)
                                .toLowerCase()
                                .contains(lower);
                      }).toList();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by country or code (e.g. Lesotho or +266)',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: filteredNotifier,
                      builder: (_, filtered, __) {
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            final code = c['name'] == 'Other'
                                ? ''
                                : c['code'] as String;
                            final currentCode =
                                widget.entry.contactCountryCode;
                            final isSelected = code.isNotEmpty &&
                                currentCode == code;
                            final isOtherSelected =
                                c['name'] == 'Other' && currentCode.isEmpty;
                            return ListTile(
                              dense: true,
                              selected: isSelected || isOtherSelected,
                              selectedTileColor:
                              widget.accentColor.withOpacity(0.07),
                              leading: Text(c['flag'] as String,
                                  style: const TextStyle(fontSize: 22)),
                              title: Text(c['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              trailing: Text(
                                c['name'] == 'Other' ? '' : c['code'] as String,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.blueGrey),
                              ),
                              // Return the code as the sheet result — no setState here
                              onTap: () => Navigator.pop(sheetCtx, code),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
    filteredNotifier.dispose();

    // Sheet is fully gone. Now it is safe to update state.
    if (picked != null && mounted) {
      // Update local display
      setState(() {});
      // Notify the parent so it can persist the value on the entry object
      widget.onCountryChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = _selectedCountry;
    final code = widget.entry.contactCountryCode;
    final flagAndCode = code.isEmpty
        ? '🌍  Other'
        : '${country?['flag'] ?? '🌍'}  $code';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country picker button
          GestureDetector(
            onTap: _openPicker,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFD),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flagAndCode,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: Colors.blueGrey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Phone number field
          Expanded(
            child: TextFormField(
              controller: widget.entry.contactNumberController,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  _validatePhone(v ?? '', widget.entry.contactCountryCode),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: country != null
                    ? 'Phone Number (${country['digits']} digits)'
                    : 'Phone Number',
                filled: true,
                fillColor: const Color(0xFFF9FBFD),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
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

  final List<_ExternalInformantEntry> _externalInformantEntries = [];
  final Set<int> _collapsedInformants = {};

  // Case Conference (Form 5)
  final List<_CaseConferenceEntry> _caseConferenceEntries = [];
  final Set<int> _collapsedConferences = {};

  static const List<String> _conferenceTypeOptions = ['SCHEDULED', 'UNPLANNED'];
  static const Map<String, String> _conferenceTypeLabels = {
    'SCHEDULED': 'Scheduled',
    'UNPLANNED': 'Unplanned',
  };
  static const List<String> _conferenceLocationOptions = [
    'CLIENTS_HOME', 'OFFICE', 'OTHER',
  ];
  static const Map<String, String> _conferenceLocationLabels = {
    'CLIENTS_HOME': "Client's home",
    'OFFICE': 'Office',
    'OTHER': 'Other (specify)',
  };
  static const List<String> _conferenceAimOptions = [
    'DURING_ASSESSMENT',
    'ROUTINE_MONITORING',
    'SUPPORT',
    'CRISIS_INTERVENTION',
    'CASE_REVIEW',
    'CASE_CLOSURE',
    'OTHER',
  ];
  static const Map<String, String> _conferenceAimLabels = {
    'DURING_ASSESSMENT': 'During assessment',
    'ROUTINE_MONITORING': 'Routine monitoring',
    'SUPPORT': 'Support',
    'CRISIS_INTERVENTION': 'Crisis intervention',
    'CASE_REVIEW': 'Case review',
    'CASE_CLOSURE': 'Case closure',
    'OTHER': 'Other (specify)',
  };

  static const List<String> _familyRelationshipOptions = [
    'PARENT', 'GUARDIAN', 'SPOUSE_PARTNER', 'CHILD', 'SIBLING',
    'GRANDPARENT', 'AUNT_UNCLE', 'COUSIN', 'CAREGIVER', 'CLIENT_SELF', 'OTHER',
  ];
  static const Map<String, String> _familyRelationshipLabels = {
    'PARENT': 'Parent',
    'GUARDIAN': 'Guardian',
    'SPOUSE_PARTNER': 'Spouse / partner',
    'CHILD': 'Child',
    'SIBLING': 'Sibling',
    'GRANDPARENT': 'Grandparent',
    'AUNT_UNCLE': 'Aunt / uncle',
    'COUSIN': 'Cousin',
    'CAREGIVER': 'Caregiver',
    'CLIENT_SELF': 'Client (self)',
    'OTHER': 'Other (specify)',
  };

  static const List<String> _purposeOfInterviewOptions = [
    'SOCIAL_INVESTIGATION', 'RISK_ASSESSMENT', 'PLACEMENT_SUPPORT',
    'COURT_REPORT', 'FOLLOW_UP_MONITORING', 'OTHER',
  ];
  static const Map<String, String> _purposeOfInterviewLabels = {
    'SOCIAL_INVESTIGATION': 'Social investigation',
    'RISK_ASSESSMENT': 'Risk assessment',
    'PLACEMENT_SUPPORT': 'Placement / support assessment',
    'COURT_REPORT': 'Court report',
    'FOLLOW_UP_MONITORING': 'Follow-up monitoring',
    'OTHER': 'Other',
  };
  static const List<String> _housingConditionOptions = [
    'STABLE_SAFE', 'INADEQUATE', 'UNSAFE',
  ];
  static const Map<String, String> _housingConditionLabels = {
    'STABLE_SAFE': 'Stable and safe',
    'INADEQUATE': 'Inadequate',
    'UNSAFE': 'Unsafe',
  };
  static const List<String> _basicNeedsOptions = [
    'ADEQUATE', 'INCONSISTENT', 'INADEQUATE',
  ];
  static const Map<String, String> _basicNeedsLabels = {
    'ADEQUATE': 'Adequate',
    'INCONSISTENT': 'Inconsistent',
    'INADEQUATE': 'Inadequate',
  };
  static const List<String> _observedHealthOptions = [
    'APPEARS_HEALTHY', 'ILL_FRAIL', 'HAS_DISABILITY', 'MENTAL_HEALTH_CONCERNS',
  ];
  static const Map<String, String> _observedHealthLabels = {
    'APPEARS_HEALTHY': 'Appears healthy',
    'ILL_FRAIL': 'Ill / frail',
    'HAS_DISABILITY': 'Has disability',
    'MENTAL_HEALTH_CONCERNS': 'Mental health concerns',
  };
  static const List<String> _abuseTypeOptions = [
    'PHYSICAL', 'EMOTIONAL_PSYCHOLOGICAL', 'SEXUAL', 'FINANCIAL', 'NONE_KNOWN',
  ];
  static const Map<String, String> _abuseTypeLabels = {
    'PHYSICAL': 'Physical',
    'EMOTIONAL_PSYCHOLOGICAL': 'Emotional / psychological',
    'SEXUAL': 'Sexual',
    'FINANCIAL': 'Financial exploitation',
    'NONE_KNOWN': 'None known',
  };
  static const List<String> _riskFactorOptions = [
    'VIOLENCE', 'SUBSTANCE_ABUSE', 'ISOLATION', 'UNSAFE_ENVIRONMENT', 'EXPLOITATION', 'OTHER',
  ];
  static const Map<String, String> _riskFactorLabels = {
    'VIOLENCE': 'Violence in household / community',
    'SUBSTANCE_ABUSE': 'Substance abuse',
    'ISOLATION': 'Isolation / lack of support',
    'UNSAFE_ENVIRONMENT': 'Unsafe environment',
    'EXPLOITATION': 'Exploitation (labour, financial, etc.)',
    'OTHER': 'Other',
  };
  static const List<String> _socialBehaviourOptions = [
    'INDEPENDENT', 'WITHDRAWN', 'DEPENDENT', 'AGGRESSIVE', 'VULNERABLE',
  ];
  static const Map<String, String> _socialBehaviourLabels = {
    'INDEPENDENT': 'Independent',
    'WITHDRAWN': 'Withdrawn',
    'DEPENDENT': 'Dependent on others',
    'AGGRESSIVE': 'Aggressive',
    'VULNERABLE': 'Vulnerable / easily exploited',
  };
  static const List<String> _familySupportOptions = ['STRONG', 'LIMITED', 'NONE'];
  static const Map<String, String> _familySupportLabels = {
    'STRONG': 'Strong',
    'LIMITED': 'Limited',
    'NONE': 'None',
  };
  static const List<String> _credibilityOptions = ['HIGH', 'MODERATE', 'LOW'];
  static const Map<String, String> _credibilityLabels = {
    'HIGH': 'High',
    'MODERATE': 'Moderate',
    'LOW': 'Low',
  };
  static const List<String> _riskLevelOptions = [
    'LOW_RISK', 'MODERATE_RISK', 'HIGH_RISK', 'CRITICAL',
  ];
  static const Map<String, String> _riskLevelLabels = {
    'LOW_RISK': 'Low Risk',
    'MODERATE_RISK': 'Moderate Risk',
    'HIGH_RISK': 'High Risk',
    'CRITICAL': 'Critical (Immediate intervention required)',
  };
  // Gender options for external informant (includes Other)
  static const List<String> _genderOptions = ['MALE', 'FEMALE', 'OTHER'];
  static const Map<String, String> _genderLabels = {
    'MALE': 'Male',
    'FEMALE': 'Female',
    'OTHER': 'Other',
  };

  // Informant's relationship to client (Section B) — dropdown with Other
  static const List<String> _informantRelationshipOptions = [
    'NEIGHBOUR',
    'TEACHER',
    'COMMUNITY_LEADER',
    'RELATIVE',
    'NURSE_HEALTH_WORKER',
    'FRIEND',
    'RELIGIOUS_LEADER',
    'SOCIAL_WORKER_OTHER_PROFESSIONAL',
    'OTHER',
  ];
  static const Map<String, String> _informantRelationshipLabels = {
    'NEIGHBOUR': 'Neighbour',
    'TEACHER': 'Teacher',
    'COMMUNITY_LEADER': 'Community leader',
    'RELATIVE': 'Relative',
    'NURSE_HEALTH_WORKER': 'Nurse / health worker',
    'FRIEND': 'Friend',
    'RELIGIOUS_LEADER': 'Religious leader',
    'SOCIAL_WORKER_OTHER_PROFESSIONAL': 'Social worker / other professional',
    'OTHER': 'Other',
  };

  // Informant occupation (Section B) — dropdown with Other
  static const List<String> _occupationOptions = [
    'UNEMPLOYED',
    'FARMER',
    'TEACHER',
    'HEALTH_WORKER',
    'GOVERNMENT_EMPLOYEE',
    'BUSINESS_OWNER_TRADER',
    'DOMESTIC_WORKER',
    'CASUAL_LABOURER',
    'STUDENT',
    'RETIRED',
    'OTHER',
  ];
  static const Map<String, String> _occupationLabels = {
    'UNEMPLOYED': 'Unemployed',
    'FARMER': 'Farmer',
    'TEACHER': 'Teacher',
    'HEALTH_WORKER': 'Health worker',
    'GOVERNMENT_EMPLOYEE': 'Government employee',
    'BUSINESS_OWNER_TRADER': 'Business owner / trader',
    'DOMESTIC_WORKER': 'Domestic worker',
    'CASUAL_LABOURER': 'Casual labourer',
    'STUDENT': 'Student',
    'RETIRED': 'Retired',
    'OTHER': 'Other',
  };

  // Country data for informant contact number (Section B)
  static const List<Map<String, dynamic>> _countries = [
    {'name': 'Lesotho',              'code': '+266', 'flag': '🇱🇸', 'digits': 8,  'validPrefixes': ['5','6','2']},
    {'name': 'South Africa',         'code': '+27',  'flag': '🇿🇦', 'digits': 9,  'validPrefixes': []},
    {'name': 'Zimbabwe',             'code': '+263', 'flag': '🇿🇼', 'digits': 9,  'validPrefixes': ['7','8']},
    {'name': 'Mozambique',           'code': '+258', 'flag': '🇲🇿', 'digits': 9,  'validPrefixes': ['8']},
    {'name': 'Botswana',             'code': '+267', 'flag': '🇧🇼', 'digits': 8,  'validPrefixes': ['7','3']},
    {'name': 'Namibia',              'code': '+264', 'flag': '🇳🇦', 'digits': 9,  'validPrefixes': ['8','6']},
    {'name': 'Eswatini',             'code': '+268', 'flag': '🇸🇿', 'digits': 8,  'validPrefixes': ['7','2']},
    {'name': 'Zambia',               'code': '+260', 'flag': '🇿🇲', 'digits': 9,  'validPrefixes': ['9','7']},
    {'name': 'Malawi',               'code': '+265', 'flag': '🇲🇼', 'digits': 9,  'validPrefixes': ['8','9']},
    {'name': 'Tanzania',             'code': '+255', 'flag': '🇹🇿', 'digits': 9,  'validPrefixes': ['7','6']},
    {'name': 'Kenya',                'code': '+254', 'flag': '🇰🇪', 'digits': 9,  'validPrefixes': ['7','1']},
    {'name': 'Uganda',               'code': '+256', 'flag': '🇺🇬', 'digits': 9,  'validPrefixes': ['7','3']},
    {'name': 'Ethiopia',             'code': '+251', 'flag': '🇪🇹', 'digits': 9,  'validPrefixes': ['9','1']},
    {'name': 'Ghana',                'code': '+233', 'flag': '🇬🇭', 'digits': 9,  'validPrefixes': ['2','5']},
    {'name': 'Nigeria',              'code': '+234', 'flag': '🇳🇬', 'digits': 10, 'validPrefixes': ['7','8','9']},
    {'name': 'Egypt',                'code': '+20',  'flag': '🇪🇬', 'digits': 10, 'validPrefixes': ['1']},
    {'name': 'Angola',               'code': '+244', 'flag': '🇦🇴', 'digits': 9,  'validPrefixes': ['9']},
    {'name': 'DR Congo',             'code': '+243', 'flag': '🇨🇩', 'digits': 9,  'validPrefixes': ['8','9']},
    {'name': 'Rwanda',               'code': '+250', 'flag': '🇷🇼', 'digits': 9,  'validPrefixes': ['7']},
    {'name': 'Madagascar',           'code': '+261', 'flag': '🇲🇬', 'digits': 9,  'validPrefixes': ['3']},
    {'name': 'United Kingdom',       'code': '+44',  'flag': '🇬🇧', 'digits': 10, 'validPrefixes': []},
    {'name': 'United States',        'code': '+1',   'flag': '🇺🇸', 'digits': 10, 'validPrefixes': []},
    {'name': 'Canada',               'code': '+1',   'flag': '🇨🇦', 'digits': 10, 'validPrefixes': []},
    {'name': 'Australia',            'code': '+61',  'flag': '🇦🇺', 'digits': 9,  'validPrefixes': ['4']},
    {'name': 'India',                'code': '+91',  'flag': '🇮🇳', 'digits': 10, 'validPrefixes': ['6','7','8','9']},
    {'name': 'China',                'code': '+86',  'flag': '🇨🇳', 'digits': 11, 'validPrefixes': ['1']},
    {'name': 'Germany',              'code': '+49',  'flag': '🇩🇪', 'digits': 10, 'validPrefixes': []},
    {'name': 'France',               'code': '+33',  'flag': '🇫🇷', 'digits': 9,  'validPrefixes': ['6','7']},
    {'name': 'Portugal',             'code': '+351', 'flag': '🇵🇹', 'digits': 9,  'validPrefixes': ['9']},
    {'name': 'Netherlands',          'code': '+31',  'flag': '🇳🇱', 'digits': 9,  'validPrefixes': ['6']},
    {'name': 'Sweden',               'code': '+46',  'flag': '🇸🇪', 'digits': 9,  'validPrefixes': ['7']},
    {'name': 'Norway',               'code': '+47',  'flag': '🇳🇴', 'digits': 8,  'validPrefixes': []},
    {'name': 'Denmark',              'code': '+45',  'flag': '🇩🇰', 'digits': 8,  'validPrefixes': []},
    {'name': 'Switzerland',          'code': '+41',  'flag': '🇨🇭', 'digits': 9,  'validPrefixes': ['7']},
    {'name': 'Italy',                'code': '+39',  'flag': '🇮🇹', 'digits': 10, 'validPrefixes': ['3']},
    {'name': 'Spain',                'code': '+34',  'flag': '🇪🇸', 'digits': 9,  'validPrefixes': ['6','7']},
    {'name': 'Brazil',               'code': '+55',  'flag': '🇧🇷', 'digits': 11, 'validPrefixes': ['9']},
    {'name': 'Japan',                'code': '+81',  'flag': '🇯🇵', 'digits': 10, 'validPrefixes': ['7','8','9']},
    {'name': 'South Korea',          'code': '+82',  'flag': '🇰🇷', 'digits': 10, 'validPrefixes': ['1']},
    {'name': 'Saudi Arabia',         'code': '+966', 'flag': '🇸🇦', 'digits': 9,  'validPrefixes': ['5']},
    {'name': 'United Arab Emirates', 'code': '+971', 'flag': '🇦🇪', 'digits': 9,  'validPrefixes': ['5']},
    {'name': 'Qatar',                'code': '+974', 'flag': '🇶🇦', 'digits': 8,  'validPrefixes': ['3','5','6','7']},
    {'name': 'New Zealand',          'code': '+64',  'flag': '🇳🇿', 'digits': 9,  'validPrefixes': ['2']},
    {'name': 'Pakistan',             'code': '+92',  'flag': '🇵🇰', 'digits': 10, 'validPrefixes': ['3']},
    {'name': 'Bangladesh',           'code': '+880', 'flag': '🇧🇩', 'digits': 10, 'validPrefixes': ['1']},
    {'name': 'Other',                'code': '',     'flag': '🌍', 'digits': 0,  'validPrefixes': []},
  ];

  // How long the informant has known the client (Section D) — range dropdown
  static const List<String> _howLongKnownOptions = [
    'LESS_THAN_6_MONTHS',
    'SIX_MONTHS_TO_ONE_YEAR',
    'ONE_TO_THREE_YEARS',
    'THREE_TO_FIVE_YEARS',
    'MORE_THAN_FIVE_YEARS',
  ];
  static const Map<String, String> _howLongKnownLabels = {
    'LESS_THAN_6_MONTHS': 'Less than 6 months',
    'SIX_MONTHS_TO_ONE_YEAR': '6 months – 1 year',
    'ONE_TO_THREE_YEARS': '1 – 3 years',
    'THREE_TO_FIVE_YEARS': '3 – 5 years',
    'MORE_THAN_FIVE_YEARS': 'More than 5 years',
  };

  // Access to services sub-options (Section E), shown when the parent Yes/No is YES
  static const List<String> _healthServiceOptions = [
    'CLINIC_HOSPITAL',
    'MENTAL_HEALTH_SERVICES',
    'DISABILITY_REHABILITATION',
    'TRADITIONAL_HEALER',
    'OTHER',
  ];
  static const Map<String, String> _healthServiceLabels = {
    'CLINIC_HOSPITAL': 'Clinic / hospital',
    'MENTAL_HEALTH_SERVICES': 'Mental health services',
    'DISABILITY_REHABILITATION': 'Disability / rehabilitation services',
    'TRADITIONAL_HEALER': 'Traditional healer',
    'OTHER': 'Other',
  };
  static const List<String> _socialSupportOptions = [
    'GOVERNMENT_GRANT',
    'NGO_SUPPORT',
    'FAMILY_NETWORK',
    'RELIGIOUS_SUPPORT',
    'OTHER',
  ];
  static const Map<String, String> _socialSupportLabels = {
    'GOVERNMENT_GRANT': 'Government grant',
    'NGO_SUPPORT': 'NGO support',
    'FAMILY_NETWORK': 'Family network',
    'RELIGIOUS_SUPPORT': 'Religious support',
    'OTHER': 'Other',
  };
  static const List<String> _schoolWorkOptions = [
    'ATTENDING_SCHOOL',
    'VOCATIONAL_TRAINING',
    'EMPLOYED',
    'SELF_EMPLOYED',
    'OTHER',
  ];
  static const Map<String, String> _schoolWorkLabels = {
    'ATTENDING_SCHOOL': 'Attending school',
    'VOCATIONAL_TRAINING': 'Vocational training',
    'EMPLOYED': 'Employed',
    'SELF_EMPLOYED': 'Self-employed',
    'OTHER': 'Other',
  };

  // Signs of neglect sub-options (Section F), shown when the parent Yes/No is YES
  static const List<String> _neglectTypeOptions = [
    'LACK_OF_FOOD_NUTRITION',
    'POOR_HYGIENE',
    'INADEQUATE_CLOTHING',
    'LACK_OF_SUPERVISION',
    'LACK_OF_MEDICAL_CARE',
    'EDUCATIONAL_NEGLECT',
    'OTHER',
  ];
  static const Map<String, String> _neglectTypeLabels = {
    'LACK_OF_FOOD_NUTRITION': 'Lack of food / nutrition',
    'POOR_HYGIENE': 'Poor hygiene',
    'INADEQUATE_CLOTHING': 'Inadequate clothing',
    'LACK_OF_SUPERVISION': 'Lack of supervision',
    'LACK_OF_MEDICAL_CARE': 'Lack of medical care',
    'EDUCATIONAL_NEGLECT': 'Educational neglect',
    'OTHER': 'Other',
  };

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
    for (final entry in _externalInformantEntries) { entry.dispose(); }
    for (final entry in _caseConferenceEntries) { entry.dispose(); }
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

  // Conference date must not be in the past
  Future<void> _pickConferenceDate(TextEditingController controller) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = () {
      final parsed = DateTime.tryParse(controller.text.trim());
      if (parsed == null) return today;
      return parsed.isBefore(today) ? today : parsed;
    }();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => controller.text = _formatDate(picked));
  }

  Future<void> _pickConferenceTime(TextEditingController controller) async {
    TimeOfDay initial = TimeOfDay.now();
    final existing = controller.text.trim();
    if (existing.isNotEmpty) {
      final parts = existing.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        final hh = picked.hour.toString().padLeft(2, '0');
        final mm = picked.minute.toString().padLeft(2, '0');
        controller.text = '$hh:$mm';
      });
    }
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
    final informants = (part4['externalInformants'] ?? []) as List<dynamic>;
    for (final entry in _externalInformantEntries) { entry.dispose(); }
    _externalInformantEntries.clear();
    for (final raw in informants) {
      final item = (raw ?? {}) as Map<String, dynamic>;

      // Backward compatibility: older saved drafts stored a single 'fullName'
      // and a single 'responsibleForCare' free-text field.
      String firstName = _text(item['firstName']);
      String surname = _text(item['surname']);
      if (firstName.isEmpty && surname.isEmpty) {
        final legacyFullName = _text(item['fullName']);
        if (legacyFullName.isNotEmpty) {
          final parts = legacyFullName.split(' ').where((p) => p.trim().isNotEmpty).toList();
          firstName = parts.isNotEmpty ? parts.first : '';
          surname = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
      }

      String responsibleFirstName = _text(item['responsibleForCareFirstName']);
      String responsibleSurname = _text(item['responsibleForCareSurname']);
      if (responsibleFirstName.isEmpty && responsibleSurname.isEmpty) {
        final legacyResponsible = _text(item['responsibleForCare']);
        if (legacyResponsible.isNotEmpty) {
          final parts = legacyResponsible.split(' ').where((p) => p.trim().isNotEmpty).toList();
          responsibleFirstName = parts.isNotEmpty ? parts.first : '';
          responsibleSurname = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
      }

      // Relationship to client / occupation used to be free text; map onto the
      // new dropdown + Other pattern.
      final relationship = _resolveOptionWithOther(
        _text(item['relationshipToClient']).isNotEmpty
            ? _text(item['relationshipToClient'])
            : '',
        _informantRelationshipOptions,
      );
      final relationshipOther = _text(item['relationshipToClientOther']).isNotEmpty
          ? _text(item['relationshipToClientOther'])
          : relationship[1];

      final occupationResolved = _resolveOptionWithOther(_text(item['occupation']), _occupationOptions);
      final occupationOther = _text(item['occupationOther']).isNotEmpty
          ? _text(item['occupationOther'])
          : occupationResolved[1];

      // Contact details: newer drafts split country code + number; legacy
      // drafts stored one free-text 'contactDetails' field.
      String countryCode = _text(item['contactCountryCode']);
      String contactNumber = _text(item['contactNumber']);
      if (countryCode.isEmpty && contactNumber.isEmpty) {
        contactNumber = _text(item['contactDetails']);
        countryCode = '+266';
      }
      if (countryCode.isEmpty) countryCode = '+266';

      // How long known used to be free text; normalise onto the range options
      // where possible (older values that don't match are left blank).
      final howLongKnownResolved = _normaliseOptionValue(_text(item['howLongKnown']), _howLongKnownOptions);

      _externalInformantEntries.add(_ExternalInformantEntry(
        id: _text(item['id']).isEmpty ? AppUtil.getUid() : _text(item['id']),
        firstName: firstName,
        surname: surname,
        age: _text(item['age']),
        gender: _text(item['gender']),
        relationshipToClient: relationship[0],
        relationshipToClientOther: relationshipOther,
        occupation: occupationResolved[0],
        occupationOther: occupationOther,
        contactCountryCode: countryCode,
        contactCountryCodeOther: _text(item['contactCountryCodeOther']),
        contactNumber: contactNumber,
        physicalAddress: _text(item['physicalAddress']),
        purposeOfInterview: Set<String>.from(item['purposeOfInterview'] ?? []),
        purposeOfInterviewOther: _text(item['purposeOfInterviewOther']),
        howLongKnown: _howLongKnownOptions.contains(howLongKnownResolved) ? howLongKnownResolved : '',
        currentSituationUnderstanding: _text(item['currentSituationUnderstanding']),
        showResponsibleForCare: item['showResponsibleForCare'] is bool
            ? item['showResponsibleForCare'] as bool
            : null,
        responsibleForCareFirstName: responsibleFirstName,
        responsibleForCareSurname: responsibleSurname,
        housingConditionRating: _text(item['housingConditionRating']),
        housingComments: _text(item['housingComments']),
        basicNeedsRating: _text(item['basicNeedsRating']),
        basicNeedsDetails: _text(item['basicNeedsDetails']),
        healthStatusRating: _text(item['healthStatusRating']),
        healthStatusDetails: _text(item['healthStatusDetails']),
        accessHealthServices: _text(item['accessHealthServices']),
        healthServiceTypes: Set<String>.from(item['healthServiceTypes'] ?? []),
        healthServiceOther: _text(item['healthServiceOther']),
        accessSocialSupport: _text(item['accessSocialSupport']),
        socialSupportTypes: Set<String>.from(item['socialSupportTypes'] ?? []),
        socialSupportOther: _text(item['socialSupportOther']),
        accessSchoolWork: _text(item['accessSchoolWork']),
        schoolWorkTypes: Set<String>.from(item['schoolWorkTypes'] ?? []),
        schoolWorkOther: _text(item['schoolWorkOther']),
        accessServicesComments: _text(item['accessServicesComments']),
        abuseTypes: Set<String>.from(item['abuseTypes'] ?? []),
        abuseDetails: _text(item['abuseDetails']),
        signsOfNeglect: _text(item['signsOfNeglect']),
        neglectTypes: Set<String>.from(item['neglectTypes'] ?? []),
        neglectTypeOther: _text(item['neglectTypeOther']),
        neglectDetails: _text(item['neglectDetails']),
        riskFactors: Set<String>.from(item['riskFactors'] ?? []),
        riskFactorOther: _text(item['riskFactorOther']),
        dailyFunctioning: _text(item['dailyFunctioning']),
        socialBehaviours: Set<String>.from(item['socialBehaviours'] ?? []),
        behaviourComments: _text(item['behaviourComments']),
        familySupportLevel: _text(item['familySupportLevel']),
        familySupportExplain: _text(item['familySupportExplain']),
        communityPerception: _text(item['communityPerception']),
        knownHistory: _text(item['knownHistory']),
        keyChallenges: _text(item['keyChallenges']),
        recommendations: _text(item['recommendations']),
        informantCredibility: _text(item['informantCredibility']),
        credibilityReasons: _text(item['credibilityReasons']),
        socialWorkerSummaryNotes: _text(item['socialWorkerSummaryNotes']),
        riskLevel: _text(item['riskLevel']),
      ));
    }

    final conferences = (part4['caseConferences'] ?? []) as List<dynamic>;
    for (final entry in _caseConferenceEntries) { entry.dispose(); }
    _caseConferenceEntries.clear();
    for (final raw in conferences) {
      final item = (raw ?? {}) as Map<String, dynamic>;
      final nonFamily = ((item['nonFamilyParticipants'] ?? []) as List<dynamic>).map((p) {
        final m = (p ?? {}) as Map<String, dynamic>;
        return {'name': TextEditingController(text: _text(m['name'])), 'agency': TextEditingController(text: _text(m['agency']))};
      }).toList();
      final family = ((item['familyParticipants'] ?? []) as List<dynamic>).map((p) {
        final m = (p ?? {}) as Map<String, dynamic>;
        return <String, dynamic>{
          'firstName': TextEditingController(text: _text(m['firstName'])),
          'surname': TextEditingController(text: _text(m['surname'])),
          'relationship': _text(m['relationship']),
          'relationshipOther': TextEditingController(text: _text(m['relationshipOther'])),
        };
      }).toList();
      _caseConferenceEntries.add(_CaseConferenceEntry(
        id: _text(item['id']).isEmpty ? AppUtil.getUid() : _text(item['id']),
        conferenceDate: _text(item['conferenceDate']),
        conferenceTime: _text(item['conferenceTime']),
        conferenceType: _text(item['conferenceType']),
        locationType: _text(item['locationType']),
        locationOther: _text(item['locationOther']),
        aimOfConference: _text(item['aimOfConference']),
        aimOther: _text(item['aimOther']),
        nonFamilyParticipants: nonFamily.isEmpty ? null : nonFamily,
        familyParticipants: family.isEmpty ? null : family,
        keyDiscussionPoints: _text(item['keyDiscussionPoints']),
        keyOutcomes: _text(item['keyOutcomes']),
        observationsOnDynamics: _text(item['observationsOnDynamics']),
        clientSpokenToIndividually: _text(item['clientSpokenToIndividually']),
        clientConsultationOutcome: _text(item['clientConsultationOutcome']),
        nextConferenceDate: _text(item['nextConferenceDate']),
        nextConferenceType: _text(item['nextConferenceType']),
        nextConferenceLocation: _text(item['nextConferenceLocation']),
        nextConferenceLocationOther: _text(item['nextConferenceLocationOther']),
        nextConferencePurpose: _text(item['nextConferencePurpose']),
      ));
    }
  }

  /// Resolves a legacy free-text value onto a known option list. Returns a
  /// two-item list: [resolvedOption, otherText]. If the value already
  /// matches (or normalises to) one of [options], otherText is empty. If it
  /// doesn't match and the list supports 'OTHER', the original text is kept
  /// as the Other value. Empty input resolves to ['', ''].
  List<String> _resolveOptionWithOther(String raw, List<String> options) {
    final v = raw.trim();
    if (v.isEmpty) return ['', ''];
    final normalised = _normaliseOptionValue(v, options);
    if (options.contains(normalised)) return [normalised, ''];
    if (options.contains('OTHER')) return ['OTHER', v];
    return [v, ''];
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
        'externalInformants': _externalInformantEntries.map((e) => e.toJson()).toList(),
        'caseConferences': _caseConferenceEntries.map((e) => e.toJson()).toList(),
      },
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

  void _addExternalInformantEntry() {
    setState(() {
      // Collapse all existing cards before adding the new one
      for (int i = 0; i < _externalInformantEntries.length; i++) {
        _collapsedInformants.add(i);
      }
      _externalInformantEntries.add(_ExternalInformantEntry(id: AppUtil.getUid(), contactCountryCode: '+266'));
      // New card is always expanded (its index is not in the set)
    });
  }

  void _removeExternalInformantEntry(int index) {
    setState(() {
      final item = _externalInformantEntries.removeAt(index);
      item.dispose();
      // Rebuild the collapsed set with shifted indices
      final updated = <int>{};
      for (final i in _collapsedInformants) {
        if (i < index) updated.add(i);
        if (i > index) updated.add(i - 1);
        // i == index: removed, don't carry over
      }
      _collapsedInformants
        ..clear()
        ..addAll(updated);
    });
  }

  void _addCaseConferenceEntry() {
    setState(() {
      for (int i = 0; i < _caseConferenceEntries.length; i++) {
        _collapsedConferences.add(i);
      }
      _caseConferenceEntries.add(_CaseConferenceEntry(id: AppUtil.getUid()));
    });
  }

  void _removeCaseConferenceEntry(int index) {
    setState(() {
      final item = _caseConferenceEntries.removeAt(index);
      item.dispose();
      final updated = <int>{};
      for (final i in _collapsedConferences) {
        if (i < index) updated.add(i);
        if (i > index) updated.add(i - 1);
      }
      _collapsedConferences..clear()..addAll(updated);
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

  Widget _checkboxGroup({
    required String label,
    required List<String> options,
    required Map<String, String> labels,
    required Set<String> selected,
    required void Function(String option, bool checked) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 4),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blueGrey),
          ),
        ),
        ...options.map((option) {
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: selected.contains(option),
            title: Text(labels[option] ?? option, style: const TextStyle(fontSize: 13.5)),
            onChanged: (checked) => onChanged(option, checked ?? false),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _subHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: widget.color, margin: const EdgeInsets.only(right: 8)),
          Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _readOnlyInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Auto-capitalizes the first letter of every word as the user types
  Widget _capitalizedInput(TextEditingController controller, String label,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        validator: validator,
        onChanged: (value) {
          final capitalized = value.split(' ').map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1);
          }).join(' ');
          if (capitalized != value) {
            controller.value = controller.value.copyWith(
              text: capitalized,
              selection: TextSelection.collapsed(offset: capitalized.length),
            );
          }
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

  Widget _externalInformantCard(int index, _ExternalInformantEntry entry) {
    final cardLabel = entry.fullName.isNotEmpty
        ? entry.fullName
        : 'Informant ${index + 1}';
    final isCollapsed = _collapsedInformants.contains(index);

    // Pull primary client from _familyMembers
    final primaryClient = _familyMembers.isNotEmpty
        ? _familyMembers.firstWhere((m) => m.isPrimaryClient, orElse: () => _familyMembers.first)
        : null;
    final clientName = primaryClient != null ? primaryClient.fullName : (widget.clientName ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCollapsed ? Colors.blueGrey.withOpacity(0.08) : Colors.blueGrey.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (always visible) ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: widget.color.withOpacity(0.12),
                  child: Icon(Icons.person_outline, color: widget.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cardLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      if (isCollapsed && entry.purposeOfInterview.isNotEmpty)
                        Text(
                          entry.purposeOfInterview
                              .map((k) => _purposeOfInterviewLabels[k] ?? k)
                              .join(', '),
                          style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Expand / collapse button
                IconButton(
                  tooltip: isCollapsed ? 'Expand' : 'Minimise',
                  onPressed: () => setState(() {
                    if (isCollapsed) {
                      _collapsedInformants.remove(index);
                    } else {
                      _collapsedInformants.add(index);
                    }
                  }),
                  icon: AnimatedRotation(
                    turns: isCollapsed ? 0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                  ),
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 2),
                // Delete — visually separated by colour and distance from minimize
                IconButton(
                  tooltip: 'Remove informant',
                  onPressed: () => _removeExternalInformantEntry(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),

          // ── Body (hidden when collapsed) ─────────────────────
          if (!isCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subHeading('Section A: Case Information'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.color.withOpacity(0.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _readOnlyInfoRow('Case Number', widget.mgysdCase.caseNo),
                        _readOnlyInfoRow('File Number', _householdFileNumberController.text.trim().isNotEmpty
                            ? _householdFileNumberController.text.trim() : '—'),
                        _readOnlyInfoRow('Name of Client', clientName.isNotEmpty ? clientName : '—'),
                        _readOnlyInfoRow('District', _householdDistrictController.text.trim().isNotEmpty
                            ? _householdDistrictController.text.trim() : '—'),
                        _readOnlyInfoRow('Community Council', _householdCommunityCouncilController.text.trim().isNotEmpty
                            ? _householdCommunityCouncilController.text.trim() : '—'),
                        _readOnlyInfoRow('Village', _householdVillageController.text.trim().isNotEmpty
                            ? _householdVillageController.text.trim() : '—'),
                        _readOnlyInfoRow('Address', _householdAddressController.text.trim().isNotEmpty
                            ? _householdAddressController.text.trim() : '—'),
                        _readOnlyInfoRow('Name of Social Worker',
                            '${_socialWorkerFirstNameController.text.trim()} ${_socialWorkerSurnameController.text.trim()}'.trim().isNotEmpty
                                ? '${_socialWorkerFirstNameController.text.trim()} ${_socialWorkerSurnameController.text.trim()}'.trim()
                                : '—'),
                        _readOnlyInfoRow('Date of Interview', _eventDateController.text.trim().isNotEmpty
                            ? _eventDateController.text.trim() : '—'),
                      ],
                    ),
                  ),

                  // ── Section B: Informant Details ──────────────────────
                  _subHeading('Section B: Informant Details'),
                  _two(
                    _capitalizedInput(entry.firstNameController, 'First Name',
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                    _capitalizedInput(entry.surnameController, 'Surname',
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                  ),
                  _two(
                    _input(entry.ageController, 'Age', keyboardType: TextInputType.number),
                    _dropdown(
                      label: 'Gender',
                      value: entry.gender,
                      options: _genderOptions,
                      labels: _genderLabels,
                      onChanged: (v) => setState(() => entry.gender = v),
                    ),
                  ),
                  _dropdown(
                    label: 'Relationship to Client',
                    value: entry.relationshipToClient,
                    options: _informantRelationshipOptions,
                    labels: _informantRelationshipLabels,
                    onChanged: (v) => setState(() => entry.relationshipToClient = v),
                  ),
                  if (entry.relationshipToClient == 'OTHER')
                    _input(entry.relationshipToClientOtherController, 'Please specify relationship', maxLines: 2),
                  _dropdown(
                    label: 'Occupation',
                    value: entry.occupation,
                    options: _occupationOptions,
                    labels: _occupationLabels,
                    onChanged: (v) => setState(() => entry.occupation = v),
                  ),
                  if (entry.occupation == 'OTHER')
                    _input(entry.occupationOtherController, 'Please specify occupation', maxLines: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 4),
                    child: Text('Contact Details',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  ),
                  _PhoneInputField(
                    entry: entry,
                    countries: _countries,
                    accentColor: widget.color,
                    onCountryChanged: (code) => setState(() => entry.contactCountryCode = code),
                  ),
                  _input(entry.physicalAddressController, 'Physical Address', maxLines: 2),

                  // ── Section C: Purpose of Interview ───────────────────
                  _subHeading('Section C: Purpose of Interview'),
                  _checkboxGroup(
                    label: 'Select all that apply',
                    options: _purposeOfInterviewOptions,
                    labels: _purposeOfInterviewLabels,
                    selected: entry.purposeOfInterview,
                    onChanged: (option, checked) => setState(() {
                      if (checked) { entry.purposeOfInterview.add(option); } else { entry.purposeOfInterview.remove(option); }
                    }),
                  ),
                  if (entry.purposeOfInterview.contains('OTHER'))
                    _input(entry.purposeOfInterviewOtherController, 'Please specify other purpose', maxLines: 2),

                  // ── Section D: Knowledge of Client ────────────────────
                  _subHeading('Section D: Knowledge of Client'),
                  _dropdown(
                    label: 'How long have you known the client?',
                    value: entry.howLongKnown,
                    options: _howLongKnownOptions,
                    labels: _howLongKnownLabels,
                    onChanged: (v) => setState(() => entry.howLongKnown = v),
                  ),
                  _input(entry.currentSituationUnderstandingController,
                      "What is your understanding of the client's current situation?", maxLines: 4),
                  if (!entry.showResponsibleForCare)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => entry.showResponsibleForCare = true),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add who is responsible for the client's care"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.color,
                          side: BorderSide(color: widget.color.withOpacity(0.45)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (entry.showResponsibleForCare) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text("Who is responsible for the client's care / support",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => setState(() {
                            entry.showResponsibleForCare = false;
                            entry.responsibleForCareFirstNameController.clear();
                            entry.responsibleForCareSurnameController.clear();
                          }),
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                    _two(
                      _input(entry.responsibleForCareFirstNameController, 'First Name'),
                      _input(entry.responsibleForCareSurnameController, 'Surname'),
                    ),
                  ],

                  // ── Section E: Living Conditions ──────────────────────
                  _subHeading('Section E: Living Conditions and Basic Needs'),
                  _dropdown(
                    label: '1. Housing / Living Environment',
                    value: entry.housingConditionRating,
                    options: _housingConditionOptions,
                    labels: _housingConditionLabels,
                    onChanged: (v) => setState(() => entry.housingConditionRating = v),
                  ),
                  _input(entry.housingCommentsController, 'Comments', maxLines: 2),
                  _dropdown(
                    label: '2. Access to Basic Needs (food, clothing, hygiene, shelter)',
                    value: entry.basicNeedsRating,
                    options: _basicNeedsOptions,
                    labels: _basicNeedsLabels,
                    onChanged: (v) => setState(() => entry.basicNeedsRating = v),
                  ),
                  _input(entry.basicNeedsDetailsController, 'Details', maxLines: 2),
                  _dropdown(
                    label: '3. Health Status (as observed)',
                    value: entry.healthStatusRating,
                    options: _observedHealthOptions,
                    labels: _observedHealthLabels,
                    onChanged: (v) => setState(() => entry.healthStatusRating = v),
                  ),
                  _input(entry.healthStatusDetailsController, 'Details', maxLines: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 4),
                    child: Text('4. Access to Services',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  ),
                  _dropdown(
                    label: 'Health services',
                    value: entry.accessHealthServices,
                    options: _yesNoOptions,
                    labels: _yesNoLabels,
                    onChanged: (v) => setState(() => entry.accessHealthServices = v),
                  ),
                  if (entry.accessHealthServices == 'YES') ...[
                    _checkboxGroup(
                      label: 'Which health services?',
                      options: _healthServiceOptions,
                      labels: _healthServiceLabels,
                      selected: entry.healthServiceTypes,
                      onChanged: (option, checked) => setState(() {
                        if (checked) { entry.healthServiceTypes.add(option); } else { entry.healthServiceTypes.remove(option); }
                      }),
                    ),
                    if (entry.healthServiceTypes.contains('OTHER'))
                      _input(entry.healthServiceOtherController, 'Please specify other health service', maxLines: 2),
                  ],
                  _dropdown(
                    label: 'Social support',
                    value: entry.accessSocialSupport,
                    options: _yesNoOptions,
                    labels: _yesNoLabels,
                    onChanged: (v) => setState(() => entry.accessSocialSupport = v),
                  ),
                  if (entry.accessSocialSupport == 'YES') ...[
                    _checkboxGroup(
                      label: 'Which social support?',
                      options: _socialSupportOptions,
                      labels: _socialSupportLabels,
                      selected: entry.socialSupportTypes,
                      onChanged: (option, checked) => setState(() {
                        if (checked) { entry.socialSupportTypes.add(option); } else { entry.socialSupportTypes.remove(option); }
                      }),
                    ),
                    if (entry.socialSupportTypes.contains('OTHER'))
                      _input(entry.socialSupportOtherController, 'Please specify other social support', maxLines: 2),
                  ],
                  _dropdown(
                    label: 'School / work (if applicable)',
                    value: entry.accessSchoolWork,
                    options: _yesNoOptions,
                    labels: _yesNoLabels,
                    onChanged: (v) => setState(() => entry.accessSchoolWork = v),
                  ),
                  if (entry.accessSchoolWork == 'YES') ...[
                    _checkboxGroup(
                      label: 'Which school / work situation?',
                      options: _schoolWorkOptions,
                      labels: _schoolWorkLabels,
                      selected: entry.schoolWorkTypes,
                      onChanged: (option, checked) => setState(() {
                        if (checked) { entry.schoolWorkTypes.add(option); } else { entry.schoolWorkTypes.remove(option); }
                      }),
                    ),
                    if (entry.schoolWorkTypes.contains('OTHER'))
                      _input(entry.schoolWorkOtherController, 'Please specify other school / work situation', maxLines: 2),
                  ],
                  _input(entry.accessServicesCommentsController, 'Comments', maxLines: 2),

                  // ── Section F: Safety and Protection Concerns ──────────────────────
                  _subHeading('Section F: Safety and Protection Concerns'),
                  _checkboxGroup(
                    label: '1. Any concerns of abuse or exploitation?',
                    options: _abuseTypeOptions,
                    labels: _abuseTypeLabels,
                    selected: entry.abuseTypes,
                    onChanged: (option, checked) => setState(() {
                      if (checked) { entry.abuseTypes.add(option); } else { entry.abuseTypes.remove(option); }
                    }),
                  ),
                  _input(entry.abuseDetailsController, 'Details', maxLines: 3),
                  _dropdown(
                    label: '2. Signs of neglect?',
                    value: entry.signsOfNeglect,
                    options: _yesNoOptions,
                    labels: _yesNoLabels,
                    onChanged: (v) => setState(() => entry.signsOfNeglect = v),
                  ),
                  if (entry.signsOfNeglect == 'YES') ...[
                    _checkboxGroup(
                      label: 'Which signs of neglect?',
                      options: _neglectTypeOptions,
                      labels: _neglectTypeLabels,
                      selected: entry.neglectTypes,
                      onChanged: (option, checked) => setState(() {
                        if (checked) { entry.neglectTypes.add(option); } else { entry.neglectTypes.remove(option); }
                      }),
                    ),
                    if (entry.neglectTypes.contains('OTHER'))
                      _input(entry.neglectTypeOtherController, 'Please specify other sign of neglect', maxLines: 2),
                  ],
                  _input(entry.neglectDetailsController, 'Details', maxLines: 2),
                  _checkboxGroup(
                    label: '3. Exposure to risk factors',
                    options: _riskFactorOptions,
                    labels: _riskFactorLabels,
                    selected: entry.riskFactors,
                    onChanged: (option, checked) => setState(() {
                      if (checked) { entry.riskFactors.add(option); } else { entry.riskFactors.remove(option); }
                    }),
                  ),
                  if (entry.riskFactors.contains('OTHER'))
                    _input(entry.riskFactorOtherController, 'Please specify other risk factor', maxLines: 2),

                  // ── Section G: Functioning and Well-being ─────────────────────────
                  _subHeading('Section G: Functioning and Well-being'),
                  _input(entry.dailyFunctioningController, 'How does the client function in daily life?', maxLines: 3),
                  _checkboxGroup(
                    label: 'Social behaviour (tick any observed)',
                    options: _socialBehaviourOptions,
                    labels: _socialBehaviourLabels,
                    selected: entry.socialBehaviours,
                    onChanged: (option, checked) => setState(() {
                      if (checked) { entry.socialBehaviours.add(option); } else { entry.socialBehaviours.remove(option); }
                    }),
                  ),
                  _input(entry.behaviourCommentsController, 'Comments', maxLines: 2),

                  // ── Section H: Social Support and Community Context ───────────────
                  _subHeading('Section H: Social Support and Community Context'),
                  _dropdown(
                    label: 'Does the client have family or community support?',
                    value: entry.familySupportLevel,
                    options: _familySupportOptions,
                    labels: _familySupportLabels,
                    onChanged: (v) => setState(() => entry.familySupportLevel = v),
                  ),
                  _input(entry.familySupportExplainController, 'Explain', maxLines: 2),
                  _input(entry.communityPerceptionController, 'How is the client perceived in the community?', maxLines: 3),
                  _input(entry.knownHistoryController, 'Any known history of issues (violence, neglect, conflict)?', maxLines: 3),

                  // ── Section I: Informant's Opinion / Recommendations ──────────────
                  _subHeading("Section I: Informant's Opinion / Recommendations"),
                  _input(entry.keyChallengesController, 'What do you think are the key challenges facing the client?', maxLines: 4),
                  _input(entry.recommendationsController, 'What support or intervention do you recommend?', maxLines: 4),

                  // ── Section J: Reliability of Information ─────────────────────────
                  _subHeading('Section J: Reliability of Information'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('To be completed by Social Worker',
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                  ),
                  _dropdown(
                    label: 'Informant credibility',
                    value: entry.informantCredibility,
                    options: _credibilityOptions,
                    labels: _credibilityLabels,
                    onChanged: (v) => setState(() => entry.informantCredibility = v),
                  ),
                  _input(entry.credibilityReasonsController, 'Reasons', maxLines: 3),

                  // ── Section K: Social Worker's Summary Notes ──────────────────────
                  _subHeading('Section K: Social Worker\'s Summary Notes'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('To be completed by Social Worker',
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                  ),
                  _input(entry.socialWorkerSummaryNotesController, 'Summary notes', maxLines: 6),

                  // ── Section L: Risk Level Assessment ──────────────────────────────
                  _subHeading('Section L: Risk Level Assessment'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('To be completed by Social Worker',
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                  ),
                  _dropdown(
                    label: 'Risk Level',
                    value: entry.riskLevel,
                    options: _riskLevelOptions,
                    labels: _riskLevelLabels,
                    onChanged: (v) => setState(() => entry.riskLevel = v),
                  ),

                  // ── Section M: Confidentiality Statement ──────────────────────────
                  _subHeading('Section M: Confidentiality Statement'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.25),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign_outlined, color: Colors.amber.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Read aloud to the informant before proceeding',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Information provided will be used strictly for social work and protection purposes and will be treated with confidentiality.',
                          style: TextStyle(fontSize: 14.5, color: Colors.black87, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ], // end if (!isCollapsed)
        ],
      ),
    );
  }

  Widget _caseConferenceCard(int index, _CaseConferenceEntry entry) {
    final isCollapsed = _collapsedConferences.contains(index);
    final dateLabel = entry.conferenceDateController.text.trim();
    final cardLabel = dateLabel.isNotEmpty
        ? 'Conference — $dateLabel'
        : 'Case Conference ${index + 1}';

    final primaryClient = _familyMembers.isNotEmpty
        ? _familyMembers.firstWhere((m) => m.isPrimaryClient, orElse: () => _familyMembers.first)
        : null;
    final clientName = primaryClient != null ? primaryClient.fullName : (widget.clientName ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCollapsed ? Colors.blueGrey.withOpacity(0.08) : Colors.blueGrey.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: widget.color.withOpacity(0.12),
                  child: Icon(Icons.groups_outlined, color: widget.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cardLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      if (isCollapsed && entry.conferenceType.isNotEmpty)
                        Text(
                          _conferenceTypeLabels[entry.conferenceType] ?? entry.conferenceType,
                          style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isCollapsed ? 'Expand' : 'Minimise',
                  onPressed: () => setState(() {
                    if (isCollapsed) { _collapsedConferences.remove(index); }
                    else { _collapsedConferences.add(index); }
                  }),
                  icon: AnimatedRotation(
                    turns: isCollapsed ? 0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                  ),
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Remove conference',
                  onPressed: () => _removeCaseConferenceEntry(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),

          if (!isCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Auto-filled case info ──────────────────────────────
                  _subHeading('Case Information'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.color.withOpacity(0.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _readOnlyInfoRow('Case Number', widget.mgysdCase.caseNo),
                        _readOnlyInfoRow('File Number', _householdFileNumberController.text.trim().isNotEmpty
                            ? _householdFileNumberController.text.trim() : '—'),
                        _readOnlyInfoRow('Name of Client', clientName.isNotEmpty ? clientName : '—'),
                        _readOnlyInfoRow('Social Worker',
                            '${_socialWorkerFirstNameController.text.trim()} ${_socialWorkerSurnameController.text.trim()}'.trim().isNotEmpty
                                ? '${_socialWorkerFirstNameController.text.trim()} ${_socialWorkerSurnameController.text.trim()}'.trim()
                                : '—'),
                      ],
                    ),
                  ),

                  // ── Conference details ─────────────────────────────────
                  _subHeading('Conference Details'),
                  _two(
                    _input(entry.conferenceDateController, 'Date of Conference',
                        readOnly: true,
                        onTap: () => _pickConferenceDate(entry.conferenceDateController),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                    _input(entry.conferenceTimeController, 'Time of Conference',
                        readOnly: true,
                        onTap: () => _pickConferenceTime(entry.conferenceTimeController)),
                  ),
                  _two(
                    _dropdown(
                      label: 'Type of Case Conference',
                      value: entry.conferenceType,
                      options: _conferenceTypeOptions,
                      labels: _conferenceTypeLabels,
                      onChanged: (v) => setState(() => entry.conferenceType = v),
                    ),
                    _dropdown(
                      label: 'Location',
                      value: entry.locationType,
                      options: _conferenceLocationOptions,
                      labels: _conferenceLocationLabels,
                      onChanged: (v) => setState(() => entry.locationType = v),
                    ),
                  ),
                  if (entry.locationType == 'OFFICE' || entry.locationType == 'OTHER')
                    _input(entry.locationOtherController, 'Specify location'),
                  _dropdown(
                    label: 'Aim of Case Conference',
                    value: entry.aimOfConference,
                    options: _conferenceAimOptions,
                    labels: _conferenceAimLabels,
                    onChanged: (v) => setState(() => entry.aimOfConference = v),
                  ),
                  if (entry.aimOfConference == 'OTHER')
                    _input(entry.aimOtherController, 'Please specify aim', maxLines: 2),

                  // ── Non-family participants ────────────────────────────
                  _subHeading('Non-Family Participants'),
                  const Text('Names and agencies of all non-family participants',
                      style: TextStyle(fontSize: 12.5, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  if (entry.nonFamilyParticipants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('No non-family participants added.',
                          style: TextStyle(fontSize: 13, color: Colors.blueGrey.withOpacity(0.7),
                              fontStyle: FontStyle.italic)),
                    ),
                  ...List.generate(entry.nonFamilyParticipants.length, (i) {
                    final row = entry.nonFamilyParticipants[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _capitalizedInput(row['name']!, 'Name')),
                          const SizedBox(width: 8),
                          Expanded(flex: 5, child: _capitalizedInput(row['agency']!, 'Agency / Organisation')),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => setState(() {
                              row['name']!.dispose();
                              row['agency']!.dispose();
                              entry.nonFamilyParticipants.removeAt(i);
                            }),
                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                            color: Colors.redAccent,
                            padding: const EdgeInsets.only(top: 4),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      entry.nonFamilyParticipants.add(_CaseConferenceEntry._newParticipantRow());
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add non-family participant'),
                  ),

                  // ── Family participants ────────────────────────────────
                  _subHeading('Family Participants'),
                  const Text('Names of all family participants (including client)',
                      style: TextStyle(fontSize: 12.5, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  if (entry.familyParticipants.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('No family participants added.',
                          style: TextStyle(fontSize: 13, color: Colors.blueGrey.withOpacity(0.7),
                              fontStyle: FontStyle.italic)),
                    ),
                  ...List.generate(entry.familyParticipants.length, (i) {
                    final row = entry.familyParticipants[i];
                    final rel = row['relationship'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Family Member ${i + 1}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ),
                              IconButton(
                                onPressed: () => setState(() {
                                  (row['firstName'] as TextEditingController).dispose();
                                  (row['surname'] as TextEditingController).dispose();
                                  (row['relationshipOther'] as TextEditingController).dispose();
                                  entry.familyParticipants.removeAt(i);
                                }),
                                icon: const Icon(Icons.remove_circle_outline, size: 18),
                                color: Colors.redAccent,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _two(
                            _capitalizedInput(row['firstName'] as TextEditingController, 'First Name'),
                            _capitalizedInput(row['surname'] as TextEditingController, 'Surname'),
                          ),
                          _dropdown(
                            label: 'Relationship to Client',
                            value: rel,
                            options: _familyRelationshipOptions,
                            labels: _familyRelationshipLabels,
                            onChanged: (v) => setState(() => row['relationship'] = v),
                          ),
                          if (rel == 'OTHER')
                            _input(row['relationshipOther'] as TextEditingController,
                                'Please specify relationship', maxLines: 2),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      entry.familyParticipants.add(_CaseConferenceEntry._newFamilyRow());
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add family member'),
                  ),

                  // ── Discussion & outcomes ──────────────────────────────
                  _subHeading('Discussion & Outcomes'),
                  _input(entry.keyDiscussionPointsController,
                      'Key Discussion Points (biopsychosocial factors)', maxLines: 5),
                  _input(entry.keyOutcomesController, 'Key Outcomes of Meeting', maxLines: 4),
                  _input(entry.observationsOnDynamicsController,
                      'Any Observations on Dynamics of Meeting', maxLines: 4),

                  // ── Client consultation ────────────────────────────────
                  _subHeading('Client Consultation'),
                  _dropdown(
                    label: 'Did you have the opportunity to speak with the client individually?',
                    value: entry.clientSpokenToIndividually,
                    options: _yesNoOptions,
                    labels: _yesNoLabels,
                    onChanged: (v) => setState(() => entry.clientSpokenToIndividually = v),
                  ),
                  if (entry.clientSpokenToIndividually == 'YES')
                    _input(entry.clientConsultationOutcomeController,
                        'Outcome of the discussion', maxLines: 4),
                  if (entry.clientSpokenToIndividually == 'NO')
                    _input(entry.clientConsultationOutcomeController,
                        'Note date for follow-up visit', readOnly: true,
                        onTap: () => _pickDate(entry.clientConsultationOutcomeController)),

                  // ── Next conference / follow-up ────────────────────────
                  _subHeading('Next Case Conference / Follow-up'),
                  _input(entry.nextConferenceDateController, 'Date',
                      readOnly: true, onTap: () => _pickDate(entry.nextConferenceDateController)),
                  _two(
                    _dropdown(
                      label: 'Type',
                      value: entry.nextConferenceType,
                      options: _conferenceTypeOptions,
                      labels: _conferenceTypeLabels,
                      onChanged: (v) => setState(() => entry.nextConferenceType = v),
                    ),
                    _dropdown(
                      label: 'Location',
                      value: entry.nextConferenceLocation,
                      options: _conferenceLocationOptions,
                      labels: _conferenceLocationLabels,
                      onChanged: (v) => setState(() => entry.nextConferenceLocation = v),
                    ),
                  ),
                  if (entry.nextConferenceLocation == 'OFFICE' || entry.nextConferenceLocation == 'OTHER')
                    _input(entry.nextConferenceLocationOtherController, 'Specify location'),
                  _input(entry.nextConferencePurposeController,
                      'Type, location, purpose and aim', maxLines: 3),
                ],
              ),
            ),
          ], // end if (!isCollapsed)
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
            'Part 4: Supplementary Assessments',
            'Optional records gathered outside the core investigation — external informant interviews and case conference proceedings.',
          ),

          // ── External Informant Interviews ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text('External Informant Interviews',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: widget.color)),
          ),
          if (_externalInformantEntries.isEmpty)
            _optionalAddCard(
              title: 'External Informant',
              subtitle: 'Add an interview with a neighbour, teacher, community leader, relative, nurse or other external source.',
              icon: Icons.record_voice_over_outlined,
              onAdd: _addExternalInformantEntry,
            ),
          if (_externalInformantEntries.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(
                  child: Text('External Informants',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addExternalInformantEntry,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add informant'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(
              _externalInformantEntries.length,
                  (index) => _externalInformantCard(index, _externalInformantEntries[index]),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),

          // ── Case Conference Records ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text('Case Conference Records',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: widget.color)),
          ),
          if (_caseConferenceEntries.isEmpty)
            _optionalAddCard(
              title: 'Case Conference Record',
              subtitle: 'Add a record when a multi-party case conference has been held.',
              icon: Icons.groups_outlined,
              onAdd: _addCaseConferenceEntry,
            ),
          if (_caseConferenceEntries.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(
                  child: Text('Case Conferences',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addCaseConferenceEntry,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add conference'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(
              _caseConferenceEntries.length,
                  (index) => _caseConferenceCard(index, _caseConferenceEntries[index]),
            ),
          ],
        ],
      ),
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