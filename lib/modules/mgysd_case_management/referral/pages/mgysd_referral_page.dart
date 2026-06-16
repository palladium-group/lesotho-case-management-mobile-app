import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lncmis_mobile_app/app_state/current_user_state/current_user_state.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/helpers/mgysd_program_stage_event_helper.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:sqflite/sqflite.dart';

// ---------------------------------------------------------------------------
// Need categories – matches Form 4 in the PDF exactly.
//
// Structure:
//   • Top-level items with isParent=false  → plain checkbox
//   • Top-level items with isParent=true   → checkbox that, when ticked,
//     reveals its children as sub-checkboxes
//   • Items with isOther=true              → checkbox + free-text field
//   • childOtherKeys                       → child labels that need their own
//     free-text field when selected (keyed by child label)
// ---------------------------------------------------------------------------
class _NeedItem {
  final String label;
  final bool isParent;
  final bool isOther;
  final List<String> children;
  final Set<String> childOtherKeys;

  const _NeedItem({
    required this.label,
    this.isParent = false,
    this.isOther = false,
    this.children = const [],
    this.childOtherKeys = const {},
  });
}

class _NeedCategory {
  final String label;
  final List<_NeedItem> items;
  const _NeedCategory({required this.label, required this.items});
}

const List<_NeedCategory> _needCategories = [
  _NeedCategory(label: 'Social Protection Support', items: [
    _NeedItem(label: 'Transportation Assistance'),
    _NeedItem(label: 'Food Assistance'),
    _NeedItem(label: 'Social Assistance (Bursary)'),
  ]),
  _NeedCategory(label: 'Education', items: [
    _NeedItem(label: 'Bursary or other financial or material support'),
    _NeedItem(label: 'Vocational training'),
    _NeedItem(label: 'Early Childhood Development'),
    _NeedItem(label: 'Support to return to school / homework support'),
  ]),
  _NeedCategory(label: 'Health Support', items: [
    _NeedItem(label: 'Nutritional support'),
    _NeedItem(label: 'Support related to primary care'),
    _NeedItem(label: 'HIV-related care and support'),
    _NeedItem(label: 'Reproductive health / sexual health services'),
    _NeedItem(
      label: 'Disability support',
      isParent: true,
      children: [
        'Medical assessment',
        'Physiotherapy',
        'Assistive devices',
        'Other disability support (specify)',
      ],
      childOtherKeys: {'Other disability support (specify)'},
    ),
  ]),
  _NeedCategory(label: 'Mental Health Support', items: [
    _NeedItem(label: 'Psychiatric Services'),
    _NeedItem(label: 'Substance abuse services'),
    _NeedItem(label: 'Psychosocial support / counselling'),
    _NeedItem(label: 'Support group'),
  ]),
  _NeedCategory(label: 'Community Development', items: [
    _NeedItem(label: 'Skills Development'),
    _NeedItem(label: 'Income Generating Activity'),
    _NeedItem(label: 'Job placement'),
    _NeedItem(label: 'Start-up kit / capital'),
    _NeedItem(label: 'Economic empowerment'),
  ]),
  _NeedCategory(label: 'Legal/Justice Services', items: [
    _NeedItem(label: 'Master of High Court'),
    _NeedItem(label: 'Probation'),
    _NeedItem(label: 'Magistrate Court'),
    _NeedItem(label: "Children's Court"),
    _NeedItem(label: 'High Court'),
    _NeedItem(label: 'Child and Gender Protection Unit (CGPU)'),
  ]),
  _NeedCategory(label: 'NICR', items: [
    _NeedItem(label: 'Birth registration / civil registration support'),
  ]),
];

// ---------------------------------------------------------------------------
// Main Widget
// ---------------------------------------------------------------------------
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

class _MgysdReferralPageState extends State<MgysdReferralPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Date ──────────────────────────────────────────────────────────────────
  final _referralDateController = TextEditingController();

  // ── Person Making Referral (auto-filled from CurrentUserState, read-only) ─
  late final TextEditingController _referrerNameController;
  late final TextEditingController _referrerTitleController;
  late final TextEditingController _referrerContactController;
  late final TextEditingController _referrerLocationController;

  // ── Referring Organisation (user-editable) ────────────────────────────────
  final _referringOrgController = TextEditingController();

  // ── Referred To ───────────────────────────────────────────────────────────
  final _referredToOrgController     = TextEditingController();
  final _referredToSpecifyController = TextEditingController();

  // ── Extra fields ──────────────────────────────────────────────────────────
  final _supportsProvidedController      = TextEditingController();
  final _documentsAccompanyingController = TextEditingController();
  final _recommendationsController       = TextEditingController();

  // ── Needs ─────────────────────────────────────────────────────────────────
  final Map<String, Set<String>> _selectedItems = {
    for (final cat in _needCategories) cat.label: {},
  };
  final Map<String, Set<String>> _selectedChildren = {};
  final Map<String, TextEditingController> _otherControllers = {};
  final Map<String, TextEditingController> _childOtherControllers = {};

  bool _saving = false;
  String? _savedStatus;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Initialise empty – filled from Provider in didChangeDependencies
    _referrerNameController     = TextEditingController();
    _referrerTitleController    = TextEditingController();
    _referrerContactController  = TextEditingController();
    _referrerLocationController = TextEditingController();

    for (final cat in _needCategories) {
      for (final item in cat.items) {
        if (item.isOther) {
          _otherControllers[item.label] = TextEditingController();
        }
        if (item.isParent) {
          _selectedChildren[item.label] = {};
          for (final childKey in item.childOtherKeys) {
            _childOtherControllers[childKey] = TextEditingController();
          }
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only fill once – guard prevents clobbering on subsequent dependency changes
    if (_referrerNameController.text.isNotEmpty) return;

    final userState = context.read<CurrentUserState>();
    final user = userState.currentUser;

    _referrerNameController.text     = user?.name ?? '';
    _referrerTitleController.text    = user?.userRoles ?? '';
    _referrerContactController.text  = user?.phoneNumber ?? user?.email ?? '';
    _referrerLocationController.text = userState.currentUserLocations;
  }

  @override
  void dispose() {
    _referralDateController.dispose();
    _referrerNameController.dispose();
    _referrerTitleController.dispose();
    _referrerContactController.dispose();
    _referrerLocationController.dispose();
    _referringOrgController.dispose();
    _referredToOrgController.dispose();
    _referredToSpecifyController.dispose();
    _supportsProvidedController.dispose();
    _documentsAccompanyingController.dispose();
    _recommendationsController.dispose();
    for (final c in _otherControllers.values) {
      c.dispose();
    }
    for (final c in _childOtherControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── DB helpers ────────────────────────────────────────────────────────────
  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  void _showSnack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Map<String, dynamic> _payload() => {
    'referringOrganisation':  _referringOrgController.text.trim(),
    'referrerName':           _referrerNameController.text.trim(),
    'referrerTitle':          _referrerTitleController.text.trim(),
    'referrerContact':        _referrerContactController.text.trim(),
    'referrerLocation':       _referrerLocationController.text.trim(),
    'referredToOrganisation': _referredToOrgController.text.trim(),
    'referredToSpecify':      _referredToSpecifyController.text.trim(),
    'supportsProvided':       _supportsProvidedController.text.trim(),
    'documentsAccompanying':  _documentsAccompanyingController.text.trim(),
    'recommendations':        _recommendationsController.text.trim(),
    'identifiedNeeds': {
      for (final cat in _needCategories)
        cat.label: {
          'selected': _selectedItems[cat.label]!.toList(),
          'subSelections': {
            for (final item in cat.items)
              if (item.isParent &&
                  (_selectedChildren[item.label]?.isNotEmpty ?? false))
                item.label: _selectedChildren[item.label]!.toList(),
          },
          'otherText': {
            for (final item in cat.items)
              if (item.isOther &&
                  _selectedItems[cat.label]!.contains(item.label) &&
                  (_otherControllers[item.label]?.text.trim().isNotEmpty ??
                      false))
                item.label: _otherControllers[item.label]!.text.trim(),
          },
          'childOtherText': {
            for (final item in cat.items)
              if (item.isParent)
                for (final childKey in item.childOtherKeys)
                  if ((_selectedChildren[item.label]
                      ?.contains(childKey) ??
                      false) &&
                      (_childOtherControllers[childKey]
                          ?.text
                          .trim()
                          .isNotEmpty ??
                          false))
                    childKey:
                    _childOtherControllers[childKey]!.text.trim(),
          },
        },
    },
  };

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final db  = await _db();
      final now = DateTime.now();

      final eventDate = _referralDateController.text.trim().isNotEmpty
          ? _referralDateController.text.trim()
          : '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      await MgysdProgramStageEventHelper.saveProgramStageEvent(
        db: db,
        eventId: widget.mgysdCase.id,
        status: status,
        eventDate: eventDate,
      );

      await db.insert(
        'mgysd_referral',
        {
          'id':           widget.mgysdCase.id,
          'caseId':       widget.mgysdCase.id,
          'householdTei': (widget.householdTei ?? '').trim(),
          'referralDate': eventDate,
          'status':       status,
          'payloadJson':  jsonEncode(_payload()),
          'updatedAt':    now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!mounted) return;
      setState(() => _savedStatus = status);
      _showSnack(status == 'COMPLETED'
          ? 'Referral saved successfully.'
          : 'Referral draft saved.');
    } catch (e) {
      _showSnack('Failed to save referral: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w800, color: widget.color),
    ),
  );

  Widget _divider() => const Divider(height: 1, thickness: 1);

  Widget _field({
    required String label,
    required Widget child,
    bool isRequired = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (isRequired)
                const Text(' *',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 7),
            child,
          ],
        ),
      );

  Widget _readOnlyField(String label, TextEditingController controller) =>
      _field(
        label: label,
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: const Icon(Icons.lock_outline,
                size: 16, color: Colors.grey),
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  // ── Needs section ─────────────────────────────────────────────────────────
  Widget _needsSection() => _card([
    _sectionHeader('Needs Identified and Discussed with Client'),
    _divider(),
    const SizedBox(height: 8),
    for (final cat in _needCategories) ...[
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(cat.label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      for (final item in cat.items) ...[
        // ── Top-level checkbox ──────────────────────────────────────────
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(item.label,
              style: const TextStyle(fontSize: 13)),
          value: _selectedItems[cat.label]!.contains(item.label),
          activeColor: widget.color,
          onChanged: (checked) => setState(() {
            if (checked == true) {
              _selectedItems[cat.label]!.add(item.label);
            } else {
              _selectedItems[cat.label]!.remove(item.label);
              if (item.isParent) {
                _selectedChildren[item.label]?.clear();
              }
              if (item.isOther) {
                _otherControllers[item.label]?.clear();
              }
            }
          }),
        ),

        // ── Sub-options for parent items ────────────────────────────────
        if (item.isParent &&
            _selectedItems[cat.label]!.contains(item.label))
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in item.children) ...[
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(child,
                        style: const TextStyle(fontSize: 12)),
                    value: _selectedChildren[item.label]
                        ?.contains(child) ??
                        false,
                    activeColor: widget.color,
                    onChanged: (checked) => setState(() {
                      _selectedChildren[item.label] ??= {};
                      if (checked == true) {
                        _selectedChildren[item.label]!.add(child);
                      } else {
                        _selectedChildren[item.label]!.remove(child);
                        if (item.childOtherKeys.contains(child)) {
                          _childOtherControllers[child]?.clear();
                        }
                      }
                    }),
                  ),
                  // Free-text field for childOtherKeys children
                  if (item.childOtherKeys.contains(child) &&
                      (_selectedChildren[item.label]?.contains(child) ??
                          false))
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 8, bottom: 8),
                      child: TextFormField(
                        controller: _childOtherControllers[child],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Please specify…',
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),

        // ── Free-text for "Other (specify)" top-level items ─────────────
        if (item.isOther &&
            _selectedItems[cat.label]!.contains(item.label))
          Padding(
            padding:
            const EdgeInsets.only(left: 32, right: 8, bottom: 8),
            child: TextFormField(
              controller: _otherControllers[item.label],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Please specify…',
                isDense: true,
              ),
            ),
          ),
      ],
      _divider(),
    ],
  ]);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: widget.color,
        title: const Text('Form 4: Social Protection Service Referral'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Client header ─────────────────────────────────────────────
            _card([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Client's Full Name",
                            style: TextStyle(
                                fontSize: 11, color: Colors.blueGrey)),
                        const SizedBox(height: 2),
                        Text(
                          widget.clientName ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('File Number',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blueGrey)),
                      const SizedBox(height: 2),
                      Text(
                        widget.fileNumber ?? widget.mgysdCase.caseNo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ],
              ),
            ]),

            // ── Section 1: Referral Details ───────────────────────────────
            _card([
              _sectionHeader('Referral Details'),
              _divider(),
              const SizedBox(height: 12),
              _field(
                label: 'Date of Referral',
                isRequired: true,
                child: TextFormField(
                  controller: _referralDateController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              _field(
                label: 'Name of Referring Organisation',
                isRequired: true,
                child: TextFormField(
                  controller: _referringOrgController,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder()),
                ),
              ),
            ]),

            // ── Section 2: Person Making Referral (auto-filled) ───────────
            _card([
              _sectionHeader('Person Making Referral'),
              const Text(
                'Auto-filled from your account',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              _divider(),
              const SizedBox(height: 12),
              _readOnlyField('Name', _referrerNameController),
              _readOnlyField('Title / Role', _referrerTitleController),
              _readOnlyField('Contact Details', _referrerContactController),
              _readOnlyField('Location', _referrerLocationController),
            ]),

            // ── Section 3: Referred To ────────────────────────────────────
            _card([
              _sectionHeader('This Client Has Been Referred To'),
              _divider(),
              const SizedBox(height: 12),
              _field(
                label: 'Organisation Name',
                isRequired: true,
                child: TextFormField(
                  controller: _referredToOrgController,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder()),
                ),
              ),
              _field(
                label: 'Specify (if needed)',
                child: TextFormField(
                  controller: _referredToSpecifyController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder()),
                ),
              ),
              _field(
                label:
                'List supports or services being provided to the client or family',
                child: TextFormField(
                  controller: _supportsProvidedController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              _field(
                label: 'List any documents accompanying this referral form',
                child: TextFormField(
                  controller: _documentsAccompanyingController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              _field(
                label: 'Recommendations or expected results',
                child: TextFormField(
                  controller: _recommendationsController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ]),

            // ── Section 4: Identified Needs ───────────────────────────────
            _needsSection(),

            const SizedBox(height: 16),

            // ── Action buttons ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _save('DRAFT'),
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color),
                    onPressed:
                    _saving ? null : () => _save('COMPLETED'),
                    child: _saving
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Complete'),
                  ),
                ),
              ],
            ),

            if (_savedStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Current status: $_savedStatus',
                  style: TextStyle(
                      color: widget.color, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}