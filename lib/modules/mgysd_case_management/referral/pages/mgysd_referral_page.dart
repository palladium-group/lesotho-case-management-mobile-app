import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lncmis_mobile_app/app_state/current_user_state/current_user_state.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
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
  String _priority = 'ROUTINE';
  bool _consentDiscussed = false;
  bool _saving = false;
  String? _savedStatus;
  bool _userFilled = false;

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
      'contactPhone': _contactPhoneController.text.trim(),
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
                _input(
                  _contactPhoneController,
                  'Contact phone',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
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
                _input(
                  _documentsAccompanyingController,
                  'Documents accompanying referral',
                  hint:
                  'Example: assessment notes, ID copy, medical note, court document',
                  maxLines: 3,
                  prefixIcon: Icons.attach_file_outlined,
                ),
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
