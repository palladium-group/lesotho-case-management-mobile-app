import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/enrollment/pages/mgysd_new_case_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
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
enum _RecordsSort { newest, oldest, clientName, priority }

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

  String get statusLabel => isEnrolled ? 'Enrolled' : 'Reported only';

  bool get hasConcern => concernReason.trim().isNotEmpty;
  bool get hasIncidentNarrative => incidentDescription.trim().isNotEmpty;
  bool get hasPhone => clientPhone.trim().isNotEmpty;

  int get priorityScore {
    if (!isEnrolled) return 100;
    if (!hasPhone) return 35;
    if (!hasIncidentNarrative) return 25;
    return 10;
  }

  String get nextActionTitle {
    if (!isEnrolled) return 'Open intake and assess household';
    if (!hasPhone) return 'Review client contact details';
    if (!hasIncidentNarrative) return 'Review report narrative';
    return 'Report already linked to household case';
  }

  String get nextActionSubtitle {
    if (!isEnrolled) {
      return 'This report has not yet been converted into Intake and Initial Risk Assessment.';
    }
    if (!hasPhone) {
      return 'The primary client has no phone number captured in the report.';
    }
    if (!hasIncidentNarrative) {
      return 'The report has limited incident description. Verify details during follow-up.';
    }
    return 'Use the household case record for investigation, care planning and services.';
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
      isEnrolled ? 'enrolled' : 'reported only not enrolled',
      nextActionTitle,
    ].join(' ').toLowerCase();
  }
}

class _MgysdRecordsPageState extends State<MgysdRecordsPage> {
  late Future<List<_OfflineReportedCase>> _future;
  final TextEditingController _searchController = TextEditingController();

  _RecordsFilter _filter = _RecordsFilter.all;
  _RecordsSort _sort = _RecordsSort.priority;
  bool _showFilters = false;

  static const String mgysdReportProgramUid =
      MgysdDhis2Uids.reportedCasesEventProgram;
  static const String mgysdReportStageUid =
      MgysdDhis2Uids.reportedCasesProgramStage;

  static const String deClientsJson = MgysdDhis2Uids.deClientsJson;
  static const String dePeopleInvolvedJson =
      MgysdDhis2Uids.dePeopleInvolvedJson;

  static const String deConcernReason = MgysdDhis2Uids.deConcernReason;
  static const String deConcernReasonOther =
      MgysdDhis2Uids.deConcernReasonOther;
  static const String deWhenHappened = MgysdDhis2Uids.deWhenHappened;
  static const String deIncidentLocation = MgysdDhis2Uids.deIncidentLocation;
  static const String deIncidentDescription =
      MgysdDhis2Uids.deIncidentDescription;

  static const String deFirstClientFirstName =
      MgysdDhis2Uids.deFirstClientFirstName;
  static const String deFirstClientLastName =
      MgysdDhis2Uids.deFirstClientLastName;
  static const String deFirstClientPhone = MgysdDhis2Uids.deFirstClientPhone;
  static const String deFirstClientSex = MgysdDhis2Uids.deFirstClientSex;
  static const String deFirstClientDistrict =
      MgysdDhis2Uids.deFirstClientDistrict;

  static const Map<String, String> concernLabels = {
    'PHYSICAL': 'Physical violence',
    'SEXUAL': 'Sexual violence',
    'SOCIO_ECON': 'Low socio-economic status',
    'ISSN_NISSA': 'Exclusion / inclusion error',
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
    if (!await _tableExists(db, 'mgysd_report_intake_link')) {
      return <String, Map<String, String>>{};
    }

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
      filtered = filtered.where((item) => item.searchableText.contains(query));
    }

    final list = filtered.toList();

    switch (_sort) {
      case _RecordsSort.oldest:
        list.sort((a, b) => a.eventDate.compareTo(b.eventDate));
        break;
      case _RecordsSort.clientName:
        list.sort(
              (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        break;
      case _RecordsSort.priority:
        list.sort((a, b) {
          final score = b.priorityScore.compareTo(a.priorityScore);
          if (score != 0) return score;
          return b.eventDate.compareTo(a.eventDate);
        });
        break;
      case _RecordsSort.newest:
      default:
        list.sort((a, b) => b.eventDate.compareTo(a.eventDate));
        break;
    }

    return list;
  }

  Future<void> _openEnrollForm(_OfflineReportedCase item) async {
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

  void _showRecordDetails(_OfflineReportedCase item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F9FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: (item.isEnrolled ? Colors.green : widget.color)
                            .withOpacity(0.12),
                        child: Icon(
                          item.isEnrolled
                              ? Icons.verified_user_outlined
                              : Icons.report_outlined,
                          color: item.isEnrolled ? Colors.green : widget.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _decisionBox(item),
                  const SizedBox(height: 14),
                  _detailSection(
                    title: 'Report Summary',
                    icon: Icons.article_outlined,
                    children: [
                      _detailRow('Status', item.statusLabel),
                      _detailRow('Report Date', item.eventDate),
                      _detailRow('Incident Date', item.incidentDate),
                      _detailRow('Concern', item.concernReason),
                      _detailRow('Incident Location', item.incidentLocation),
                      _detailRow('Report Event', item.eventId),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailSection(
                    title: 'Client Details',
                    icon: Icons.person_outline,
                    children: [
                      _detailRow('Client Name', item.displayName),
                      _detailRow('Phone', item.clientPhone),
                      _detailRow('Sex', item.clientSex),
                      _detailRow('District', item.clientDistrict),
                      _detailRow('Clients Captured', item.clientsCount.toString()),
                      _detailRow(
                        'People Involved',
                        item.peopleInvolvedCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailSection(
                    title: 'Incident Description',
                    icon: Icons.notes_outlined,
                    children: [
                      Text(
                        item.incidentDescription.trim().isEmpty
                            ? 'No incident description captured.'
                            : item.incidentDescription.trim(),
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (item.isEnrolled) ...[
                    const SizedBox(height: 12),
                    _detailSection(
                      title: 'Linked Intake / Household',
                      icon: Icons.link_outlined,
                      children: [
                        _detailRow('Linked TEI', item.linkedTei),
                        _detailRow('Linked Enrollment', item.linkedEnrollment),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: item.isEnrolled
                              ? null
                              : () async {
                            Navigator.pop(context);
                            await _openEnrollForm(item);
                          },
                          icon: Icon(
                            item.isEnrolled
                                ? Icons.check_circle_outline
                                : Icons.edit_outlined,
                          ),
                          label: Text(
                            item.isEnrolled ? 'Already Enrolled' : 'Edit / Intake',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                            Colors.blueGrey.withOpacity(0.18),
                            disabledForegroundColor: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: widget.color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final v = value.trim().isEmpty ? 'Not captured' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: value.trim().isEmpty ? Colors.blueGrey : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
                fontWeight: FontWeight.w800,
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
        setState(() => _filter = value);
      },
      selectedColor: widget.color.withOpacity(0.16),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? widget.color : Colors.blueGrey,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? widget.color.withOpacity(0.35)
            : Colors.blueGrey.withOpacity(0.16),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headerMessage({
    required int reportedCount,
    required int enrolledCount,
  }) {
    if (reportedCount > 0) {
      return '$reportedCount reported case${reportedCount == 1 ? '' : 's'} still need Intake and Initial Risk Assessment.';
    }
    if (enrolledCount > 0) {
      return 'All visible reports have been converted into household cases.';
    }
    return 'No report records are available yet.';
  }

  int _activeFilterCount() {
    int count = 0;
    if (_filter != _RecordsFilter.all) count++;
    if (_sort != _RecordsSort.priority) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  String _sortLabel() {
    switch (_sort) {
      case _RecordsSort.newest:
        return 'Newest';
      case _RecordsSort.oldest:
        return 'Oldest';
      case _RecordsSort.clientName:
        return 'Client name';
      case _RecordsSort.priority:
        return 'Priority';
    }
  }

  Widget _searchAndFilters({
    required int allCount,
    required int filteredCount,
    required int reportedCount,
    required int enrolledCount,
  }) {
    final activeFilters = _activeFilterCount();

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
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.color.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: widget.color.withOpacity(0.12),
                      child: Icon(
                        Icons.support_agent_outlined,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Records Decision Support',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _headerMessage(
                              reportedCount: reportedCount,
                              enrolledCount: enrolledCount,
                            ),
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12.4,
                              height: 1.28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    _summaryTile(
                      label: 'Reports',
                      value: allCount.toString(),
                      icon: Icons.assignment_outlined,
                      color: widget.color,
                    ),
                    const SizedBox(width: 8),
                    _summaryTile(
                      label: 'Need Intake',
                      value: reportedCount.toString(),
                      icon: Icons.priority_high_outlined,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(width: 8),
                    _summaryTile(
                      label: 'Enrolled',
                      value: enrolledCount.toString(),
                      icon: Icons.verified_user_outlined,
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_outlined, color: widget.color, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeFilters == 0
                          ? 'Filters hidden • Sorted by ${_sortLabel()}'
                          : '$activeFilters active filter${activeFilters == 1 ? '' : 's'} • ${_sortLabel()}',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (activeFilters > 0)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        _filter = _RecordsFilter.all;
                        _sort = _RecordsSort.priority;
                        setState(() {});
                      },
                      child: const Text('Clear'),
                    ),
                  Icon(
                    _showFilters
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip('All $allCount', _RecordsFilter.all),
                      _filterChip(
                        'Need Intake $reportedCount',
                        _RecordsFilter.reportedOnly,
                      ),
                      _filterChip(
                        'Enrolled $enrolledCount',
                        _RecordsFilter.enrolledOnly,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.blueGrey.withOpacity(0.14),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_RecordsSort>(
                        value: _sort,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: const [
                          DropdownMenuItem(
                            value: _RecordsSort.priority,
                            child: Text('Sort by priority'),
                          ),
                          DropdownMenuItem(
                            value: _RecordsSort.newest,
                            child: Text('Sort by newest'),
                          ),
                          DropdownMenuItem(
                            value: _RecordsSort.oldest,
                            child: Text('Sort by oldest'),
                          ),
                          DropdownMenuItem(
                            value: _RecordsSort.clientName,
                            child: Text('Sort by client name'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
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

  Widget _decisionBox(_OfflineReportedCase item) {
    final color = item.isEnrolled ? Colors.green : Colors.deepOrange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nextActionTitle,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.nextActionSubtitle,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                    fontSize: 12.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(_OfflineReportedCase item) {
    final statusColor = item.isEnrolled ? Colors.green : widget.color;
    final statusText = item.isEnrolled ? 'Enrolled' : 'Need Intake';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(item.isEnrolled ? 0.03 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showRecordDetails(item),
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
                              _chip(
                                '${item.clientsCount} clients',
                                icon: Icons.groups_outlined,
                              ),
                            if (item.peopleInvolvedCount > 0)
                              _chip(
                                '${item.peopleInvolvedCount} involved',
                                icon: Icons.people_outline,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (value) async {
                      if (value == 'view') {
                        _showRecordDetails(item);
                      }
                      if (value == 'edit') {
                        await _openEnrollForm(item);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined),
                            SizedBox(width: 10),
                            Text('View details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        enabled: !item.isEnrolled,
                        child: Row(
                          children: [
                            Icon(
                              item.isEnrolled
                                  ? Icons.lock_outline
                                  : Icons.edit_outlined,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item.isEnrolled
                                  ? 'Already enrolled'
                                  : 'Edit / open intake',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (item.concernReason.isNotEmpty)
                Text(
                  item.concernReason,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
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
                    fontWeight: FontWeight.w500,
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
                    _chip(item.incidentLocation,
                        icon: Icons.location_on_outlined),
                ],
              ),
              const SizedBox(height: 11),
              _decisionBox(item),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingState() {
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

  Widget _errorState(Object error) {
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
            'Failed to load MGYSD records:\n$error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
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
            return _loadingState();
          }

          if (snapshot.hasError) {
            return _errorState(snapshot.error!);
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

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _searchAndFilters(
                allCount: all.length,
                filteredCount: filtered.length,
                reportedCount: reportedCount,
                enrolledCount: enrolledCount,
              ),
              if (filtered.isEmpty)
                _emptyState('No reports match the selected filter or search.')
              else ...[
                const SizedBox(height: 14),
                ...filtered.map(_recordCard),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}
