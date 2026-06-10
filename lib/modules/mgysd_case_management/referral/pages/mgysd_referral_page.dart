
import 'dart:convert';

import 'package:flutter/material.dart';
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
  }) : super(key: key);

  final Color color;
  final MgysdCase mgysdCase;
  final String? householdTei;
  final String? householdName;
  final String? clientName;

  @override
  State<MgysdReferralPage> createState() =>
      _MgysdReferralPageState();
}

class _MgysdReferralPageState
    extends State<MgysdReferralPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController
  _referralDateController =
  TextEditingController();

  final TextEditingController
  _organizationController =
  TextEditingController();

  final TextEditingController
  _reasonController =
  TextEditingController();

  final TextEditingController
  _notesController =
  TextEditingController();

  bool _saving = false;
  String? _savedStatus;

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;

    if (dbClient == null) {
      throw Exception(
        'Offline DB not initialized',
      );
    }

    return dbClient;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Map<String, dynamic> _payload() {
    return {
      'organization':
      _organizationController.text.trim(),
      'reason':
      _reasonController.text.trim(),
      'notes':
      _notesController.text.trim(),
    };
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final db = await _db();

      final now = DateTime.now();

      final eventDate =
      _referralDateController.text.trim().isNotEmpty
          ? _referralDateController.text.trim()
          : '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      // SAVE PROGRAM STAGE EVENT
      await MgysdProgramStageEventHelper
          .saveProgramStageEvent(
        db: db,
        eventId: widget.mgysdCase.id,
        status: status,
        eventDate: eventDate,
      );

      // SAVE LEGACY PAYLOAD
      await db.insert(
        'mgysd_referral',
        {
          'id': widget.mgysdCase.id,
          'caseId': widget.mgysdCase.id,
          'householdTei':
          (widget.householdTei ?? '').trim(),
          'referralDate': eventDate,
          'status': status,
          'payloadJson':
          jsonEncode(_payload()),
          'updatedAt':
          now.toIso8601String(),
        },
        conflictAlgorithm:
        ConflictAlgorithm.replace,
      );

      if (!mounted) return;

      setState(() {
        _savedStatus = status;
      });

      _showSnack(
        status == 'COMPLETED'
            ? 'Referral saved successfully.'
            : 'Referral draft saved.',
      );
    } catch (e) {
      _showSnack(
        'Failed to save referral: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _field({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: widget.color,
        title: const Text('Referral'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            Container(
              padding:
              const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.clientName ??
                        '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.mgysdCase.caseNo,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _field(
              label: 'Referral Date',
              child: TextFormField(
                controller:
                _referralDateController,
                decoration:
                const InputDecoration(
                  border:
                  OutlineInputBorder(),
                  hintText: 'YYYY-MM-DD',
                ),
              ),
            ),
            _field(
              label: 'Organization',
              child: TextFormField(
                controller:
                _organizationController,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
                decoration:
                const InputDecoration(
                  border:
                  OutlineInputBorder(),
                ),
              ),
            ),
            _field(
              label: 'Reason',
              child: TextFormField(
                controller:
                _reasonController,
                maxLines: 3,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
                decoration:
                const InputDecoration(
                  border:
                  OutlineInputBorder(),
                ),
              ),
            ),
            _field(
              label: 'Notes',
              child: TextFormField(
                controller:
                _notesController,
                maxLines: 4,
                decoration:
                const InputDecoration(
                  border:
                  OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child:
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => _save(
                      'DRAFT',
                    ),
                    child:
                    const Text(
                      'Save Draft',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                  ElevatedButton(
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      widget.color,
                    ),
                    onPressed: _saving
                        ? null
                        : () => _save(
                      'COMPLETED',
                    ),
                    child:
                    _saving
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color: Colors
                            .white,
                      ),
                    )
                        : const Text(
                      'Complete',
                    ),
                  ),
                ),
              ],
            ),
            if (_savedStatus != null)
              Padding(
                padding:
                const EdgeInsets.only(
                  top: 12,
                ),
                child: Text(
                  'Current status: $_savedStatus',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
