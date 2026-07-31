import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lncmis_mobile_app/app_state/current_user_state/current_user_state.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/helpers/mgysd_program_stage_event_helper.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:sqflite/sqflite.dart';

class MgysdReferralPage extends StatefulWidget {
  const MgysdReferralPage({
    Key? key,
    required this.color,
    required this.mgysdCase,
    this.householdTei,
    this.householdName,
    this.clientName,
    this.fileNumber,
  }) : super(key: key);

  final Color color;
  final MgysdCase mgysdCase;
  final String? householdTei;
  final String? householdName;
  final String? clientName;
  final String? fileNumber;

  @override
  State<MgysdReferralPage> createState() => _MgysdReferralPageState();
}

class _ServiceCategory {
  const _ServiceCategory({
    required this.label,
    required this.services,
    required this.icon,
  });

  final String label;
  final List<String> services;
  final IconData icon;
}

class MgysdCountryCodeOption {
  final String code;
  final String label;
  final String dialCode;
  final int minNationalDigits;
  final int maxNationalDigits;
  final List<String> allowedNationalPrefixes;
  final List<String> disallowedNationalPrefixes;
  final String prefixHint;
  final bool useNanpRules;

  const MgysdCountryCodeOption({
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

class _MgysdReferralPageState extends State<MgysdReferralPage> {
  final _formKey = GlobalKey<FormState>();

  final _referralDateController = TextEditingController();
  final _referringOrgController = TextEditingController(
    text: 'Ministry of Gender Youth and Social Development',
  );

  final _referrerNameController = TextEditingController();
  final _referrerTitleController = TextEditingController();
  final _referrerContactController = TextEditingController();
  final _referrerLocationController = TextEditingController();

  final _receivingOrganisationController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _documentsAccompanyingController = TextEditingController();
  final _reasonForReferralController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _urgentActionController = TextEditingController();

  String _selectedCategory = '';
  final Set<String> _selectedServices = {};
  final Set<String> _selectedAttachments = {};
  String _priority = 'ROUTINE';
  bool _consentDiscussed = false;
  bool _saving = false;
  String? _savedStatus;
  bool _userFilled = false;
  bool _countryPickerBusy = false;
  String _contactPhoneCountryCode = 'LS';

  static const List<_ServiceCategory> _serviceCategories = [
    _ServiceCategory(
      label: 'Social Protection Support',
      icon: Icons.volunteer_activism_outlined,
      services: [
        'Transportation Assistance',
        'Food Assistance',
        'Social Assistance',
      ],
    ),
    _ServiceCategory(
      label: 'Education',
      icon: Icons.school_outlined,
      services: [
        'Bursary or other financial or material support',
        'Vocational training',
        'Early Childhood Development',
        'Support to return to school / homework support',
      ],
    ),
    _ServiceCategory(
      label: 'Health Support',
      icon: Icons.local_hospital_outlined,
      services: [
        'Nutrition support',
        'Support related to primary care',
        'HIV-related care and support',
        'Reproductive health / sexual health services',
        'Disability support',
      ],
    ),
    _ServiceCategory(
      label: 'Mental Health',
      icon: Icons.psychology_outlined,
      services: [
        'Psychiatric service',
        'Substance abuse services',
        'Psychosocial support / counseling',
        'Support group',
      ],
    ),
    _ServiceCategory(
      label: 'Community Development',
      icon: Icons.groups_2_outlined,
      services: [
        'Skills development',
        'Income Generation Activity',
        'Job placement',
        'Start-up kit / capital',
        'Economic empowerment',
      ],
    ),
    _ServiceCategory(
      label: 'Legal / Justice Services',
      icon: Icons.gavel_outlined,
      services: [
        'Master of High Court',
        'Probation',
        'Magistrate Court',
        "Children's Court",
        'High Court',
        'Child and Gender Protection Unit (CGPU)',
      ],
    ),
    _ServiceCategory(
      label: 'NICR',
      icon: Icons.badge_outlined,
      services: [
        'Birth registration / civil registration support',
        'Death Registration',
      ],
    ),
  ];

  static const Map<String, String> _priorityLabels = {
    'ROUTINE': 'Routine',
    'URGENT': 'Urgent',
    'EMERGENCY': 'Emergency',
  };

  static const List<MgysdCountryCodeOption> _phoneCountryOptions = [
    MgysdCountryCodeOption(
      code: 'LS',
      label: 'Lesotho (+266)',
      dialCode: '+266',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['2', '5', '6'],
      disallowedNationalPrefixes: ['54', '55'],
      prefixHint: 'Lesotho numbers must start with 2, 5 or 6. Prefixes 54 and 55 are not allowed',
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
      code: 'BW',
      label: 'Botswana (+267)',
      dialCode: '+267',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['71', '72', '73', '74', '75', '76'],
      prefixHint: 'Botswana mobile numbers must start with 71, 72, 73, 74, 75 or 76',
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
      code: 'SZ',
      label: 'Eswatini (+268)',
      dialCode: '+268',
      minNationalDigits: 8,
      maxNationalDigits: 8,
      allowedNationalPrefixes: ['75', '76', '77', '78', '79'],
      prefixHint: 'Eswatini mobile numbers must start with 75, 76, 77, 78 or 79',
    ),
    MgysdCountryCodeOption(
      code: 'ZM',
      label: 'Zambia (+260)',
      dialCode: '+260',
      minNationalDigits: 9,
      maxNationalDigits: 9,
      allowedNationalPrefixes: ['76', '77', '95', '96', '97'],
      prefixHint: 'Zambia mobile numbers must start with 76, 77, 95, 96 or 97',
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

  static const Map<String, String> _attachmentLabels = {
    'Assessment notes': 'Assessment notes',
    'ID copy': 'ID copy',
    'Medical note': 'Medical note',
    'Court document': 'Court document',
  };

  @override
  void initState() {
    super.initState();
    _referralDateController.text = _today();
    _referringOrgController.text =
    'Ministry of Gender Youth and Social Development';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_userFilled) return;
    _populateCurrentUser();
    _userFilled = true;
  }

  @override
  void dispose() {
    _referralDateController.dispose();
    _referringOrgController.dispose();
    _referrerNameController.dispose();
    _referrerTitleController.dispose();
    _referrerContactController.dispose();
    _referrerLocationController.dispose();
    _receivingOrganisationController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _documentsAccompanyingController.dispose();
    _reasonForReferralController.dispose();
    _recommendationsController.dispose();
    _urgentActionController.dispose();
    super.dispose();
  }

  void _populateCurrentUser() {
    try {
      final userState = context.read<CurrentUserState>();
      final user = userState.currentUser;
      if (user == null) return;

      _referrerNameController.text = _firstNonEmpty([
        user.name ?? '',
        user.username ?? '',
      ]);

      final roles = (user.userRoles ?? '').trim();
      final groups = (user.userGroups ?? '').trim();
      _referrerTitleController.text =
      groups.toLowerCase().contains('supervisor') ||
          roles.toLowerCase().contains('supervisor')
          ? 'Supervisor'
          : 'Social Worker';

      _referrerContactController.text = _firstNonEmpty([
        user.phoneNumber ?? '',
        user.email ?? '',
      ]);

      _referrerLocationController.text = userState.currentUserLocations;
    } catch (_) {
      _referrerTitleController.text = 'Social Worker';
    }
  }

  String _today() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
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

  bool _hasDisallowedNationalPrefix(
      String nationalDigits,
      MgysdCountryCodeOption country,
      ) {
    if (country.code == 'INTL' || nationalDigits.isEmpty) return false;
    return country.disallowedNationalPrefixes.any(nationalDigits.startsWith);
  }

  bool _hasPossibleNetworkPrefix(
      String nationalDigits,
      MgysdCountryCodeOption country,
      ) {
    if (country.code == 'INTL' || nationalDigits.isEmpty) return true;

    if (_hasDisallowedNationalPrefix(nationalDigits, country)) {
      return false;
    }

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
      MgysdCountryCodeOption country,
      ) {
    if (country.code == 'INTL') return true;

    if (_hasDisallowedNationalPrefix(nationalDigits, country)) {
      return false;
    }

    if (country.useNanpRules) {
      return RegExp(r'^[2-9][0-9]{2}[2-9][0-9]{6}$')
          .hasMatch(nationalDigits);
    }

    if (country.allowedNationalPrefixes.isEmpty) return true;
    return country.allowedNationalPrefixes.any(nationalDigits.startsWith);
  }

  String _phonePrefixMessage(MgysdCountryCodeOption country) {
    return country.prefixHint.isNotEmpty
        ? country.prefixHint
        : 'Phone number prefix does not match selected country';
  }

  String _phoneLengthMessage(MgysdCountryCodeOption country) {
    if (country.minNationalDigits == country.maxNationalDigits) {
      return '${country.label} numbers must have '
          '${country.maxNationalDigits} digits after ${country.dialCode}';
    }

    return '${country.label} numbers must have '
        '${country.minNationalDigits} to ${country.maxNationalDigits} digits '
        'after ${country.dialCode}';
  }

  void _validateNationalPhoneDigits(
      String nationalDigits,
      MgysdCountryCodeOption country,
      ) {
    // Reused from Report Case: check prefix before length so invalid Lesotho
    // prefixes such as 54 and 55 are reported immediately.
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
        throw const FormatException(
          'International numbers must start with +',
        );
      }
      if (digits.length < 8 || digits.length > 15) {
        throw const FormatException(
          'International numbers must have 8 to 15 digits',
        );
      }
      return '+$digits';
    }

    final dialDigits = country.dialCode.replaceAll('+', '');

    if (compact.startsWith('+')) {
      if (!digits.startsWith(dialDigits)) {
        throw const FormatException(
          'Phone number country code does not match selected country',
        );
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
    final trimmed = (value ?? '').trim();
    if (!requiredField && trimmed.isEmpty) return null;
    if (trimmed.isEmpty) return 'Required';

    if (_hasInvalidPhoneCharacters(trimmed)) {
      return 'Use numbers only';
    }

    final country = _phoneCountryByCode(countryCode);

    try {
      _normalisePhoneByCountryCode(trimmed, countryCode);
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

  bool _looksLikeEmail(String value) {
    return value.contains('@') || RegExp(r'[A-Za-z]').hasMatch(value);
  }

  String? _phoneOrEmailValidator(
      String? value, {
        required bool requiredField,
        required String countryCode,
      }) {
    final trimmed = (value ?? '').trim();
    if (!requiredField && trimmed.isEmpty) return null;
    if (trimmed.isEmpty) return 'Required';

    if (_looksLikeEmail(trimmed)) {
      final validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      return validEmail.hasMatch(trimmed)
          ? null
          : 'Enter a valid email address';
    }

    return _phoneValidator(
      trimmed,
      requiredField: requiredField,
      countryCode: countryCode,
    );
  }

  String _countryDisplayName(MgysdCountryCodeOption country) {
    final label = country.label.trim();
    final bracketIndex = label.indexOf(' (');
    if (bracketIndex > 0) return label.substring(0, bracketIndex);
    return label;
  }

  String _countryFlag(MgysdCountryCodeOption country) {
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
      default:
        return '🌐';
    }
  }

  String _phoneFieldLabel(String label, MgysdCountryCodeOption country) {
    if (country.code == 'INTL') return label;
    if (country.minNationalDigits == country.maxNationalDigits) {
      return '$label (${country.maxNationalDigits} digits)';
    }
    return '$label '
        '(${country.minNationalDigits}-${country.maxNationalDigits} digits)';
  }

  String _formatPhoneTextForSelectedCountry(
      String value,
      String countryCode,
      ) {
    final country = _phoneCountryByCode(countryCode);
    return MgysdPhoneNumberInputFormatter(country).formatEditUpdate(
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

    final selectedCountryCode = await showDialog<String>(
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
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
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
                          hintText:
                          'Search by country or code (e.g. Lesotho or +266)',
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
                                  Navigator.of(
                                    dialogContext,
                                    rootNavigator: true,
                                  ).pop(country.code);
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

    return selectedCountryCode;
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
            color: const Color(0xFFF9FBFD),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
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
    required TextEditingController controller,
    required String label,
    required String countryCode,
    required void Function(String?) onCountryChanged,
    bool requiredField = false,
    bool allowEmail = false,
  }) {
    final country = _phoneCountryByCode(countryCode);
    final currentIsEmail = allowEmail && _looksLikeEmail(controller.text);
    final phoneHint = country.code == 'INTL'
        ? 'Start with + country code'
        : country.minNationalDigits == country.maxNationalDigits
        ? 'Phone Number (${country.maxNationalDigits} digits)'
        : 'Phone Number '
        '(${country.minNationalDigits}-${country.maxNationalDigits} digits)';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!currentIsEmail) ...[
            SizedBox(
              width: 108,
              child: _countryCodeSelectorButton(
                value: countryCode,
                onChanged: onCountryChanged,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: allowEmail
                  ? TextInputType.emailAddress
                  : country.code == 'INTL'
                  ? TextInputType.phone
                  : TextInputType.number,
              inputFormatters: allowEmail
                  ? null
                  : [MgysdPhoneNumberInputFormatter(country)],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: allowEmail ? (_) => setState(() {}) : null,
              validator: (value) => allowEmail
                  ? _phoneOrEmailValidator(
                value,
                requiredField: requiredField,
                countryCode: countryCode,
              )
                  : _phoneValidator(
                value,
                requiredField: requiredField,
                countryCode: countryCode,
              ),
              decoration: InputDecoration(
                labelText: allowEmail
                    ? label
                    : _phoneFieldLabel(label, country),
                hintText: allowEmail
                    ? 'Enter a phone number or email address'
                    : phoneHint,
                errorMaxLines: 4,
                filled: true,
                fillColor: const Color(0xFFF9FBFD),
                prefixIcon: allowEmail && currentIsEmail
                    ? const Icon(Icons.email_outlined, size: 19)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Colors.blueGrey.withOpacity(0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: widget.color, width: 1.35),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReferralDate() async {
    final initial = DateTime.tryParse(_referralDateController.text.trim()) ??
        DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _referralDateController.text = _formatDate(picked);
      });
    }
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  _ServiceCategory? get _category {
    for (final item in _serviceCategories) {
      if (item.label == _selectedCategory) return item;
    }
    return null;
  }

  Map<String, dynamic> _payload() {
    return {
      'referralDate': _referralDateController.text.trim(),
      'referringOrganisation': _referringOrgController.text.trim(),
      'referrer': {
        'name': _referrerNameController.text.trim(),
        'title': _referrerTitleController.text.trim(),
        'contact': _referrerContactController.text.trim(),
        'location': _referrerLocationController.text.trim(),
      },
      'serviceCategoryReferredFor': _selectedCategory,
      'services': _selectedServices.toList(),
      'receivingOrganisation': _receivingOrganisationController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'contactPhone': _normalisedPhoneNumber(
        _contactPhoneController.text,
        _contactPhoneCountryCode,
      ),
      'priority': _priority,
      'consentDiscussed': _consentDiscussed,
      'reasonForReferral': _reasonForReferralController.text.trim(),
      'urgentActionRequired': _urgentActionController.text.trim(),
      'documentsAccompanying': _documentsAccompanyingController.text.trim(),
      'recommendations': _recommendationsController.text.trim(),
      'client': {
        'name': widget.clientName ?? '',
        'fileNumber': widget.fileNumber ?? widget.mgysdCase.caseNo,
        'householdTei': widget.householdTei ?? '',
        'householdName': widget.householdName ?? '',
      },
    };
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory.trim().isEmpty) {
      _showSnack('Please select the service category referred for.');
      return;
    }

    if (_selectedServices.isEmpty) {
      _showSnack('Please select at least one service.');
      return;
    }

    setState(() => _saving = true);

    try {
      final db = await _db();
      final now = DateTime.now();
      final eventDate = _referralDateController.text.trim().isNotEmpty
          ? _referralDateController.text.trim()
          : _today();

      await MgysdProgramStageEventHelper.saveProgramStageEvent(
        db: db,
        eventId: widget.mgysdCase.id,
        status: status,
        eventDate: eventDate,
        dataValues: {
          MgysdDhis2Uids.deReferralServiceCategory: _selectedCategory,
          MgysdDhis2Uids.deReferralReceivingOrganisation: _receivingOrganisationController.text,
          MgysdDhis2Uids.deReferralContactPerson: _contactPersonController.text,
          MgysdDhis2Uids.deReferralContactPhone: _contactPhoneController.text,
          MgysdDhis2Uids.deReferralDocuments: _documentsAccompanyingController.text,
          MgysdDhis2Uids.deReferralReason: _reasonForReferralController.text,
          MgysdDhis2Uids.deReferralPriority: _priority,
          MgysdDhis2Uids.deReferralRecommendations: _recommendationsController.text,
        },
      );

      await db.insert(
        'mgysd_referral',
        {
          'id': widget.mgysdCase.id,
          'caseId': widget.mgysdCase.id,
          'householdTei': (widget.householdTei ?? '').trim(),
          'referralDate': eventDate,
          'status': status,
          'payloadJson': jsonEncode(_payload()),
          'updatedAt': now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!mounted) return;
      setState(() => _savedStatus = status);
      _showSnack(
        status == 'COMPLETED'
            ? 'Referral completed successfully.'
            : 'Referral draft saved.',
      );

      Navigator.pop(context, {
        'referralSaved': true,
        'status': status,
        'caseId': widget.mgysdCase.id,
        'householdTei': (widget.householdTei ?? '').trim(),
      });
    } catch (e) {
      _showSnack('Failed to save referral: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _pageHeader() {
    final client = (widget.clientName ?? '').trim().isEmpty
        ? 'Client / household'
        : widget.clientName!.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.color,
            widget.color.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.18),
            child: const Icon(
              Icons.handshake_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Referral',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  client,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'File: ${widget.fileNumber ?? widget.mgysdCase.caseNo}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          _statusBadge(_savedStatus ?? 'DRAFT'),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.26)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: widget.color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12.5,
                        height: 1.32,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _input(
      TextEditingController controller,
      String label, {
        String? hint,
        bool requiredField = false,
        bool readOnly = false,
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        VoidCallback? onTap,
        IconData? prefixIcon,
        IconData? suffixIcon,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onTap: onTap,
        validator: requiredField
            ? (value) {
          if ((value ?? '').trim().isEmpty) return 'Required';
          return null;
        }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: readOnly
              ? Colors.blueGrey.withOpacity(0.04)
              : const Color(0xFFF9FBFD),
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 19),
          suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 19),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: widget.color, width: 1.35),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String value) onChanged,
    required Map<String, String> labels,
    bool requiredField = false,
    IconData? prefixIcon,
  }) {
    final safeValue = options.contains(value) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
            value: option,
            child: Text(
              labels[option] ?? option,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
        onChanged: (newValue) {
          if (newValue == null) return;
          onChanged(newValue);
        },
        validator: requiredField
            ? (value) {
          if ((value ?? '').trim().isEmpty) return 'Required';
          return null;
        }
            : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF9FBFD),
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 19),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: widget.color, width: 1.35),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        ),
      ),
    );
  }

  Widget _attachmentsSelector() {
    final selectedText = _selectedAttachments.join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final selected = Set<String>.from(_selectedAttachments);

          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (dialogContext, setModalState) {
                  return AlertDialog(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: _attachmentLabels.keys.map((option) {
                          return CheckboxListTile(
                            value: selected.contains(option),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: widget.color,
                            title: Text(_attachmentLabels[option] ?? option),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  selected.add(option);
                                } else {
                                  selected.remove(option);
                                }
                              });

                              setState(() {
                                _selectedAttachments
                                  ..clear()
                                  ..addAll(selected);
                                _documentsAccompanyingController.text =
                                    _selectedAttachments.join(', ');
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        child: InputDecorator(
          isEmpty: selectedText.isEmpty,
          decoration: InputDecoration(
            labelText: 'Documents accompanying referral',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: const Color(0xFFF9FBFD),
            // Attachment icon remains intentionally commented out.
            // prefixIcon: const Icon(Icons.attach_file_outlined, size: 19),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.blueGrey.withOpacity(0.18),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: widget.color, width: 1.35),
            ),
            contentPadding:
            const EdgeInsets.fromLTRB(13, 16, 13, 13),
          ),
          child: Text(
            selectedText.isEmpty
                ? 'Select one or more documents'
                : selectedText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selectedText.isEmpty ? Colors.blueGrey : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Service category referred for *',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _serviceCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 94,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final category = _serviceCategories[index];
            final selected = _selectedCategory == category.label;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  _selectedCategory = category.label;
                  _selectedServices.clear();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? widget.color.withOpacity(0.12)
                      : const Color(0xFFF9FBFD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? widget.color.withOpacity(0.55)
                        : Colors.blueGrey.withOpacity(0.14),
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      category.icon,
                      color: selected ? widget.color : Colors.blueGrey,
                    ),
                    const Spacer(),
                    Text(
                      category.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? widget.color : Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _servicesSelector() {
    final category = _category;

    if (category == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.22)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select a service category first. The specific services will appear here.',
                style: TextStyle(
                  color: Colors.blueGrey,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.color.withOpacity(0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services under ${category.label} *',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...category.services.map((service) {
            final selected = _selectedServices.contains(service);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: widget.color,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected,
              title: Text(
                service,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedServices.add(service);
                  } else {
                    _selectedServices.remove(service);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _consentTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _consentDiscussed
            ? Colors.green.withOpacity(0.07)
            : Colors.blueGrey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _consentDiscussed
              ? Colors.green.withOpacity(0.18)
              : Colors.blueGrey.withOpacity(0.12),
        ),
      ),
      child: CheckboxListTile(
        activeColor: Colors.green,
        value: _consentDiscussed,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'Referral discussed with client / caregiver',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Tick when the referral purpose and expected support were explained.',
          style: TextStyle(color: Colors.blueGrey),
        ),
        onChanged: (value) {
          setState(() => _consentDiscussed = value ?? false);
        },
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _save('DRAFT'),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Draft'),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.color,
                side: BorderSide(color: widget.color.withOpacity(0.45)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _save('COMPLETED'),
              icon: _saving
                  ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priorityOptions = _priorityLabels.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: widget.color,
        title: const Text('Referral'),
        actions: [
          IconButton(
            onPressed: _saving
                ? null
                : () {
              _referralDateController.text = _today();
              _referringOrgController.text =
              'Ministry of Gender Youth and Social Development';
              _populateCurrentUser();
              _showSnack('Referral defaults refreshed.');
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh defaults',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            _pageHeader(),
            _section(
              title: 'Referral Details',
              subtitle:
              'Capture when the referral is made and the organisation making the referral.',
              icon: Icons.assignment_outlined,
              children: [
                _input(
                  _referralDateController,
                  'Date of Referral',
                  requiredField: true,
                  readOnly: true,
                  onTap: _pickReferralDate,
                  prefixIcon: Icons.event_outlined,
                  suffixIcon: Icons.calendar_today_outlined,
                ),
                _input(
                  _referringOrgController,
                  'Name of Referring Organisation',
                  requiredField: true,
                  prefixIcon: Icons.account_balance_outlined,
                ),
              ],
            ),
            _section(
              title: 'Person Making Referral',
              subtitle:
              'Auto-populated from the logged-in user. These details help the receiving provider follow up.',
              icon: Icons.person_pin_circle_outlined,
              children: [
                _input(
                  _referrerNameController,
                  'Name',
                  readOnly: true,
                  requiredField: true,
                  prefixIcon: Icons.person_outline,
                ),
                _input(
                  _referrerTitleController,
                  'Title / Role',
                  readOnly: true,
                  prefixIcon: Icons.badge_outlined,
                ),
                _input(
                  _referrerContactController,
                  'Phone / Email',
                  readOnly: true,
                  prefixIcon: Icons.phone_outlined,
                ),
                _input(
                  _referrerLocationController,
                  'Location',
                  readOnly: true,
                  prefixIcon: Icons.place_outlined,
                ),
              ],
            ),
            _section(
              title: 'Service Category Referred For',
              subtitle:
              'Select the main service category and the specific services needed.',
              icon: Icons.category_outlined,
              children: [
                _categorySelector(),
                _servicesSelector(),
              ],
            ),
            _section(
              title: 'Receiving Service Provider',
              subtitle:
              'Capture the organisation or office expected to provide the selected service.',
              icon: Icons.apartment_outlined,
              children: [
                _input(
                  _receivingOrganisationController,
                  'Receiving organisation / office',
                  hint: 'Example: District Social Assistance Office',
                  requiredField: true,
                  prefixIcon: Icons.business_outlined,
                ),
                _input(
                  _contactPersonController,
                  'Contact person',
                  prefixIcon: Icons.person_outline,
                ),
                _phoneInputField(
                  controller: _contactPhoneController,
                  label: 'Contact phone',
                  countryCode: _contactPhoneCountryCode,
                  onCountryChanged: (value) => setState(() {
                    final newCountryCode = value ?? 'LS';
                    _contactPhoneCountryCode = newCountryCode;
                    _formatPhoneControllerForSelectedCountry(
                      _contactPhoneController,
                      newCountryCode,
                    );
                  }),
                ),
              ],
            ),
            _section(
              title: 'Referral Notes',
              subtitle:
              'Document why the referral is needed and what outcome is expected.',
              icon: Icons.notes_outlined,
              children: [
                _dropdown(
                  label: 'Referral priority',
                  value: _priority,
                  options: priorityOptions,
                  labels: _priorityLabels,
                  onChanged: (value) => setState(() => _priority = value),
                  requiredField: true,
                  prefixIcon: Icons.priority_high_outlined,
                ),
                _consentTile(),
                _input(
                  _reasonForReferralController,
                  'Reason for referral',
                  hint:
                  'Briefly explain the client or household need that requires referral.',
                  requiredField: true,
                  maxLines: 4,
                  prefixIcon: Icons.edit_note_outlined,
                ),
                if (_priority == 'URGENT' || _priority == 'EMERGENCY')
                  _input(
                    _urgentActionController,
                    'Immediate action required',
                    hint: 'Describe what must happen urgently and by whom.',
                    requiredField: _priority == 'EMERGENCY',
                    maxLines: 3,
                    prefixIcon: Icons.warning_amber_outlined,
                  ),
                _attachmentsSelector(),
                _input(
                  _recommendationsController,
                  'Recommendations / expected result',
                  hint:
                  'What should the receiving organisation do and what result is expected?',
                  maxLines: 4,
                  prefixIcon: Icons.task_alt_outlined,
                ),
              ],
            ),
            _buildButtons(),
          ],
        ),
      ),
    );
  }
}