import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/core/utils/app_util.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:sqflite/sqflite.dart';

class MgysdCaseClosurePage extends StatefulWidget {
  const MgysdCaseClosurePage({
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
  State<MgysdCaseClosurePage> createState() => _MgysdCaseClosurePageState();
}

class _PersonInMeeting {
  final String localId;
  final TextEditingController nameController;
  final TextEditingController relationshipController;

  _PersonInMeeting({
    required this.localId,
    String name = '',
    String relationship = '',
  })  : nameController = TextEditingController(text: name),
        relationshipController = TextEditingController(text: relationship);

  void dispose() {
    nameController.dispose();
    relationshipController.dispose();
  }

  Map<String, dynamic> toJson() => {
    'name': nameController.text.trim(),
    'relationshipToClient': relationshipController.text.trim(),
  };
}

class _MgysdCaseClosurePageState extends State<MgysdCaseClosurePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  String _closureId = '';
  String _parentCaseId = '';
  String _householdTei = '';
  String _caseOrgUnit = '';

  final TextEditingController _closureDateController = TextEditingController();
  final TextEditingController _caseOpeningDateController = TextEditingController();
  final TextEditingController _currentAddressController = TextEditingController();
  final TextEditingController _previousAddressController = TextEditingController();
  // Decision checkboxes
  final Map<String, bool> _closureDecisions = {
    'OBJECTIVES_MET': false,
    'CHANGE_IN_CIRCUMSTANCES': false,
    'NO_LONGER_WILLING': false,
    'CLIENT_MOVED': false,
    'LOST_TO_FOLLOW_UP': false,
  };

  static const Map<String, String> _closureDecisionLabels = {
    'OBJECTIVES_MET': 'All or most objectives agreed in the case plan have been met',
    'CHANGE_IN_CIRCUMSTANCES': 'Change in circumstances means client no longer in need of care and protection',
    'NO_LONGER_WILLING': 'The client and / or family no longer willing to participate',
    'CLIENT_MOVED': 'The client has moved, and case transferred to (note country or district & social worker)',
    'LOST_TO_FOLLOW_UP': 'The client has been lost to follow up (the client cannot be traced)',
  };

  final List<_PersonInMeeting> _peopleInMeeting = [];

  @override
  void initState() {
    super.initState();
    _parentCaseId = widget.mgysdCase.id.split('__').first;
    _closureId = _resolveClosureId(widget.mgysdCase.id);
    _closureDateController.text = _today();
    _loadData();
  }

  @override
  void dispose() {
    _closureDateController.dispose();
    _caseOpeningDateController.dispose();
    _currentAddressController.dispose();
    _previousAddressController.dispose();
    for (final person in _peopleInMeeting) {
      person.dispose();
    }
    super.dispose();
  }

  String _resolveClosureId(String rawId) {
    if (rawId.trim().length == 11 && !rawId.contains('__')) return rawId.trim();
    final parts = rawId.split('__');
    if (parts.length >= 3 && parts.last.trim().length == 11) return parts.last.trim();
    return AppUtil.getUid();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  String _today() {
    final d = DateTime.now();
    return _formatDate(d);
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = _formatDate(picked));
    }
  }


  Future<void> _ensureClosureColumns(Database db) async {
    try {
    await db.execute('''
            CREATE TABLE IF NOT EXISTS mgysd_case_closure (
              id TEXT PRIMARY KEY,
              caseId TEXT,
              householdTei TEXT,
              closureDate TEXT,
              status TEXT,
              payloadJson TEXT,
              updatedAt TEXT
            )
          ''');
    } catch (_) {}
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }


  String _text(dynamic value) => (value ?? '').toString().trim();

  void _addPersonToMeeting() {
    setState(() {
      _peopleInMeeting.add(
        _PersonInMeeting(
          localId: DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );
    });
  }

  void _removePersonFromMeeting(int index) {
    setState(() {
      _peopleInMeeting[index].dispose();
      _peopleInMeeting.removeAt(index);
    });
  }

  Future<void> _loadCaseOpeningDate(Database db) async {
    try {
      final rows = await db.query(
        'enrollment',
        columns: ['enrollmentDate'],
        where: 'enrollment = ?',
        whereArgs: [_parentCaseId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final date = _text(rows.first['enrollmentDate']);
        if (date.isNotEmpty) {
          _caseOpeningDateController.text = date.length >= 10
              ? date.substring(0, 10)
              : date;
        }
      }
    } catch (_) {}
  }

  Future<void> _resolveCaseContext(Database db) async {
    _householdTei = (widget.householdTei ?? '').trim();

    final enrollmentRows = await db.query(
      'enrollment',
      where: 'enrollment = ?',
      whereArgs: [_parentCaseId],
      limit: 1,
    );

    if (enrollmentRows.isNotEmpty) {
      final row = enrollmentRows.first;
      _caseOrgUnit = _text(row['orgUnit']);
      if (_householdTei.isEmpty) {
        _householdTei = _text(row['trackedEntityInstance']);
      }
    }
  }

  Future<void> _loadSavedClosure(Database db) async {
    if (!await _tableExists(db, 'mgysd_case_closure')) return;

    final rows = await db.query(
      'mgysd_case_closure',
      where: 'id = ?',
      whereArgs: [_closureId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    _closureDateController.text = _text(row['closureDate']).isEmpty
        ? _closureDateController.text
        : _text(row['closureDate']);

    try {
      final payloadRaw = _text(row['payloadJson']);
      if (payloadRaw.isNotEmpty) {
        final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;

        _currentAddressController.text = _text(payload['currentAddress']);
        _previousAddressController.text = _text(payload['previousAddress']);

        // Restore decisions
        final decisions = payload['closureDecisions'] as Map<String, dynamic>? ?? {};
        decisions.forEach((key, value) {
          if (_closureDecisions.containsKey(key)) {
            _closureDecisions[key] = value == true;
          }
        });

        // Restore people in meeting
        final list = payload['peopleInMeeting'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          _peopleInMeeting.clear();
          for (final item in list) {
            final m = item as Map<String, dynamic>;
            _peopleInMeeting.add(_PersonInMeeting(
              localId: DateTime.now().microsecondsSinceEpoch.toString(),
              name: _text(m['name']),
              relationship: _text(m['relationshipToClient']),
            ));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = await _db();
      await _ensureClosureColumns(db);
      await _resolveCaseContext(db);
      await _loadCaseOpeningDate(db);
      await _loadSavedClosure(db);
      if (_peopleInMeeting.isEmpty) _addPersonToMeeting();
    } catch (e) {
      _showSnack('Failed to load case closure: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _payload(String status) {
    return {
      'id': _closureId,
      'caseId': _parentCaseId,
      'householdTei': _householdTei,
      'closureDate': _closureDateController.text.trim(),
      'caseOpeningDate': _caseOpeningDateController.text.trim(),
      'clientName': widget.clientName ?? '',
      'currentAddress': _currentAddressController.text.trim(),
      'previousAddress': _previousAddressController.text.trim(),
      'closureDecisions': Map<String, bool>.from(_closureDecisions),
      'peopleInMeeting': _peopleInMeeting.map((e) => e.toJson()).toList(),
      'status': status,
    };
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (status == 'COMPLETED') {
      final hasDecision = _closureDecisions.values.any((v) => v);
      if (!hasDecision) {
        _showSnack('Please select at least one decision for case closure.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final db = await _db();
      final now = DateTime.now().toIso8601String();
      final closureDate = _closureDateController.text.trim().isEmpty
          ? _today()
          : _closureDateController.text.trim();

      await db.insert(
        'mgysd_case_closure',
        {
          'id': _closureId,
          'caseId': _parentCaseId,
          'parentCaseId': _parentCaseId,
          'rootCaseId': _parentCaseId,
          'householdTei': _householdTei,
          'closureDate': closureDate,
          'stageKey': 'case_closure',
          'status': status,
          'payloadJson': jsonEncode(_payload(status)),
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!mounted) return;
      if (status == 'COMPLETED') {
        _showSnack('Case closure completed.');
        Navigator.pop(context, true);
      } else {
        _showSnack('Case closure saved as draft.');
      }
    } catch (e) {
      _showSnack('Failed to save case closure: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _surface({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: widget.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15.8, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.blueGrey, height: 1.35, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
        bool readOnly = false,
        VoidCallback? onTap,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
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
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
      );
    });
  }

  Widget _chip(String label, {Color? color}) {
    final c = color ?? Colors.blueGrey;
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _header() {
    final title = (widget.householdName ?? '').trim().isNotEmpty
        ? widget.householdName!.trim()
        : (widget.clientName ?? widget.mgysdCase.fullName);
    return _surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: widget.color.withOpacity(0.12),
            child: Icon(Icons.folder_off_outlined, color: widget.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Case: ${widget.mgysdCase.caseNo}', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _chip('Case Closure', color: widget.color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _caseDetailsSection() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Case Details',
            'Basic information about the client and case dates.',
            Icons.info_outline,
          ),
          _input(
            _closureDateController,
            'Date of completion',
            readOnly: true,
            onTap: () => _pickDate(_closureDateController),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          _two(
            _input(
              _caseOpeningDateController,
              'Case opening date',
              readOnly: true,
            ),
            _input(
              _closureDateController,
              'Case closure date',
              readOnly: true,
              onTap: () => _pickDate(_closureDateController),
            ),
          ),
          _input(_currentAddressController, 'Client\'s current address (include community council and district)', maxLines: 2),
          _input(_previousAddressController, 'Client\'s previous address (if different from current)', maxLines: 2),
        ],
      ),
    );
  }

  Widget _decisionsSection() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Criteria for case closure',
            'Select all reasons that apply for closing this case.',
            Icons.gavel_outlined,
          ),
          ..._closureDecisions.entries.map((entry) {
            return CheckboxListTile(
              value: entry.value,
              activeColor: widget.color,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _closureDecisionLabels[entry.key] ?? entry.key,
                style: const TextStyle(fontSize: 13.5, height: 1.3),
              ),
              onChanged: (val) {
                setState(() {
                  _closureDecisions[entry.key] = val ?? false;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _peopleInMeetingSection() {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'People involved in final case closure meeting',
            'List all people who were present at the case closure meeting.',
            Icons.groups_outlined,
          ),
          ..._peopleInMeeting.asMap().entries.map((e) {
            final idx = e.key;
            final person = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFD),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Person ${idx + 1}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _two(
                    _input(person.nameController, 'Name'),
                    _input(person.relationshipController, 'Relationship to client'),
                  ),
                  if (_peopleInMeeting.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _removePersonFromMeeting(idx),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: _addPersonToMeeting,
            icon: const Icon(Icons.add),
            label: const Text('Add another person'),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : () => _save('DRAFT'),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color.withOpacity(0.45)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saving ? null : () => _save('COMPLETED'),
            icon: _saving
                ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Saving...' : 'Close Case'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: widget.color,
        title: const Text('Case Closure'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              _caseDetailsSection(),
              _decisionsSection(),

              _peopleInMeetingSection(),
              const SizedBox(height: 4),
              _actions(),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}