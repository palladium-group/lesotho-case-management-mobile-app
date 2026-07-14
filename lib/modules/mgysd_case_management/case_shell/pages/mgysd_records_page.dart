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

enum _RecordsFilter { all, newCases, activeCases }
enum _RecordsSort { priority, newest, oldest, clientName }

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
    return full.isEmpty ? 'Unnamed client' : full;
  }

  bool get hasConcern => concernReason.trim().isNotEmpty;
  bool get hasIncidentNarrative => incidentDescription.trim().isNotEmpty;
  bool get hasPhone => clientPhone.trim().isNotEmpty;

  int get priorityScore {
    if (!isEnrolled) return 100;
    if (!hasPhone) return 35;
    if (!hasIncidentNarrative) return 25;
    return 10;
  }

  String get workStatusLabel {
    if (!isEnrolled) return 'New Case';
    if (!hasPhone) return 'Follow Up';
    if (!hasIncidentNarrative) return 'Review';
    return 'Active Case';
  }

  String get nextActionTitle {
    if (!isEnrolled) return 'Open Intake Assessment';
    if (!hasPhone) return 'Update Client Contact';
    if (!hasIncidentNarrative) return 'Review Report Narrative';
    return 'Continue Household Case';
  }

  String get nextActionSubtitle {
    if (!isEnrolled) {
      return 'This report must be converted into intake and initial risk assessment.';
    }
    if (!hasPhone) {
      return 'Client contact details are missing and should be verified.';
    }
    if (!hasIncidentNarrative) {
      return 'The incident description is limited. Confirm details during follow-up.';
    }
    return 'Use the household case for investigation, care planning and services.';
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
      isEnrolled ? 'active enrolled household case' : 'new case reported intake assessment',
      nextActionTitle,
      workStatusLabel,
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
      case _RecordsFilter.newCases:
        filtered = filtered.where((item) => !item.isEnrolled);
        break;
      case _RecordsFilter.activeCases:
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
      case _RecordsSort.newest:
        list.sort((a, b) => b.eventDate.compareTo(a.eventDate));
        break;
      case _RecordsSort.priority:
      default:
        list.sort((a, b) {
          final score = b.priorityScore.compareTo(a.priorityScore);
          if (score != 0) return score;
          return b.eventDate.compareTo(a.eventDate);
        });
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

  Color _statusColor(_OfflineReportedCase item) {
    if (!item.isEnrolled) return Colors.redAccent;
    if (!item.hasPhone) return Colors.deepOrange;
    if (!item.hasIncidentNarrative) return Colors.amber.shade800;
    return Colors.green;
  }

  IconData _statusIcon(_OfflineReportedCase item) {
    if (!item.isEnrolled) return Icons.priority_high_rounded;
    if (!item.hasPhone) return Icons.phone_disabled_outlined;
    if (!item.hasIncidentNarrative) return Icons.notes_outlined;
    return Icons.check_circle_outline;
  }

  String _primaryConcern(_OfflineReportedCase item) {
    final concern = item.concernReason.trim();
    if (concern.isEmpty) return 'Concern not captured';
    return concern.split(',').first.trim();
  }

  String _dateForList(_OfflineReportedCase item) {
    if (item.incidentDate.trim().isNotEmpty) return item.incidentDate.trim();
    if (item.eventDate.trim().isNotEmpty) return item.eventDate.trim();
    return 'Date not captured';
  }

  String _listMeta(_OfflineReportedCase item) {
    final parts = <String>[];
    if (item.clientDistrict.trim().isNotEmpty) parts.add(item.clientDistrict.trim());
    parts.add(_dateForList(item));
    return parts.join(' • ');
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
      default:
        return 'Priority';
    }
  }

  int _activeFilterCount() {
    int count = 0;
    if (_filter != _RecordsFilter.all) count++;
    if (_sort != _RecordsSort.priority) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  void _showRecordDetails(_OfflineReportedCase item) {
    final statusColor = _statusColor(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
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
                        radius: 26,
                        backgroundColor: statusColor.withOpacity(0.12),
                        child: Icon(_statusIcon(item), color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.workStatusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailSection(
                    title: 'Case Summary',
                    icon: Icons.article_outlined,
                    children: [
                      _detailRow('Concern', item.concernReason),
                      _detailRow('Report Date', item.eventDate),
                      _detailRow('Incident Date', item.incidentDate),
                      _detailRow('Location', item.incidentLocation),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailSection(
                    title: 'Client Information',
                    icon: Icons.person_outline,
                    children: [
                      _detailRow('Name', item.displayName),
                      _detailRow('Phone', item.clientPhone),
                      _detailRow('Sex', item.clientSex),
                      _detailRow('District', item.clientDistrict),
                      _detailRow('Clients', item.clientsCount.toString()),
                      _detailRow('People involved', item.peopleInvolvedCount.toString()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailSection(
                    title: 'Narrative',
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
                      title: 'Linked Household Case',
                      icon: Icons.link_outlined,
                      children: [
                        _detailRow('Linked TEI', item.linkedTei),
                        _detailRow('Enrollment', item.linkedEnrollment),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
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
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        item.isEnrolled ? 'Already Active' : 'Open Intake Assessment',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.blueGrey.withOpacity(0.18),
                        disabledForegroundColor: Colors.blueGrey,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
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
            width: 116,
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

  Widget _statusPill(_OfflineReportedCase item) {
    final color = _statusColor(item);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(item), color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            item.workStatusLabel,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _RecordsFilter value) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: widget.color.withOpacity(0.16),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? widget.color : Colors.blueGrey,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? widget.color.withOpacity(0.35)
            : Colors.blueGrey.withOpacity(0.16),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _searchAndFilters({
    required int allCount,
    required int filteredCount,
    required int newCount,
    required int activeCount,
    required int followUpCount,
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Case Work Queue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      newCount > 0
                          ? '$newCount case${newCount == 1 ? '' : 's'} require assessment'
                          : 'No new case is waiting for assessment',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: Icon(Icons.refresh_rounded, color: widget.color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat(label: 'New', value: newCount, color: Colors.redAccent),
              const SizedBox(width: 8),
              _miniStat(label: 'Follow Up', value: followUpCount, color: Colors.deepOrange),
              const SizedBox(width: 8),
              _miniStat(label: 'Active', value: activeCount, color: Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by name, phone, district or concern',
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
                  Icon(Icons.tune_rounded, color: widget.color, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeFilters == 0
                          ? 'Filters hidden • Sorted by ${_sortLabel()}'
                          : '$activeFilters active • Sorted by ${_sortLabel()}',
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
                      _filterChip('New $newCount', _RecordsFilter.newCases),
                      _filterChip('Active $activeCount', _RecordsFilter.activeCases),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blueGrey.withOpacity(0.14)),
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
            'Showing $filteredCount of $allCount case${allCount == 1 ? '' : 's'}',
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

  Widget _emptyState(String title, String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        CircleAvatar(
          radius: 38,
          backgroundColor: widget.color.withOpacity(0.10),
          child: Icon(Icons.task_alt_rounded, color: widget.color, size: 36),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
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
    final statusColor = _statusColor(item);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(item.isEnrolled ? 0.03 : 0.055),
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
                  radius: 23,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(_statusIcon(item), color: statusColor),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusPill(item),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _primaryConcern(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _listMeta(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRecordDetails(item),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.color,
                      side: BorderSide(color: widget.color.withOpacity(0.28)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: item.isEnrolled
                        ? null
                        : () async => _openEnrollForm(item),
                    icon: Icon(
                      item.isEnrolled
                          ? Icons.lock_outline
                          : Icons.assignment_turned_in_outlined,
                      size: 18,
                    ),
                    label: Text(item.isEnrolled ? 'Active Case' : 'Open Intake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.blueGrey.withOpacity(0.16),
                      disabledForegroundColor: Colors.blueGrey,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
            'Loading case work queue...',
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
          final newCount = all.where((item) => !item.isEnrolled).length;
          final activeCount = all.where((item) => item.isEnrolled).length;
          final followUpCount = all
              .where(
                (item) => item.isEnrolled &&
                (!item.hasPhone || !item.hasIncidentNarrative),
          )
              .length;
          final filtered = _applyFilter(all);

          if (all.isEmpty) {
            return _emptyState(
              'No Cases Requiring Attention',
              'Submit a case report first, then return here to continue intake and assessment.',
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _searchAndFilters(
                allCount: all.length,
                filteredCount: filtered.length,
                newCount: newCount,
                activeCount: activeCount,
                followUpCount: followUpCount,
              ),
              if (filtered.isEmpty)
                _emptyState(
                  'No Matching Cases',
                  'No case matches the selected search or filter.',
                )
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
