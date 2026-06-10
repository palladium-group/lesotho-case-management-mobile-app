
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/enrollment/pages/mgysd_new_case_page.dart';
import 'package:sqflite/sqflite.dart';

class MgysdRecordsPage extends StatefulWidget {
  const MgysdRecordsPage({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdRecordsPage> createState() => _MgysdRecordsPageState();
}

enum _RecordsFilter { all, reportedOnly, enrolledOnly }

class _OfflineReportedCase {
  final String dbRowId;
  final String eventId;
  final String eventDate;
  final String program;
  final String programStage;
  final String clientFirstName;
  final String clientLastName;
  final String clientPhone;
  final String clientSex;
  final String clientDistrict;
  final String concernReason;
  final String concernReasonOther;
  final String incidentDate;
  final String incidentLocation;
  final String incidentDescription;
  final int clientsCount;
  final int peopleInvolvedCount;
  final bool isEnrolled;
  final String linkedTei;
  final String linkedEnrollment;

  const _OfflineReportedCase({
    required this.dbRowId,
    required this.eventId,
    required this.eventDate,
    required this.program,
    required this.programStage,
    required this.clientFirstName,
    required this.clientLastName,
    required this.clientPhone,
    required this.clientSex,
    required this.clientDistrict,
    required this.concernReason,
    required this.concernReasonOther,
    required this.incidentDate,
    required this.incidentLocation,
    required this.incidentDescription,
    required this.clientsCount,
    required this.peopleInvolvedCount,
    required this.isEnrolled,
    required this.linkedTei,
    required this.linkedEnrollment,
  });

  String get displayName {
    final full = ('$clientFirstName $clientLastName').trim();
    return full.isEmpty ? '(No client name)' : full;
  }

  String get searchableText {
    return [
      eventId,
      displayName,
      clientPhone,
      clientSex,
      clientDistrict,
      concernReason,
      concernReasonOther,
      incidentLocation,
      incidentDescription,
      isEnrolled ? 'enrolled' : 'reported',
    ].join(' ').toLowerCase();
  }
}

class _MgysdRecordsPageState extends State<MgysdRecordsPage> {
  late Future<List<_OfflineReportedCase>> _future;
  final TextEditingController _searchController = TextEditingController();
  _RecordsFilter _filter = _RecordsFilter.all;

  static const String mgysdReportProgramUid = 'MGYSD_REPORT_EVENT_PROGRAM_UID';
  static const String mgysdReportStageUid = 'MGYSD_REPORT_STAGE_UID';

  static const String deClientsJson = 'DE_CLIENTS_JSON';
  static const String dePeopleInvolvedJson = 'DE_PEOPLE_INVOLVED_JSON';

  static const String deConcernReason = 'UJIrqEgPMn1';
  static const String deConcernReasonOther = 'UJIrqEgPMn1_OTHER';
  static const String deWhenHappened = 'DE_WHEN_HAPPENED';
  static const String deIncidentLocation = 'DE_INCIDENT_LOCATION';
  static const String deIncidentDescription = 'DE_INCIDENT_DESCRIPTION';

  static const String deFirstClientFirstName = 'MGYSD_CLIENT_FIRST_NAME';
  static const String deFirstClientLastName = 'MGYSD_CLIENT_LAST_NAME';
  static const String deFirstClientPhone = 'MGYSD_CLIENT_PHONE';
  static const String deFirstClientSex = 'MGYSD_CLIENT_SEX';
  static const String deFirstClientDistrict = 'MGYSD_CLIENT_DISTRICT';

  static const Map<String, String> concernLabels = {
    'PHYSICAL': 'Physical violence',
    'SEXUAL': 'Sexual violence',
    'SOCIO_ECON': 'Low socio-economic status',
    'ISSN_NISSA': 'Exclusion/inclusion error',
    'WORK_EXP': 'Work exploitation',
    'EMOTIONAL': 'Emotional violence',
    'CHILD_MARRIAGE': 'Child marriage',
    'FINANCIAL': 'Financial exploitation',
    'SPECIAL_NEEDS': 'Special needs',
    'GRIEVANCE': 'Grievance',
    'MENTAL_HEALTH': 'Mental health',
    'HEALTH': 'Health',
    'SUBSTANCE': 'Substance abuse',
    'SAFETY_SECURITY': 'Safety and security',
    'OTHER': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _future = _loadReportedCases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) {
      throw Exception('Offline DB not initialized');
    }
    return dbClient;
  }

  Future<Map<String, String>> _loadEventDataValuesAsMap(
      Database db,
      String eventId,
      ) async {
    final rows = await db.query(
      'event_data_value',
      columns: ['dataElement', 'value'],
      where: 'event = ?',
      whereArgs: [eventId],
    );

    final map = <String, String>{};
    for (final row in rows) {
      final dataElement = (row['dataElement'] ?? '').toString();
      final value = (row['value'] ?? '').toString();
      if (dataElement.isNotEmpty) {
        map[dataElement] = value;
      }
    }
    return map;
  }

  Future<Map<String, Map<String, String>>> _loadLinksByReportEvent(
      Database db,
      ) async {
    final rows = await db.query(
      'mgysd_report_intake_link',
      columns: ['reportEvent', 'tei', 'enrollment'],
    );

    final links = <String, Map<String, String>>{};
    for (final row in rows) {
      final reportEvent = (row['reportEvent'] ?? '').toString();
      if (reportEvent.isEmpty) continue;

      links[reportEvent] = {
        'tei': (row['tei'] ?? '').toString(),
        'enrollment': (row['enrollment'] ?? '').toString(),
      };
    }

    return links;
  }

  List<dynamic> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      return const [];
    } catch (_) {
      return const [];
    }
  }

  String _stringFromMap(dynamic item, String key) {
    if (item is Map) {
      return (item[key] ?? '').toString();
    }
    return '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _concernDisplay(String concernCodes, String otherText) {
    final codes = concernCodes
        .split(',')
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toList();

    final labels = codes.map((code) {
      if (code == 'OTHER' && otherText.trim().isNotEmpty) {
        return 'Other: ${otherText.trim()}';
      }
      return concernLabels[code] ?? code.replaceAll('_', ' ');
    }).toList();

    return labels.join(', ');
  }

  Future<List<_OfflineReportedCase>> _loadReportedCases() async {
    final db = await _db();
    final links = await _loadLinksByReportEvent(db);

    final eventRows = await db.query(
      'events',
      where: '(programStage = ?) OR (program = ?)',
      whereArgs: [mgysdReportStageUid, mgysdReportProgramUid],
      orderBy: 'eventDate DESC',
    );

    final list = <_OfflineReportedCase>[];

    for (final row in eventRows) {
      final dbRowId = (row['id'] ?? '').toString();
      final eventId = (row['event'] ?? '').toString();
      if (eventId.isEmpty) continue;

      final values = await _loadEventDataValuesAsMap(db, eventId);

      final clients = _decodeList(values[deClientsJson] ?? '');
      final people = _decodeList(values[dePeopleInvolvedJson] ?? '');
      final firstClient = clients.isNotEmpty ? clients.first : null;

      final concernCodes = values[deConcernReason] ?? '';
      final concernOther = values[deConcernReasonOther] ?? '';
      final link = links[eventId];

      list.add(
        _OfflineReportedCase(
          dbRowId: dbRowId,
          eventId: eventId,
          eventDate: (row['eventDate'] ?? '').toString(),
          program: (row['program'] ?? '').toString(),
          programStage: (row['programStage'] ?? '').toString(),
          clientFirstName: _firstNonEmpty([
            values[deFirstClientFirstName] ?? '',
            _stringFromMap(firstClient, 'firstName'),
          ]),
          clientLastName: _firstNonEmpty([
            values[deFirstClientLastName] ?? '',
            _stringFromMap(firstClient, 'lastName'),
          ]),
          clientPhone: _firstNonEmpty([
            values[deFirstClientPhone] ?? '',
            _stringFromMap(firstClient, 'phone'),
          ]),
          clientSex: _firstNonEmpty([
            values[deFirstClientSex] ?? '',
            _stringFromMap(firstClient, 'sex'),
          ]),
          clientDistrict: _firstNonEmpty([
            values[deFirstClientDistrict] ?? '',
            _stringFromMap(firstClient, 'district'),
          ]),
          concernReason: _concernDisplay(concernCodes, concernOther),
          concernReasonOther: concernOther,
          incidentDate: values[deWhenHappened] ?? '',
          incidentLocation: values[deIncidentLocation] ?? '',
          incidentDescription: values[deIncidentDescription] ?? '',
          clientsCount: clients.isEmpty ? 1 : clients.length,
          peopleInvolvedCount: people.length,
          isEnrolled: link != null,
          linkedTei: link?['tei'] ?? '',
          linkedEnrollment: link?['enrollment'] ?? '',
        ),
      );
    }

    return list;
  }

  Future<void> _refresh() async {
    final nextFuture = _loadReportedCases();
    if (!mounted) return;

    setState(() {
      _future = nextFuture;
    });

    await nextFuture;
  }

  List<_OfflineReportedCase> _applyFilter(List<_OfflineReportedCase> items) {
    final query = _searchController.text.trim().toLowerCase();

    Iterable<_OfflineReportedCase> filtered = items;

    switch (_filter) {
      case _RecordsFilter.reportedOnly:
        filtered = filtered.where((item) => !item.isEnrolled);
        break;
      case _RecordsFilter.enrolledOnly:
        filtered = filtered.where((item) => item.isEnrolled);
        break;
      case _RecordsFilter.all:
        break;
    }

    if (query.isNotEmpty) {
      filtered = filtered.where(
            (item) => item.searchableText.contains(query),
      );
    }

    return filtered.toList();
  }

  Future<void> _openEnrollForm(_OfflineReportedCase item) async {
    if (item.isEnrolled) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdNewCasePage(
          color: widget.color,
          reportedEventId: item.eventId,
          prefillClientFirstName: item.clientFirstName,
          prefillClientLastName: item.clientLastName,
          prefillClientPhone: item.clientPhone,
          prefillCaseType: item.concernReason,
          prefillIncidentDate:
          item.incidentDate.isNotEmpty ? item.incidentDate : item.eventDate,
        ),
      ),
    );

    await _refresh();
  }

  Widget _chip(
      String text, {
        Color? color,
        IconData? icon,
        bool strong = false,
      }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final c = color ?? Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(strong ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(strong ? 0.24 : 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: c,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _RecordsFilter value) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
      selectedColor: widget.color.withOpacity(0.16),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? widget.color : Colors.blueGrey,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? widget.color.withOpacity(0.35)
            : Colors.blueGrey.withOpacity(0.16),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _searchAndFilters({
    required int allCount,
    required int filteredCount,
    required int reportedCount,
    required int enrolledCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.blueGrey.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search reports by client, phone, district or concern',
              prefixIcon: Icon(Icons.search, color: widget.color),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('All $allCount', _RecordsFilter.all),
              _filterChip('Reported $reportedCount', _RecordsFilter.reportedOnly),
              _filterChip('Enrolled $enrolledCount', _RecordsFilter.enrolledOnly),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Showing $filteredCount of $allCount report${allCount == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        CircleAvatar(
          radius: 38,
          backgroundColor: widget.color.withOpacity(0.10),
          child: Icon(Icons.folder_open, color: widget.color, size: 36),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No reports found',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _recordCard(_OfflineReportedCase item) {
    final statusColor = item.isEnrolled ? Colors.green : widget.color;
    final statusText = item.isEnrolled ? 'Enrolled' : 'Reported';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(
                    item.isEnrolled
                        ? Icons.verified_user_outlined
                        : Icons.report_outlined,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _chip(statusText, color: statusColor, strong: true),
                          if (item.eventDate.isNotEmpty)
                            _chip(item.eventDate, icon: Icons.event_outlined),
                          if (item.clientsCount > 1)
                            _chip('${item.clientsCount} clients',
                                icon: Icons.groups_outlined),
                          if (item.peopleInvolvedCount > 0)
                            _chip('${item.peopleInvolvedCount} involved',
                                icon: Icons.people_outline),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.concernReason.isNotEmpty)
              Text(
                item.concernReason,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            if (item.incidentDescription.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.incidentDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.blueGrey,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.clientPhone.isNotEmpty)
                  _chip(item.clientPhone, icon: Icons.phone_outlined),
                if (item.clientDistrict.isNotEmpty)
                  _chip(item.clientDistrict, icon: Icons.place_outlined),
                if (item.clientSex.isNotEmpty)
                  _chip(item.clientSex, icon: Icons.person_outline),
                if (item.incidentLocation.isNotEmpty)
                  _chip(item.incidentLocation, icon: Icons.location_on_outlined),
              ],
            ),
            if (item.isEnrolled && item.linkedTei.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Linked TEI: ${item.linkedTei}',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: item.isEnrolled ? null : () => _openEnrollForm(item),
                icon: Icon(
                  item.isEnrolled
                      ? Icons.check_circle_outline
                      : Icons.how_to_reg_outlined,
                ),
                label: Text(item.isEnrolled ? 'Already Enrolled' : 'Open Intake'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: item.isEnrolled ? Colors.blueGrey : widget.color,
                  side: BorderSide(
                    color: item.isEnrolled
                        ? Colors.blueGrey.withOpacity(0.25)
                        : widget.color.withOpacity(0.45),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<_OfflineReportedCase>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 140),
                Center(child: CircularProgressIndicator()),
                SizedBox(height: 12),
                Center(
                  child: Text(
                    'Loading reported cases...',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.red.withOpacity(0.18)),
                  ),
                  child: Text(
                    'Failed to load MGYSD records:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          }

          final all = snapshot.data ?? <_OfflineReportedCase>[];
          final reportedCount = all.where((item) => !item.isEnrolled).length;
          final enrolledCount = all.where((item) => item.isEnrolled).length;
          final filtered = _applyFilter(all);

          if (all.isEmpty) {
            return _emptyState(
              'Submit a report first, then come back here to view reported cases.',
            );
          }

          if (filtered.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _searchAndFilters(
                  allCount: all.length,
                  filteredCount: 0,
                  reportedCount: reportedCount,
                  enrolledCount: enrolledCount,
                ),
                _emptyState('No reports match the selected filter or search.'),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _searchAndFilters(
                allCount: all.length,
                filteredCount: filtered.length,
                reportedCount: reportedCount,
                enrolledCount: enrolledCount,
              ),
              const SizedBox(height: 14),
              ...filtered.map(_recordCard),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
