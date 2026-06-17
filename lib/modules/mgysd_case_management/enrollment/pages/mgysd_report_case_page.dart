import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lncmis_mobile_app/app_state/current_user_state/current_user_state.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/core/utils/form_util.dart';
import 'package:lncmis_mobile_app/core/services/organisation_unit_service.dart';
import 'package:lncmis_mobile_app/models/organisation_unit.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:provider/provider.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:sqflite/sqflite.dart';

class MgysdRecordCasePage extends StatefulWidget {
  const MgysdRecordCasePage({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdRecordCasePage> createState() => _MgysdRecordCasePageState();
}

enum MgysdFieldType {
  option,
  boolean,
  date,
  integer,
  phone,
  textShort,
  textLong,
}

class MgysdOption {
  final String code;
  final String label;

  const MgysdOption({
    required this.code,
    required this.label,
  });
}



class MgysdTitleCaseTextFormatter extends TextInputFormatter {
  const MgysdTitleCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final formatted = _toTitleCase(newValue.text);
    if (formatted == newValue.text) return newValue;

    final selectionEnd = newValue.selection.end;
    final safeOffset = selectionEnd < 0
        ? formatted.length
        : selectionEnd.clamp(0, formatted.length).toInt();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: safeOffset),
      composing: TextRange.empty,
    );
  }

  static String _toTitleCase(String value) {
    final buffer = StringBuffer();
    var capitaliseNext = true;

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final isLetter = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(char);

      if (isLetter) {
        buffer.write(capitaliseNext ? char.toUpperCase() : char.toLowerCase());
        capitaliseNext = false;
      } else {
        buffer.write(char);
        capitaliseNext = char.trim().isEmpty || char == '-' || char == "'" || char == '’';
      }
    }

    return buffer.toString();
  }
}

class MgysdCountryCodeOption {
  final String code;
  final String label;
  final String dialCode;
  final int minNationalDigits;
  final int maxNationalDigits;
  final List<String> allowedNationalPrefixes;
  final String prefixHint;
  final bool useNanpRules;

  const MgysdCountryCodeOption({
    required this.code,
    required this.label,
    required this.dialCode,
    this.minNationalDigits = 7,
    this.maxNationalDigits = 12,
    this.allowedNationalPrefixes = const [],
    this.prefixHint = '',
    this.useNanpRules = false,
  });
}

class MgysdPhoneNumberInputFormatter extends TextInputFormatter {
  final MgysdCountryCodeOption country;

  const MgysdPhoneNumberInputFormatter(this.country);

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

    // If the user pastes a full number such as +26658881234 or 26658881234,
    // keep only the national part because the country code is already selected.
    if (digits.startsWith(dialDigits) && digits.length > dialDigits.length) {
      digits = digits.substring(dialDigits.length);
    }

    // Remove a leading trunk 0 so countries like South Africa/UK can be typed
    // as 082... or 071... while still storing only the national digits after +code.
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

class MgysdFormFieldDef {
  final String id;
  final String label;
  final MgysdFieldType type;
  final bool requiredField;
  final List<MgysdOption> options;
  final int? maxLen;

  const MgysdFormFieldDef({
    required this.id,
    required this.label,
    required this.type,
    this.requiredField = false,
    this.options = const [],
    this.maxLen,
  });
}

class MgysdClientEntry {
  final String localId;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController ageController;
  final TextEditingController phoneController;
  final TextEditingController alternatePhoneController;
  final TextEditingController districtController;
  final TextEditingController communityCouncilController;
  final TextEditingController physicalAddressController;
  final TextEditingController relationshipOtherController;

  String sex;
  String contactNumberType;
  String phoneCountryCode;
  String alternatePhoneCountryCode;
  String relationshipToClient;
  String districtOrgUnit;
  String communityCouncilOrgUnit;

  MgysdClientEntry({
    required this.localId,
    String firstName = '',
    String lastName = '',
    String age = '',
    String phone = '',
    String alternatePhone = '',
    String district = '',
    String communityCouncil = '',
    String physicalAddress = '',
    String relationshipOther = '',
    this.sex = '',
    this.contactNumberType = '',
    this.phoneCountryCode = 'LS',
    this.alternatePhoneCountryCode = 'LS',
    this.relationshipToClient = '',
    this.districtOrgUnit = '',
    this.communityCouncilOrgUnit = '',
  })  : firstNameController = TextEditingController(text: firstName),
        lastNameController = TextEditingController(text: lastName),
        ageController = TextEditingController(text: age),
        phoneController = TextEditingController(text: phone),
        alternatePhoneController = TextEditingController(text: alternatePhone),
        districtController = TextEditingController(text: district),
        communityCouncilController = TextEditingController(text: communityCouncil),
        physicalAddressController = TextEditingController(text: physicalAddress),
        relationshipOtherController = TextEditingController(text: relationshipOther);

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    alternatePhoneController.dispose();
    districtController.dispose();
    communityCouncilController.dispose();
    physicalAddressController.dispose();
    relationshipOtherController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'age': ageController.text.trim(),
      'sex': sex,
      'contactNumberType': contactNumberType,
      'phoneCountryCode': phoneCountryCode,
      'alternatePhoneCountryCode': alternatePhoneCountryCode,
      'phone': phoneController.text.trim(),
      'alternatePhone': alternatePhoneController.text.trim(),
      'district': districtController.text.trim(),
      'districtOrgUnit': districtOrgUnit,
      'communityCouncil': communityCouncilController.text.trim(),
      'communityCouncilOrgUnit': communityCouncilOrgUnit,
      'relationshipToClient': relationshipToClient,
      'relationshipToClientOther': relationshipOtherController.text.trim(),
      'physicalAddress': physicalAddressController.text.trim(),
      // Kept for backward compatibility with any existing readers that expect this key.
      'howToContactClient': physicalAddressController.text.trim(),
    };
  }
}
class MgysdPersonInvolvedEntry {
  final String localId;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController roleOtherController;

  String roleOrRelationship;

  MgysdPersonInvolvedEntry({
    required this.localId,
    String firstName = '',
    String lastName = '',
    String roleOther = '',
    this.roleOrRelationship = '',
  })  : firstNameController = TextEditingController(text: firstName),
        lastNameController = TextEditingController(text: lastName),
        roleOtherController = TextEditingController(text: roleOther);

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    roleOtherController.dispose();
  }

  Map<String, dynamic> toJson() {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    return {
      'firstName': firstName,
      'lastName': lastName,
      'name': [firstName, lastName].where((part) => part.isNotEmpty).join(' '),
      'roleOrRelationship': roleOrRelationship,
      'roleOrRelationshipOther': roleOtherController.text.trim(),
    };
  }
}

class _MgysdRecordCasePageState extends State<MgysdRecordCasePage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _values = {};
  bool _submitting = false;
  bool _loadingLocationTree = true;

  final List<OrganisationUnit> _districts = [];
  final List<OrganisationUnit> _communityCouncils = [];

  static const int districtOrgUnitLevel = 2;
  static const int communityCouncilOrgUnitLevel = 3;

  static const String mgysdReportProgram = MgysdDhis2Uids.reportedCasesEventProgram;
  static const String mgysdReportProgramStage = MgysdDhis2Uids.reportedCasesProgramStage;

  static const String deReporterFirstName = MgysdDhis2Uids.deReporterFirstName;
  static const String deReporterLastName = MgysdDhis2Uids.deReporterLastName;
  static const String deReporterVillage = MgysdDhis2Uids.deReporterVillage;
  static const String deChiefFirstName = MgysdDhis2Uids.deChiefFirstName;
  static const String deChiefLastName = MgysdDhis2Uids.deChiefLastName;
  static const String deReporterPhone = MgysdDhis2Uids.deReporterPhone;
  static const String deReporterAltPhone = MgysdDhis2Uids.deReporterAltPhone;
  static const String deReporterRelationship = MgysdDhis2Uids.deReporterRelationship;
  static const String deReporterRelationshipOther = MgysdDhis2Uids.deReporterRelationshipOther;
  static const String deReporterAnonymous = MgysdDhis2Uids.deReporterAnonymous;

  static const String deReporterPhysicalAddress =
      MgysdDhis2Uids.deReporterPhysicalAddress;
  static const String deReporterDob = MgysdDhis2Uids.deReporterDob;
  static const String deReporterAge = MgysdDhis2Uids.deReporterAge;
  static const String deReporterSex = MgysdDhis2Uids.deReporterSex;

  static const String deClientsJson = MgysdDhis2Uids.deClientsJson;
  static const String dePeopleInvolvedJson = MgysdDhis2Uids.dePeopleInvolvedJson;

  // Concern-related data elements
  static const String deConcernReason = MgysdDhis2Uids.deConcernReason;
  static const String deConcernReasonOther = MgysdDhis2Uids.deConcernReasonOther;
  static const String deIncidentDescription = MgysdDhis2Uids.deIncidentDescription;
  static const String deWhenHappened = MgysdDhis2Uids.deWhenHappened;
  static const String deIncidentLocation = MgysdDhis2Uids.deIncidentLocation;

  final List<MgysdClientEntry> _clients = [];
  final List<MgysdPersonInvolvedEntry> _peopleInvolved = [];

  final Set<String> _selectedConcernReasons = {};
  final TextEditingController _concernOtherController = TextEditingController();

  final Map<String, String> _phoneCountryCodes = {
    deReporterPhone: 'LS',
    deReporterAltPhone: 'LS',
  };


  List<MgysdFormFieldDef> get aboutReporterFields => const [
    MgysdFormFieldDef(
      id: deReporterAnonymous,
      label: 'Reporter wants to remain anonymous',
      type: MgysdFieldType.boolean,
      requiredField: true,
    ),
    MgysdFormFieldDef(
      id: deReporterFirstName,
      label: 'Reporter First name',
      type: MgysdFieldType.textShort,
      maxLen: 40,
    ),
    MgysdFormFieldDef(
      id: deReporterLastName,
      label: 'Reporter Last name',
      type: MgysdFieldType.textShort,
      maxLen: 40,
    ),
    MgysdFormFieldDef(
      id: deReporterDob,
      label: 'Date of Birth',
      type: MgysdFieldType.date,
    ),
    MgysdFormFieldDef(
      id: deReporterAge,
      label: 'Age',
      type: MgysdFieldType.integer,
    ),
    MgysdFormFieldDef(
      id: deReporterSex,
      label: 'Sex',
      type: MgysdFieldType.option,
      options: [
        MgysdOption(code: 'Male', label: 'Male'),
        MgysdOption(code: 'Female', label: 'Female'),
      ],
    ),
    MgysdFormFieldDef(
      id: deReporterVillage,
      label: 'Reporter Village',
      type: MgysdFieldType.textShort,
      maxLen: 80,
    ),
    MgysdFormFieldDef(
      id: deReporterPhysicalAddress,
      label: 'Physical Address',
      type: MgysdFieldType.textLong,
    ),
    MgysdFormFieldDef(
      id: deChiefFirstName,
      label: 'Chief First name',
      type: MgysdFieldType.textShort,
      maxLen: 40,
    ),
    MgysdFormFieldDef(
      id: deChiefLastName,
      label: 'Chief Last name',
      type: MgysdFieldType.textShort,
      maxLen: 40,
    ),
    MgysdFormFieldDef(
      id: deReporterPhone,
      label: 'Reporter phone',
      type: MgysdFieldType.phone,
      requiredField: true,
    ),
    MgysdFormFieldDef(
      id: deReporterAltPhone,
      label: 'Alternate phone',
      type: MgysdFieldType.phone,
    ),
  ];

  // Updated concernFields order:
  // 1) Date incident happened (deWhenHappened)
  // 2) Location (deIncidentLocation)
  // 3) Concern reason (multi-select)
  // 4) Incident description
  List<MgysdFormFieldDef> get concernFields => const [
    MgysdFormFieldDef(
      id: deWhenHappened,
      label: 'Date incident happened',
      type: MgysdFieldType.date,
    ),
    MgysdFormFieldDef(
      id: deIncidentLocation,
      label: 'Location of incident',
      type: MgysdFieldType.textShort,
      maxLen: 120,
    ),
    MgysdFormFieldDef(
      id: deConcernReason,
      label: 'Concern reason',
      type: MgysdFieldType.option,
      requiredField: true,
      options: [
        MgysdOption(code: 'Physical violence', label: 'Physical violence'),
        MgysdOption(code: 'Sexual violence', label: 'Sexual violence'),
        MgysdOption(code: 'Low socio-economic status', label: 'Low socio-economic status'),
        MgysdOption(
          code: 'Exclusion/inclusion error(ISSN/NISSA)',
          label: 'Exclusion/inclusion error (ISSN/NISSA)',
        ),
        MgysdOption(code: 'Work exploitation', label: 'Work exploitation'),
        MgysdOption(code: 'EMOTIONAL', label: 'Emotional violence'),
        MgysdOption(code: 'CHILD_MARRIAGE', label: 'Child marriage'),
        MgysdOption(code: 'FINANCIAL', label: 'Financial exploitation'),
        MgysdOption(code: 'SPECIAL_NEEDS', label: 'Special needs'),
        MgysdOption(code: 'GRIEVANCE', label: 'Grievance'),
        MgysdOption(code: 'MENTAL_HEALTH', label: 'Mental Health'),
        MgysdOption(code: 'HEALTH', label: 'Health'),
        MgysdOption(code: 'SUBSTANCE', label: 'Substance abuse'),
        MgysdOption(code: 'SAFETY_SECURITY', label: 'Safety and Security'),
        MgysdOption(code: 'OTHER', label: 'Other'),
      ],
    ),
    MgysdFormFieldDef(
      id: deIncidentDescription,
      label: 'Describe the incident that has made you concerned',
      type: MgysdFieldType.textLong,
      requiredField: true,
    ),
  ];

  static const List<MgysdOption> _sexOptions = [
    MgysdOption(code: 'Male', label: 'Male'),
    MgysdOption(code: 'Female', label: 'Female'),
  ];


  static const List<MgysdCountryCodeOption> _phoneCountryOptions = [
    MgysdCountryCodeOption(
      code: 'LS',
      label: 'Lesotho (+266)',
      dialCode: '+266',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['5', '6'],
      prefixHint: 'Lesotho mobile numbers must start with 5 or 6',
    ),
    MgysdCountryCodeOption(
      code: 'ZA',
      label: 'South Africa (+27)',
      dialCode: '+27',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: [
        '60',
        '61',
        '62',
        '63',
        '64',
        '65',
        '66',
        '67',
        '68',
        '71',
        '72',
        '73',
        '74',
        '76',
        '78',
        '79',
        '81',
        '82',
        '83',
        '84',
      ],
      prefixHint: 'South African mobile numbers usually start with 6, 7 or 8 ranges such as 60, 71 or 82',
    ),
    MgysdCountryCodeOption(
      code: 'BW',
      label: 'Botswana (+267)',
      dialCode: '+267',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['71', '72', '73', '74', '75', '76'],
      prefixHint: 'Botswana mobile numbers must start with 71, 72, 73, 74, 75 or 76',
    ),
    MgysdCountryCodeOption(
      code: 'SZ',
      label: 'Eswatini (+268)',
      dialCode: '+268',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['75', '76', '77', '78', '79'],
      prefixHint: 'Eswatini mobile numbers must start with 75, 76, 77, 78 or 79',
    ),
    MgysdCountryCodeOption(
      code: 'ZW',
      label: 'Zimbabwe (+263)',
      dialCode: '+263',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['71', '73', '77', '78'],
      prefixHint: 'Zimbabwe mobile numbers must start with 71, 73, 77 or 78',
    ),
    MgysdCountryCodeOption(
      code: 'MZ',
      label: 'Mozambique (+258)',
      dialCode: '+258',
      minNationalDigits: 8,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['82', '83', '84', '85', '86', '87'],
      prefixHint: 'Mozambique mobile numbers must start with 82, 83, 84, 85, 86 or 87',
    ),
    MgysdCountryCodeOption(
      code: 'MW',
      label: 'Malawi (+265)',
      dialCode: '+265',
      minNationalDigits: 7,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['1', '3', '7', '8', '9'],
      prefixHint: 'Malawi numbers must start with an allocated range such as 1, 3, 7, 8 or 9',
    ),
    MgysdCountryCodeOption(
      code: 'NA',
      label: 'Namibia (+264)',
      dialCode: '+264',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['81', '82', '83', '84', '85'],
      prefixHint: 'Namibia mobile/electronic communications numbers must start with 81, 82, 83, 84 or 85',
    ),
    MgysdCountryCodeOption(
      code: 'US',
      label: 'USA/Canada (+1)',
      dialCode: '+1',
      minNationalDigits: 10,
      maxNationalDigits: 10,
      useNanpRules: true,
      prefixHint: 'USA/Canada numbers must follow NANP format: area code and exchange code start with 2-9',
    ),
    MgysdCountryCodeOption(
      code: 'GB',
      label: 'United Kingdom (+44)',
      dialCode: '+44',
      minNationalDigits: 10,
      maxNationalDigits: 10,
      allowedNationalPrefixes: ['7'],
      prefixHint: 'UK mobile numbers must start with 7 after the +44 country code',
    ),
    MgysdCountryCodeOption(
      code: 'INTL',
      label: 'Other country (use + code)',
      dialCode: '+',
      minNationalDigits: 8,
      maxNationalDigits: 15,
    ),
  ];

  static const List<MgysdOption> _clientContactNumberTypeOptions = [
    MgysdOption(code: 'Client phone', label: 'Client phone'),
    MgysdOption(code: 'Alternative number', label: 'Alternative'),
    MgysdOption(code: 'Both', label: 'Both'),
  ];

  static const List<MgysdOption> _reporterRelationshipOptions = [
    MgysdOption(code: 'Parent', label: 'Parent'),
    MgysdOption(code: 'Relative', label: 'Relative'),
    MgysdOption(code: 'Neighbour', label: 'Neighbour'),
    MgysdOption(code: 'Teacher', label: 'Teacher'),
    MgysdOption(code: 'Priest', label: 'Priest'),
    MgysdOption(code: 'Other', label: 'Other'),
  ];

  static const List<MgysdOption> _peopleInvolvedRelationshipOptions = [
    MgysdOption(code: 'Mother', label: 'Mother'),
    MgysdOption(code: 'Father', label: 'Father'),
    MgysdOption(code: 'Spouse', label: 'Spouse'),
    MgysdOption(code: 'Siblings', label: 'Siblings'),
    MgysdOption(code: 'Son', label: 'Son'),
    MgysdOption(code: 'Daughter', label: 'Daughter'),
    MgysdOption(code: 'Other', label: 'Other'),
  ];

  @override
  void initState() {
    super.initState();

    for (final f in [...aboutReporterFields, ...concernFields]) {
      _values.putIfAbsent(f.id, () {
        if (f.type == MgysdFieldType.boolean) return 'false';
        return '';
      });
    }

    // initialize selected concerns from saved value if present
    final saved = (_values[deConcernReason] ?? '').trim();
    if (saved.isNotEmpty) {
      _selectedConcernReasons.addAll(
        saved.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }

    // initialize other description if present
    final otherSaved = (_values[deConcernReasonOther] ?? '').trim();
    if (otherSaved.isNotEmpty) {
      _concernOtherController.text = otherSaved;
    }

    _addClient();
    _loadLocationTree();
  }

  @override
  void dispose() {
    for (final client in _clients) {
      client.dispose();
    }
    for (final person in _peopleInvolved) {
      person.dispose();
    }
    _concernOtherController.dispose();
    super.dispose();
  }

  bool get _reporterIsAnonymous =>
      (_values[deReporterAnonymous] ?? 'false') == 'true';

  Color get _softBg => const Color(0xFFF6F7FB);

  Widget _requiredLabel(String label, {required bool requiredField}) {
    if (!requiredField) return Text(label);

    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.black87),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(
      String label, {
        IconData? icon,
        String? hint,
        bool requiredField = false,
      }) {
    return InputDecoration(
      label: _requiredLabel(label, requiredField: requiredField),
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      isDense: true,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.color, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  double _contentMaxWidth(double screenWidth) {
    if (screenWidth >= 1100) return 900;
    if (screenWidth >= 800) return 740;
    return screenWidth;
  }

  bool _twoCols(double width) => width >= 420;

  Future<void> _loadLocationTree() async {
    try {
      final districts = await OrganisationUnitService()
          .getOrganisationUnitsByLevel(districtOrgUnitLevel);
      final councils = await OrganisationUnitService()
          .getOrganisationUnitsByLevel(communityCouncilOrgUnitLevel);

      districts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      councils.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      if (!mounted) return;
      setState(() {
        _districts
          ..clear()
          ..addAll(districts);
        _communityCouncils
          ..clear()
          ..addAll(councils);
        _loadingLocationTree = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLocationTree = false;
      });
    }
  }

  List<OrganisationUnit> _communityCouncilsForDistrict(String districtId) {
    if (districtId.trim().isEmpty) return const [];

    return _communityCouncils.where((ou) {
      return (ou.parent ?? '').trim() == districtId.trim();
    }).toList();
  }

  String _orgUnitNameById(List<OrganisationUnit> orgUnits, String id) {
    for (final orgUnit in orgUnits) {
      if ((orgUnit.id ?? '') == id) {
        return (orgUnit.name ?? '').trim();
      }
    }
    return '';
  }

  String? _requiredValidator(String? v, {required bool requiredField}) {
    if (!requiredField) return null;
    if ((v ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  static const List<TextInputFormatter> _titleCaseInputFormatters = [
    MgysdTitleCaseTextFormatter(),
  ];

  static final List<TextInputFormatter> _nameInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ\s'’\-]")),
    const MgysdTitleCaseTextFormatter(),
  ];

  bool _isNameFieldId(String id) {
    return id == deReporterFirstName ||
        id == deReporterLastName ||
        id == deChiefFirstName ||
        id == deChiefLastName;
  }

  String? _nameValidator(String? v, {required bool requiredField}) {
    final requiredError = _requiredValidator(v, requiredField: requiredField);
    if (requiredError != null) return requiredError;

    final value = (v ?? '').trim();
    if (value.isEmpty) return null;

    final validName = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ]+(?:[\s'’\-][A-Za-zÀ-ÖØ-öø-ÿ]+)*$");
    if (!validName.hasMatch(value)) {
      return 'Use letters only';
    }

    return null;
  }

  MgysdCountryCodeOption _phoneCountryByCode(String code) {
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
      MgysdCountryCodeOption country,
      ) {
    return nationalDigits.length >= country.minNationalDigits &&
        nationalDigits.length <= country.maxNationalDigits;
  }

  bool _hasValidNetworkPrefix(
      String nationalDigits,
      MgysdCountryCodeOption country,
      ) {
    if (country.code == 'INTL') return true;

    if (country.useNanpRules) {
      return RegExp(r'^[2-9][0-9]{2}[2-9][0-9]{6}$')
          .hasMatch(nationalDigits);
    }

    if (country.allowedNationalPrefixes.isEmpty) return true;

    return country.allowedNationalPrefixes.any(nationalDigits.startsWith);
  }

  String _phoneLengthMessage(MgysdCountryCodeOption country) {
    if (country.minNationalDigits == country.maxNationalDigits) {
      return '${country.label} numbers must have ${country.maxNationalDigits} digits after ${country.dialCode}';
    }

    return '${country.label} numbers must have ${country.minNationalDigits} to ${country.maxNationalDigits} digits after ${country.dialCode}';
  }

  void _validateNationalPhoneDigits(
      String nationalDigits,
      MgysdCountryCodeOption country,
      ) {
    if (!_hasValidNationalLength(nationalDigits, country)) {
      throw FormatException(_phoneLengthMessage(country));
    }

    if (!_hasValidNetworkPrefix(nationalDigits, country)) {
      throw FormatException(
        country.prefixHint.isNotEmpty
            ? country.prefixHint
            : 'Phone number prefix does not match selected country',
      );
    }
  }

  String _normalisePhoneByCountryCode(
      String value,
      String countryCode,
      ) {
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

    // Accept a value typed with the dial code but without the plus sign, e.g. 26658881234.
    if (digits.startsWith(dialDigits)) {
      final nationalDigits = digits.substring(dialDigits.length);
      _validateNationalPhoneDigits(nationalDigits, country);
      return '+$digits';
    }

    // Treat the value as a local number for the selected country.
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
      String? v, {
        required bool requiredField,
        required String countryCode,
      }) {
    final value = (v ?? '').trim();
    if (!requiredField && value.isEmpty) return null;
    if (value.isEmpty) return 'Required';

    if (_hasInvalidPhoneCharacters(value)) {
      return 'Use numbers only';
    }

    final country = _phoneCountryByCode(countryCode);

    try {
      _normalisePhoneByCountryCode(value, countryCode);
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

  String? _clientPhoneValidator({
    required MgysdClientEntry client,
    required String? value,
  }) {
    final selectedType = client.contactNumberType.trim();
    final isRequired = selectedType == 'Client phone' || selectedType == 'Both';
    return _phoneValidator(
      value,
      requiredField: isRequired,
      countryCode: client.phoneCountryCode,
    );
  }

  String? _clientAlternativePhoneValidator({
    required MgysdClientEntry client,
    required String? value,
  }) {
    final selectedType = client.contactNumberType.trim();
    final isRequired = selectedType == 'Alternative number' || selectedType == 'Both';
    return _phoneValidator(
      value,
      requiredField: isRequired,
      countryCode: client.alternatePhoneCountryCode,
    );
  }

  String? _dateValidator(
      String? v, {
        required bool requiredField,
        required String fieldId,
      }) {
    final requiredError = _requiredValidator(v, requiredField: requiredField);
    if (requiredError != null) return requiredError;

    final value = (v ?? '').trim();
    if (value.isEmpty) return null;

    final parsed = _parseDate(value);
    if (parsed == null) return 'Enter a valid date';

    if (fieldId == deReporterDob) {
      final age = _calculateAge(parsed);
      if (age == null || age < 6) {
        return 'Reporter must be at least 6 years old';
      }
    }

    if (fieldId == deWhenHappened) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDate = DateTime(parsed.year, parsed.month, parsed.day);
      if (selectedDate.isAfter(today)) {
        return 'Date incident happened cannot be in the future';
      }
    }

    return null;
  }

  int? _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    final hadBirthdayThisYear =
        today.month > dob.month || (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthdayThisYear) age--;
    return age < 0 ? null : age;
  }


  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _pickDate(String fieldId) async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final latestReporterDob = DateTime(today.year - 6, today.month, today.day);
    final latestAllowedDate = fieldId == deReporterDob
        ? latestReporterDob
        : fieldId == deWhenHappened
        ? today
        : today.add(const Duration(days: 365));

    DateTime initial = fieldId == deReporterDob ? latestReporterDob : today;
    final existing = (_values[fieldId] ?? '').trim();
    final parsed = _parseDate(existing);
    if (parsed != null) initial = parsed;
    if (initial.isAfter(latestAllowedDate)) initial = latestAllowedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: latestAllowedDate,
      helpText: fieldId == deReporterDob
          ? 'Select reporter date of birth (6 years or older)'
          : fieldId == deWhenHappened
          ? 'Select incident date'
          : 'Select date',
    );

    if (picked == null) return;

    setState(() {
      _values[fieldId] = _formatDate(picked);

      if (fieldId == deReporterDob) {
        final age = _calculateAge(picked);
        _values[deReporterAge] = age?.toString() ?? '';
      }
    });
  }

  void _addClient() {
    setState(() {
      _clients.add(
        MgysdClientEntry(
          localId: DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );
    });
  }

  void _removeClient(int index) {
    if (_clients.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one client is required.')),
      );
      return;
    }

    setState(() {
      final removed = _clients.removeAt(index);
      removed.dispose();
    });
  }

  void _addPersonInvolved() {
    setState(() {
      _peopleInvolved.add(
        MgysdPersonInvolvedEntry(
          localId: DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );
    });
  }

  void _removePersonInvolved(int index) {
    setState(() {
      final removed = _peopleInvolved.removeAt(index);
      removed.dispose();
    });
  }

  bool _shouldShowReporterField(MgysdFormFieldDef f) {
    if (f.id == deReporterAnonymous) return true;
    return !_reporterIsAnonymous;
  }

  Widget _countryCodeDropdown({
    required String value,
    required void Function(String?) onChanged,
  }) {
    final safeValue = _phoneCountryOptions.any((country) => country.code == value)
        ? value
        : _phoneCountryOptions.first.code;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: _decoration('Country code'),
      items: _phoneCountryOptions
          .map(
            (country) => DropdownMenuItem<String>(
          value: country.code,
          child: Text(
            country.label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _phoneInputField({
    required String label,
    required String countryCode,
    required void Function(String?) onCountryChanged,
    required bool requiredField,
    required String? Function(String?) validator,
    TextEditingController? controller,
    String? initialValue,
    void Function(String)? onChanged,
  }) {
    final country = _phoneCountryByCode(countryCode);
    final phoneHint = country.code == 'INTL'
        ? 'Start with + country code'
        : country.minNationalDigits == country.maxNationalDigits
        ? 'Enter ${country.maxNationalDigits} digits only'
        : 'Enter ${country.minNationalDigits}-${country.maxNationalDigits} digits only';

    final phoneField = TextFormField(
      key: ValueKey('${label}_$countryCode'),
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      decoration: _decoration(
        label,
        icon: Icons.phone,
        hint: phoneHint,
        requiredField: requiredField,
      ),
      keyboardType: country.code == 'INTL'
          ? TextInputType.phone
          : TextInputType.number,
      inputFormatters: [
        MgysdPhoneNumberInputFormatter(country),
      ],
      onChanged: onChanged,
      validator: validator,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 420;
        final countryDropdown = _countryCodeDropdown(
          value: countryCode,
          onChanged: onCountryChanged,
        );

        if (twoCols) {
          return Row(
            children: [
              SizedBox(width: 210, child: countryDropdown),
              const SizedBox(width: 10),
              Expanded(child: phoneField),
            ],
          );
        }

        return Column(
          children: [
            countryDropdown,
            const SizedBox(height: 8),
            phoneField,
          ],
        );
      },
    );
  }

  Widget _buildField(MgysdFormFieldDef f) {
    switch (f.type) {
      case MgysdFieldType.option:
      // Special-case multi-select for Concern reason
        if (f.id == deConcernReason) {
          final selected = _selectedConcernReasons;

          // split options into two roughly equal lists, keeping OTHER last
          final options = f.options;
          final otherOption =
          options.isNotEmpty && options.last.code == 'OTHER' ? options.last : null;
          final coreOptions = otherOption != null ? options.sublist(0, options.length - 1) : options;
          final mid = (coreOptions.length / 2).ceil();
          final left = coreOptions.sublist(0, mid);
          final right = coreOptions.sublist(mid);
          if (otherOption != null) right.add(otherOption); // ensure OTHER is last in right column

          return FormField<Set<String>>(
            initialValue: selected,
            validator: (set) {
              // avoid calling contains on null
              if (f.requiredField && (set == null || set.isEmpty)) {
                return 'Required';
              }
              if (set != null && set.contains('OTHER') && _concernOtherController.text.trim().isEmpty) {
                return 'Required';
              }
              return null;
            },
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // label
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      f.label,
                      style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
                    ),
                  ),
                  // two-column layout
                  LayoutBuilder(builder: (context, constraints) {
                    final twoCols = constraints.maxWidth >= 420;
                    if (twoCols) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: left.map((o) {
                                final isSelected = selected.contains(o.code);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        selected.add(o.code);
                                      } else {
                                        selected.remove(o.code);
                                      }
                                      _values[f.id] = selected.join(',');
                                      state.didChange(selected);
                                    });
                                  },
                                  title: Text(o.label),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                  activeColor: widget.color,
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: right.map((o) {
                                final isSelected = selected.contains(o.code);
                                final isOther = o.code == 'OTHER';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            selected.add(o.code);
                                          } else {
                                            selected.remove(o.code);
                                            if (isOther) {
                                              _concernOtherController.text = '';
                                              _values[deConcernReasonOther] = '';
                                            }
                                          }
                                          _values[f.id] = selected.join(',');
                                          state.didChange(selected);
                                        });
                                      },
                                      title: Text(o.label),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      dense: true,
                                      activeColor: widget.color,
                                    ),
                                    if (isOther && isSelected)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                                        child: TextFormField(
                                          controller: _concernOtherController,
                                          inputFormatters: _titleCaseInputFormatters,
                                          textCapitalization: TextCapitalization.sentences,
                                          decoration: InputDecoration(
                                            labelText: 'Specify',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFF9FBFD),
                                          ),
                                          onChanged: (v) {
                                            _values[deConcernReasonOther] = v.trim();
                                          },
                                          validator: (v) {
                                            if (f.requiredField && selected.contains('OTHER')) {
                                              if ((v ?? '').trim().isEmpty) return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // single column for narrow screens: left then right stacked
                      final all = [...left, ...right];
                      return Column(
                        children: all.map((o) {
                          final isSelected = selected.contains(o.code);
                          final isOther = o.code == 'OTHER';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selected.add(o.code);
                                    } else {
                                      selected.remove(o.code);
                                      if (isOther) {
                                        _concernOtherController.text = '';
                                        _values[deConcernReasonOther] = '';
                                      }
                                    }
                                    _values[f.id] = selected.join(',');
                                    state.didChange(selected);
                                  });
                                },
                                title: Text(o.label),
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                                activeColor: widget.color,
                              ),
                              if (isOther && isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                                  child: TextFormField(
                                    controller: _concernOtherController,
                                    inputFormatters: _titleCaseInputFormatters,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      labelText: 'Specify',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF9FBFD),
                                    ),
                                    onChanged: (v) {
                                      _values[deConcernReasonOther] = v.trim();
                                    },
                                    validator: (v) {
                                      if (f.requiredField && selected.contains('OTHER')) {
                                        if ((v ?? '').trim().isEmpty) return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                            ],
                          );
                        }).toList(),
                      );
                    }
                  }),
                  // validation message
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        state.errorText ?? '',
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          );
        }

        // Default single-select behavior for other option fields
        final rawValue = (_values[f.id] ?? '').trim();
        final safeValue = f.options.any((o) => o.code == rawValue) ? rawValue : null;

        return DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          items: f.options
              .map(
                (o) => DropdownMenuItem<String>(
              value: o.code,
              child: Text(o.label, overflow: TextOverflow.ellipsis),
            ),
          )
              .toList(),
          onChanged: (v) => setState(() {
            _values[f.id] = v ?? '';
          }),
          validator: (v) => _requiredValidator(v, requiredField: f.requiredField),
          decoration: _decoration(f.label, requiredField: f.requiredField),
        );

      case MgysdFieldType.boolean:
        final current = (_values[f.id] ?? 'false') == 'true';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(f.label, style: const TextStyle(fontSize: 13.5)),
              ),
              Text(
                current ? 'Yes' : 'No',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                value: current,
                activeColor: widget.color,
                onChanged: (val) => setState(() {
                  _values[f.id] = val ? 'true' : 'false';

                  if (f.id == deReporterAnonymous && val) {
                    for (final reporterField in aboutReporterFields) {
                      if (reporterField.id != deReporterAnonymous) {
                        _values[reporterField.id] = '';
                      }
                    }
                  }
                }),
              ),
            ],
          ),
        );

      case MgysdFieldType.date:
        final value = (_values[f.id] ?? '').trim();

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pickDate(f.id),
          child: IgnorePointer(
            child: TextFormField(
              key: ValueKey('${f.id}_$value'),
              initialValue: value,
              decoration: _decoration(
                f.label,
                icon: Icons.calendar_month,
                hint: 'yyyy-mm-dd',
                requiredField: f.requiredField,
              ),
              validator: (v) => _dateValidator(
                v,
                requiredField: f.requiredField,
                fieldId: f.id,
              ),
            ),
          ),
        );

      case MgysdFieldType.phone:
        final countryCode = _phoneCountryCodes[f.id] ?? 'LS';
        return _phoneInputField(
          label: f.label,
          countryCode: countryCode,
          requiredField: f.requiredField,
          initialValue: (_values[f.id] ?? '').trim(),
          onChanged: (v) => _values[f.id] = v.trim(),
          onCountryChanged: (v) => setState(() {
            _phoneCountryCodes[f.id] = v ?? 'LS';
          }),
          validator: (v) => _phoneValidator(
            v,
            requiredField: f.requiredField,
            countryCode: _phoneCountryCodes[f.id] ?? 'LS',
          ),
        );

      case MgysdFieldType.integer:
        return TextFormField(
          key: ValueKey('${f.id}_${_values[f.id] ?? ''}'),
          initialValue: (_values[f.id] ?? '').trim(),
          decoration: _decoration(f.label, requiredField: f.requiredField),
          keyboardType: TextInputType.number,
          readOnly: f.id == deReporterAge,
          onChanged: (v) => _values[f.id] = v.trim(),
          validator: (v) =>
              _requiredValidator(v, requiredField: f.requiredField),
        );

      case MgysdFieldType.textLong:
        return TextFormField(
          initialValue: (_values[f.id] ?? '').trim(),
          decoration: _decoration(f.label, requiredField: f.requiredField),
          maxLines: 4,
          inputFormatters: _titleCaseInputFormatters,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => _values[f.id] = v.trim(),
          validator: (v) =>
              _requiredValidator(v, requiredField: f.requiredField),
        );

      case MgysdFieldType.textShort:
        final isNameField = _isNameFieldId(f.id);
        return TextFormField(
          initialValue: (_values[f.id] ?? '').trim(),
          decoration: _decoration(f.label, requiredField: f.requiredField),
          maxLength: f.maxLen,
          inputFormatters: isNameField
              ? _nameInputFormatters
              : _titleCaseInputFormatters,
          textCapitalization: TextCapitalization.words,
          buildCounter: (
              context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) {
            return null;
          },
          onChanged: (v) => _values[f.id] = v.trim(),
          validator: (v) => isNameField
              ? _nameValidator(v, requiredField: f.requiredField)
              : _requiredValidator(v, requiredField: f.requiredField),
        );
    }
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

  List<Widget> _buildCompactFields({
    required List<MgysdFormFieldDef> fields,
    required double availableWidth,
  }) {
    final twoCols = _twoCols(availableWidth);
    final visible = fields.where(_shouldShowReporterField).toList();

    MgysdFormFieldDef? byId(String id) {
      for (final f in visible) {
        if (f.id == id) return f;
      }
      return null;
    }

    final widgets = <Widget>[];
    final used = <String>{};

    void addField(MgysdFormFieldDef f) {
      used.add(f.id);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildField(f),
        ),
      );
    }

    void addRow(MgysdFormFieldDef f1, MgysdFormFieldDef f2) {
      used.add(f1.id);
      used.add(f2.id);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _row2(_buildField(f1), _buildField(f2)),
        ),
      );
    }

    final anonymous = byId(deReporterAnonymous);
    if (anonymous != null) {
      addField(anonymous);
    }

    // When anonymous is selected, keep the toggle visible but hide the rest of
    // the About Reporter fields.
    if (_reporterIsAnonymous) {
      return widgets;
    }

    if (twoCols) {
      final rfn = byId(deReporterFirstName);
      final rln = byId(deReporterLastName);
      if (rfn != null && rln != null) addRow(rfn, rln);

      final dob = byId(deReporterDob);
      final age = byId(deReporterAge);
      if (dob != null && age != null) addRow(dob, age);

      final p1 = byId(deReporterPhone);
      final p2 = byId(deReporterAltPhone);
      if (p1 != null && p2 != null) addRow(p1, p2);

      final cfn = byId(deChiefFirstName);
      final cln = byId(deChiefLastName);
      if (cfn != null && cln != null) addRow(cfn, cln);
    }

    for (final f in visible) {
      if (!used.contains(f.id)) addField(f);
    }

    return widgets;
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _dropdownFromOptions({
    required String label,
    required String value,
    required List<MgysdOption> options,
    required void Function(String?) onChanged,
    bool requiredField = false,
  }) {
    final safeValue = options.any((o) => o.code == value) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: _decoration(label, requiredField: requiredField),
      items: options
          .map(
            (o) => DropdownMenuItem<String>(
          value: o.code,
          child: Text(o.label, overflow: TextOverflow.ellipsis),
        ),
      )
          .toList(),
      onChanged: onChanged,
      validator: (v) => _requiredValidator(v, requiredField: requiredField),
    );
  }

  Widget _orgUnitDropdown({
    required String label,
    required String value,
    required List<OrganisationUnit> options,
    required void Function(String?) onChanged,
    bool requiredField = false,
  }) {
    final safeValue = options.any((ou) => ou.id == value) ? value : null;

    if (_loadingLocationTree) {
      return InputDecorator(
        decoration: _decoration(label, requiredField: requiredField),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Loading locations...')),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: _decoration(label, requiredField: requiredField),
      items: options
          .map(
            (ou) => DropdownMenuItem<String>(
          value: ou.id ?? '',
          child: Text(
            ou.name ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .where((item) => item.value != null && item.value!.isNotEmpty)
          .toList(),
      onChanged: onChanged,
      validator: (v) {
        if (!requiredField) return null;
        if ((v ?? '').trim().isEmpty) return 'Required';
        return null;
      },
    );
  }

  Widget _clientDistrictDropdown(MgysdClientEntry client) {
    return _orgUnitDropdown(
      label: 'Client District',
      value: client.districtOrgUnit,
      options: _districts,
      requiredField: true,
      onChanged: (value) {
        final districtId = value ?? '';
        final districtName = _orgUnitNameById(_districts, districtId);

        setState(() {
          client.districtOrgUnit = districtId;
          client.districtController.text = districtName;
          client.communityCouncilOrgUnit = '';
          client.communityCouncilController.text = '';
        });
      },
    );
  }

  Widget _clientCommunityCouncilDropdown(MgysdClientEntry client) {
    final councils = _communityCouncilsForDistrict(client.districtOrgUnit);

    return _orgUnitDropdown(
      label: 'Client Community Council',
      value: client.communityCouncilOrgUnit,
      options: councils,
      requiredField: true,
      onChanged: (value) {
        final councilId = value ?? '';
        final councilName = _orgUnitNameById(councils, councilId);

        setState(() {
          client.communityCouncilOrgUnit = councilId;
          client.communityCouncilController.text = councilName;
        });
      },
    );
  }

  Widget _clientContactNumberTypeRadios(MgysdClientEntry client) {
    void updateSelection(String? value, FormFieldState<String> state) {
      setState(() {
        client.contactNumberType = value ?? '';

        if (client.contactNumberType == 'Client phone') {
          client.alternatePhoneController.clear();
        } else if (client.contactNumberType == 'Alternative number') {
          client.phoneController.clear();
        }
      });
      state.didChange(value ?? '');
    }

    return FormField<String>(
      initialValue: client.contactNumberType,
      validator: (value) {
        if ((value ?? '').trim().isEmpty) return 'Required';
        return null;
      },
      builder: (state) {
        final currentValue = client.contactNumberType.trim().isNotEmpty
            ? client.contactNumberType
            : state.value;

        Widget optionTile(MgysdOption option) {
          return RadioListTile<String>(
            value: option.code,
            groupValue: currentValue,
            onChanged: (value) => updateSelection(value, state),
            dense: true,
            activeColor: widget.color,
            contentPadding: EdgeInsets.zero,
            title: Text(option.label),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _requiredLabel(
                'Contact number to provide',
                requiredField: true,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth >= 520;
                if (twoCols) {
                  return Row(
                    children: _clientContactNumberTypeOptions
                        .map((option) => Expanded(child: optionTile(option)))
                        .toList(),
                  );
                }

                return Column(
                  children: _clientContactNumberTypeOptions.map(optionTile).toList(),
                );
              },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _clientCard(int index, MgysdClientEntry client, double availableWidth) {
    final twoCols = _twoCols(availableWidth);

    Widget firstName = TextFormField(
      controller: client.firstNameController,
      decoration: _decoration('Client First name', requiredField: true),
      inputFormatters: _nameInputFormatters,
      textCapitalization: TextCapitalization.words,
      validator: (v) => _nameValidator(v, requiredField: true),
    );

    Widget lastName = TextFormField(
      controller: client.lastNameController,
      decoration: _decoration('Client Last name', requiredField: true),
      inputFormatters: _nameInputFormatters,
      textCapitalization: TextCapitalization.words,
      validator: (v) => _nameValidator(v, requiredField: true),
    );

    Widget age = TextFormField(
      controller: client.ageController,
      decoration: _decoration('Age', requiredField: true),
      keyboardType: TextInputType.number,
      validator: (v) => _requiredValidator(v, requiredField: true),
    );

    Widget sex = _dropdownFromOptions(
      label: 'Client Sex',
      value: client.sex,
      options: _sexOptions,
      requiredField: true,
      onChanged: (v) => setState(() {
        client.sex = v ?? '';
      }),
    );

    Widget contactNumberType = _clientContactNumberTypeRadios(client);

    Widget phone = _phoneInputField(
      label: 'Client phone',
      controller: client.phoneController,
      countryCode: client.phoneCountryCode,
      requiredField: true,
      onCountryChanged: (v) => setState(() {
        client.phoneCountryCode = v ?? 'LS';
      }),
      validator: (v) => _clientPhoneValidator(client: client, value: v),
    );

    Widget alternatePhone = _phoneInputField(
      label: 'Alternative number',
      controller: client.alternatePhoneController,
      countryCode: client.alternatePhoneCountryCode,
      requiredField: true,
      onCountryChanged: (v) => setState(() {
        client.alternatePhoneCountryCode = v ?? 'LS';
      }),
      validator: (v) => _clientAlternativePhoneValidator(client: client, value: v),
    );

    Widget district = _clientDistrictDropdown(client);

    Widget communityCouncil = _clientCommunityCouncilDropdown(client);

    Widget relationshipToClient = _dropdownFromOptions(
      label: 'Relationship to client',
      value: client.relationshipToClient,
      options: _reporterRelationshipOptions,
      requiredField: true,
      onChanged: (v) => setState(() {
        client.relationshipToClient = v ?? '';
        if (client.relationshipToClient != 'Other') {
          client.relationshipOtherController.clear();
        }
      }),
    );

    Widget relationshipOther = TextFormField(
      controller: client.relationshipOtherController,
      decoration: _decoration('Specify relationship to client', requiredField: true),
      inputFormatters: _titleCaseInputFormatters,
      textCapitalization: TextCapitalization.words,
      maxLength: 80,
      buildCounter: (
          context, {
            required currentLength,
            required isFocused,
            maxLength,
          }) {
        return null;
      },
      validator: (v) {
        if (client.relationshipToClient == 'Other' &&
            (v ?? '').trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
    );

    Widget physicalAddress = TextFormField(
      controller: client.physicalAddressController,
      decoration: _decoration('Client Physical Address', requiredField: true),
      maxLines: 4,
      inputFormatters: _titleCaseInputFormatters,
      textCapitalization: TextCapitalization.sentences,
      validator: (v) => _requiredValidator(v, requiredField: true),
    );

    final fields = <Widget>[
      if (twoCols)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _row2(firstName, lastName),
        )
      else ...[
        Padding(padding: const EdgeInsets.only(bottom: 10), child: firstName),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: lastName),
      ],
      if (twoCols) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _row2(age, sex),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: contactNumberType,
        ),
        if (client.contactNumberType == 'Client phone')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: phone,
          ),
        if (client.contactNumberType == 'Alternative number')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: alternatePhone,
          ),
        if (client.contactNumberType == 'Both')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _row2(phone, alternatePhone),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _row2(district, communityCouncil),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: relationshipToClient,
        ),
      ] else ...[
        Padding(padding: const EdgeInsets.only(bottom: 10), child: age),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: sex),
        Padding(padding: const EdgeInsets.only(bottom: 10), child: contactNumberType),
        if (client.contactNumberType == 'Client phone')
          Padding(padding: const EdgeInsets.only(bottom: 10), child: phone),
        if (client.contactNumberType == 'Alternative number')
          Padding(padding: const EdgeInsets.only(bottom: 10), child: alternatePhone),
        if (client.contactNumberType == 'Both') ...[
          Padding(padding: const EdgeInsets.only(bottom: 10), child: phone),
          Padding(padding: const EdgeInsets.only(bottom: 10), child: alternatePhone),
        ],
        Padding(padding: const EdgeInsets.only(bottom: 10), child: district),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: communityCouncil,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: relationshipToClient,
        ),
      ],
      if (client.relationshipToClient == 'Other')
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: relationshipOther,
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: physicalAddress,
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          ...fields,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Container()),
              if (_clients.length > 1)
                TextButton.icon(
                  onPressed: () => _removeClient(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _personInvolvedCard(int index, MgysdPersonInvolvedEntry person, double availableWidth) {
    final twoCols = _twoCols(availableWidth);

    Widget firstNameField = TextFormField(
      controller: person.firstNameController,
      decoration: _decoration('First name', requiredField: true),
      inputFormatters: _nameInputFormatters,
      textCapitalization: TextCapitalization.words,
      validator: (v) => _nameValidator(v, requiredField: true),
    );

    Widget lastNameField = TextFormField(
      controller: person.lastNameController,
      decoration: _decoration('Last name', requiredField: true),
      inputFormatters: _nameInputFormatters,
      textCapitalization: TextCapitalization.words,
      validator: (v) => _nameValidator(v, requiredField: true),
    );

    Widget roleRelationshipField = _dropdownFromOptions(
      label: 'Role / Relationship',
      value: person.roleOrRelationship,
      options: _peopleInvolvedRelationshipOptions,
      requiredField: true,
      onChanged: (v) => setState(() {
        person.roleOrRelationship = v ?? '';
        if (person.roleOrRelationship != 'Other') {
          person.roleOtherController.clear();
        }
      }),
    );

    Widget roleRelationshipOtherField = TextFormField(
      controller: person.roleOtherController,
      decoration: _decoration('Specify role / relationship', requiredField: true),
      inputFormatters: _titleCaseInputFormatters,
      textCapitalization: TextCapitalization.words,
      maxLength: 80,
      buildCounter: (
          context, {
            required currentLength,
            required isFocused,
            maxLength,
          }) {
        return null;
      },
      validator: (v) {
        if (person.roleOrRelationship == 'Other' &&
            (v ?? '').trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Person ${index + 1}',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
          ),
          if (twoCols) ...[
            Row(
              children: [
                Expanded(child: firstNameField),
                const SizedBox(width: 10),
                Expanded(child: lastNameField),
              ],
            ),
            const SizedBox(height: 10),
            roleRelationshipField,
          ] else ...[
            firstNameField,
            const SizedBox(height: 8),
            lastNameField,
            const SizedBox(height: 8),
            roleRelationshipField,
          ],
          if (person.roleOrRelationship == 'Other') ...[
            const SizedBox(height: 10),
            roleRelationshipOtherField,
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              if (_peopleInvolved.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _removePersonInvolved(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) {
      throw Exception('Offline DB not initialized');
    }
    return dbClient;
  }

  String _newEventId() {
    return AppUtil.getUid();
  }

  String _today() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  Future<void> _saveEventDataValue({
    required Database db,
    required String eventId,
    required String dataElement,
    required String value,
  }) async {
    if (dataElement.trim().isEmpty) return;

    await db.insert(
      'event_data_value',
      {
        'id': '${eventId}_$dataElement',
        'event': eventId,
        'dataElement': dataElement,
        'value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _clientToJson(MgysdClientEntry client) {
    final rawPhone = client.phoneController.text.trim();
    final rawAlternatePhone = client.alternatePhoneController.text.trim();

    return {
      'firstName': client.firstNameController.text.trim(),
      'lastName': client.lastNameController.text.trim(),
      'age': client.ageController.text.trim(),
      'sex': client.sex,
      'contactNumberType': client.contactNumberType,
      'phoneCountryCode': client.phoneCountryCode,
      'alternatePhoneCountryCode': client.alternatePhoneCountryCode,
      'phone': _normalisedPhoneNumber(rawPhone, client.phoneCountryCode),
      'phoneRaw': rawPhone,
      'alternatePhone': _normalisedPhoneNumber(
        rawAlternatePhone,
        client.alternatePhoneCountryCode,
      ),
      'alternatePhoneRaw': rawAlternatePhone,
      'district': client.districtController.text.trim(),
      'districtOrgUnit': client.districtOrgUnit,
      'communityCouncil': client.communityCouncilController.text.trim(),
      'communityCouncilOrgUnit': client.communityCouncilOrgUnit,
      'relationshipToClient': client.relationshipToClient,
      'relationshipToClientOther': client.relationshipOtherController.text.trim(),
      'physicalAddress': client.physicalAddressController.text.trim(),
      // Kept for backward compatibility with any existing readers that expect this key.
      'howToContactClient': client.physicalAddressController.text.trim(),
    };
  }

  Future<void> _onSave() async {
    final currentUserState = Provider.of<CurrentUserState>(
      context,
      listen: false,
    );

    if (!currentUserState.canMgysdReportCase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to report a case.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }

    final reportOrgUnit = _clients.isNotEmpty
        ? _clients.first.communityCouncilOrgUnit.trim()
        : '';

    if (reportOrgUnit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the client Community Council.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      _values[deConcernReason] = _selectedConcernReasons.join(',');
      _values[deConcernReasonOther] = _concernOtherController.text.trim();

      final clientsJson = _clients.map(_clientToJson).toList();
      final peopleJson = _peopleInvolved.map((p) => p.toJson()).toList();

      final reporterMap = <String, String>{};
      for (final f in aboutReporterFields) {
        reporterMap[f.id] = _values[f.id] ?? '';
      }

      reporterMap[deReporterPhone] = _normalisedPhoneNumber(
        reporterMap[deReporterPhone] ?? '',
        _phoneCountryCodes[deReporterPhone] ?? 'LS',
      );
      reporterMap[deReporterAltPhone] = _normalisedPhoneNumber(
        reporterMap[deReporterAltPhone] ?? '',
        _phoneCountryCodes[deReporterAltPhone] ?? 'LS',
      );
      if (clientsJson.isNotEmpty) {
        final firstClient = clientsJson.first;
        reporterMap[deReporterRelationship] =
            (firstClient['relationshipToClient'] ?? '').toString();
        reporterMap[deReporterRelationshipOther] =
            (firstClient['relationshipToClientOther'] ?? '').toString();
      }

      final concernsMap = <String, String>{
        deWhenHappened: _values[deWhenHappened] ?? '',
        deIncidentLocation: _values[deIncidentLocation] ?? '',
        deConcernReason: _values[deConcernReason] ?? '',
        deConcernReasonOther: _values[deConcernReasonOther] ?? '',
        deIncidentDescription: _values[deIncidentDescription] ?? '',
      };

      final payload = {
        'reporter': reporterMap,
        'reporterPhoneCountries': {
          deReporterPhone: _phoneCountryCodes[deReporterPhone] ?? 'LS',
          deReporterAltPhone: _phoneCountryCodes[deReporterAltPhone] ?? 'LS',
        },
        'concerns': concernsMap,
        'peopleInvolved': peopleJson,
        'clients': clientsJson,
      };

      final db = await _db();
      final eventId = _newEventId();
      final eventDate = (concernsMap[deWhenHappened] ?? '').trim().isNotEmpty
          ? concernsMap[deWhenHappened]!.trim()
          : _today();

      await db.insert(
        'events',
        {
          'id': eventId,
          'event': eventId,
          'eventDate': eventDate,
          'program': mgysdReportProgram,
          'programStage': mgysdReportProgramStage,
          'trackedEntityInstance': '',
          'status': 'COMPLETED',
          'orgUnit': reportOrgUnit,
          'syncStatus': 'not-synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Reporter fields
      for (final entry in reporterMap.entries) {
        await _saveEventDataValue(
          db: db,
          eventId: eventId,
          dataElement: entry.key,
          value: entry.value,
        );
      }

      // Concern fields
      for (final entry in concernsMap.entries) {
        await _saveEventDataValue(
          db: db,
          eventId: eventId,
          dataElement: entry.key,
          value: entry.value,
        );
      }

      // Structured lists and full payload for reliable display/editing later.
      await _saveEventDataValue(
        db: db,
        eventId: eventId,
        dataElement: deClientsJson,
        value: jsonEncode(clientsJson),
      );

      await _saveEventDataValue(
        db: db,
        eventId: eventId,
        dataElement: dePeopleInvolvedJson,
        value: jsonEncode(peopleJson),
      );

      await _saveEventDataValue(
        db: db,
        eventId: eventId,
        dataElement: MgysdDhis2Uids.deReportPayloadJson,
        value: jsonEncode(payload),
      );

      // Save first client details into explicit data values too, so the
      // records page can show a clean summary without unpacking JSON only.
      if (clientsJson.isNotEmpty) {
        final firstClient = clientsJson.first;
        await _saveEventDataValue(
          db: db,
          eventId: eventId,
          dataElement: MgysdDhis2Uids.deFirstClientFirstName,
          value: (firstClient['firstName'] ?? '').toString(),
        );
        await _saveEventDataValue(
          db: db,
          eventId: eventId,
          dataElement: MgysdDhis2Uids.deFirstClientLastName,
          value: (firstClient['lastName'] ?? '').toString(),
        );
        await _saveEventDataValue(
          db: db,
          eventId: eventId,
          dataElement: MgysdDhis2Uids.deFirstClientPhone,
          value: (firstClient['phone'] ?? '').toString(),
        );
        await _saveEventDataValue(
          db: db,
          eventId: eventId,
          dataElement: MgysdDhis2Uids.deFirstClientSex,
          value: (firstClient['sex'] ?? '').toString(),
        );
        await _saveEventDataValue(
          db: db,
          eventId: eventId,
          dataElement: MgysdDhis2Uids.deFirstClientDistrict,
          value: (firstClient['district'] ?? '').toString(),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report saved offline as event')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserState = Provider.of<CurrentUserState>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final contentMax = _contentMaxWidth(screenWidth);

    if (!currentUserState.canMgysdReportCase) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Report a Case',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: widget.color,
        ),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.05),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.orange.withOpacity(0.12),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Colors.orange,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Permission required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your current MGYSD role does not allow reporting a case.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blueGrey,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report a Case',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: widget.color,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMax),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionCard(
                      title: 'About Reporter',
                      subtitle: 'Who is reporting this concern',
                      icon: Icons.person,
                      children: _buildCompactFields(
                        fields: aboutReporterFields,
                        availableWidth: contentMax,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: 'Client',
                      subtitle: 'Person affected',
                      icon: Icons.group,
                      children: [
                        ..._clients.asMap().entries.map((e) {
                          final idx = e.key;
                          final client = e.value;
                          return _clientCard(idx, client, contentMax);
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: 'Why are you concerned?',
                      subtitle: 'Date, location and reasons for concern',
                      icon: Icons.report_problem,
                      children: [
                        // Concern fields in the new order: date, location, reasons, description
                        ...concernFields.map((f) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildField(f),
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: 'People involved',
                      subtitle: 'Other people involved in the incident',
                      icon: Icons.people,
                      children: [
                        ..._peopleInvolved.asMap().entries.map((e) {
                          final idx = e.key;
                          final person = e.value;
                          return _personInvolvedCard(idx, person, contentMax);
                        }).toList(),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addPersonInvolved,
                            icon: const Icon(Icons.add),
                            label: const Text('Add a person'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitting ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text(
                        'Save Report Offline',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}