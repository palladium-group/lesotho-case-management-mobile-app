import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/enrollment/pages/mgysd_new_case_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/enrollment/pages/mgysd_report_case_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:sqflite/sqflite.dart';

class MgysdReportingWorkspace extends StatefulWidget {
  const MgysdReportingWorkspace({
    Key? key,
    required this.color,
    this.refreshToken = 0,
  }) : super(key: key);

  final Color color;
  final int refreshToken;

  @override
  State<MgysdReportingWorkspace> createState() =>
      _MgysdReportingWorkspaceState();
}

class _ReportedCaseItem {
  const _ReportedCaseItem({
    required this.eventId,
    required this.eventDate,
    required this.syncStatus,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.sex,
    required this.district,
    required this.concern,
    required this.incidentDate,
    required this.incidentLocation,
    required this.description,
    required this.linkedTei,
    required this.linkedEnrollment,
  });

  final String eventId;
  final String eventDate;
  final String syncStatus;
  final String firstName;
  final String lastName;
  final String phone;
  final String sex;
  final String district;
  final String concern;
  final String incidentDate;
  final String incidentLocation;
  final String description;
  final String linkedTei;
  final String linkedEnrollment;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Unnamed reported client' : name;
  }

  bool get hasIntake =>
      linkedTei.trim().isNotEmpty || linkedEnrollment.trim().isNotEmpty;

  bool get isSynced {
    final value = syncStatus.toLowerCase();
    return value == 'synced' ||
        value == 'online' ||
        value == 'true' ||
        value == '1';
  }

  String get intakeLabel => hasIntake ? 'Intake completed' : 'Awaiting intake';

  String get searchableText => [
        displayName,
        phone,
        sex,
        district,
        concern,
        incidentDate,
        incidentLocation,
        description,
        intakeLabel,
      ].join(' ').toLowerCase();
}

class _MgysdReportingWorkspaceState
    extends State<MgysdReportingWorkspace> {
  final TextEditingController _searchController = TextEditingController();

  List<_ReportedCaseItem> _items = [];
  List<_ReportedCaseItem> _filtered = [];
  bool _loading = true;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MgysdReportingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _db() async {
    final db = await OfflineDbProvider().db;
    if (db == null) throw Exception('Offline database is not ready');
    return db;
  }

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, String>> _eventValues(
    Database db,
    String eventId,
  ) async {
    final map = <String, String>{};
    if (!await _tableExists(db, 'event_data_value')) return map;

    try {
      final rows = await db.query(
        'event_data_value',
        where: 'event = ?',
        whereArgs: [eventId],
      );

      for (final row in rows) {
        final key = (row['dataElement'] ?? '').toString();
        final value = (row['value'] ?? '').toString();
        if (key.isNotEmpty) map[key] = value;
      }
    } catch (_) {}

    return map;
  }

  String _first(Map<String, String> values, List<String> keys) {
    for (final key in keys) {
      final value = (values[key] ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<Map<String, String>> _linkedIntake(
    Database db,
    String reportEventId,
  ) async {
    if (!await _tableExists(db, 'mgysd_report_intake_link')) {
      return const {};
    }

    try {
      final columns = await db.rawQuery(
        'PRAGMA table_info(mgysd_report_intake_link)',
      );
      final names = columns
          .map((row) => (row['name'] ?? '').toString())
          .toSet();

      final reportColumn = names.contains('reportEventId')
          ? 'reportEventId'
          : names.contains('reportEvent')
              ? 'reportEvent'
              : '';

      if (reportColumn.isEmpty) return const {};

      final rows = await db.query(
        'mgysd_report_intake_link',
        where: '$reportColumn = ?',
        whereArgs: [reportEventId],
        orderBy: names.contains('createdAt') ? 'createdAt DESC' : null,
        limit: 1,
      );
      if (rows.isEmpty) return const {};
      return rows.first.map(
        (key, value) => MapEntry(key, (value ?? '').toString()),
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final db = await _db();
      if (!await _tableExists(db, 'events')) {
        if (mounted) {
          setState(() {
            _items = [];
            _filtered = [];
            _loading = false;
          });
        }
        return;
      }

      final rows = await db.query(
        'events',
        where: 'program = ?',
        whereArgs: [MgysdDhis2Uids.reportedCasesEventProgram],
        orderBy: 'eventDate DESC',
      );

      final result = <_ReportedCaseItem>[];

      for (final row in rows) {
        final eventId =
            (row['event'] ?? row['id'] ?? '').toString().trim();
        if (eventId.isEmpty) continue;

        final values = await _eventValues(db, eventId);
        final link = await _linkedIntake(db, eventId);

        Map<String, dynamic> payload = {};
        final payloadText =
            (values[MgysdDhis2Uids.deReportPayloadJson] ?? '').trim();
        if (payloadText.isNotEmpty) {
          try {
            final decoded = jsonDecode(payloadText);
            if (decoded is Map<String, dynamic>) payload = decoded;
          } catch (_) {}
        }

        Map<String, dynamic> firstClient = {};
        final clients = payload['clients'];
        if (clients is List && clients.isNotEmpty && clients.first is Map) {
          firstClient =
              Map<String, dynamic>.from(clients.first as Map);
        }

        final concerns = payload['concerns'] is Map
            ? Map<String, dynamic>.from(payload['concerns'] as Map)
            : <String, dynamic>{};

        result.add(
          _ReportedCaseItem(
            eventId: eventId,
            eventDate: (row['eventDate'] ?? '').toString(),
            syncStatus: (row['syncStatus'] ?? '').toString(),
            firstName: _first(values, [
              MgysdDhis2Uids.deFirstClientFirstName,
            ]).isNotEmpty
                ? _first(values, [MgysdDhis2Uids.deFirstClientFirstName])
                : (firstClient['firstName'] ?? '').toString(),
            lastName: _first(values, [
              MgysdDhis2Uids.deFirstClientLastName,
            ]).isNotEmpty
                ? _first(values, [MgysdDhis2Uids.deFirstClientLastName])
                : (firstClient['lastName'] ?? '').toString(),
            phone: _first(values, [
              MgysdDhis2Uids.deFirstClientPhone,
            ]).isNotEmpty
                ? _first(values, [MgysdDhis2Uids.deFirstClientPhone])
                : (firstClient['phone'] ?? '').toString(),
            sex: _first(values, [
              MgysdDhis2Uids.deFirstClientSex,
            ]).isNotEmpty
                ? _first(values, [MgysdDhis2Uids.deFirstClientSex])
                : (firstClient['sex'] ?? '').toString(),
            district: _first(values, [
              MgysdDhis2Uids.deFirstClientDistrict,
            ]).isNotEmpty
                ? _first(values, [MgysdDhis2Uids.deFirstClientDistrict])
                : (firstClient['district'] ?? '').toString(),
            concern: _first(values, const [
              'MGYSD_DE_CONCERN_REASON',
              'MGYSD_CONCERN_REASON',
            ]).isNotEmpty
                ? _first(values, const [
                    'MGYSD_DE_CONCERN_REASON',
                    'MGYSD_CONCERN_REASON',
                  ])
                : (concerns.values.isNotEmpty
                    ? concerns.values.first.toString()
                    : ''),
            incidentDate:
                (concerns['MGYSD_DE_WHEN_HAPPENED'] ??
                        concerns['incidentDate'] ??
                        '')
                    .toString(),
            incidentLocation:
                (concerns['MGYSD_DE_INCIDENT_LOCATION'] ??
                        concerns['incidentLocation'] ??
                        '')
                    .toString(),
            description:
                (concerns['MGYSD_DE_INCIDENT_DESCRIPTION'] ??
                        concerns['description'] ??
                        '')
                    .toString(),
            linkedTei: (link['teiId'] ??
                    link['tei'] ??
                    link['householdTei'] ??
                    link['trackedEntityInstance'] ??
                    '')
                .toString(),
            linkedEnrollment: (link['enrollmentId'] ??
                    link['enrollment'] ??
                    '')
                .toString(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _items = result;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load reported cases: $e')),
      );
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _items.where((item) {
      if (_filter == 'PENDING' && item.hasIntake) return false;
      if (_filter == 'INTAKE' && !item.hasIntake) return false;
      if (_filter == 'UNSYNCED' && item.isSynced) return false;
      if (query.isNotEmpty && !item.searchableText.contains(query)) {
        return false;
      }
      return true;
    }).toList();

    setState(() => _filtered = filtered);
  }

  Future<void> _openIntake(_ReportedCaseItem item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdNewCasePage(
          color: widget.color,
          reportedEventId: item.eventId,
          prefillClientFirstName: item.firstName,
          prefillClientLastName: item.lastName,
          prefillClientPhone: item.phone,
          prefillCaseType: item.concern,
          prefillIncidentDate:
              item.incidentDate.isEmpty ? item.eventDate : item.incidentDate,
        ),
      ),
    );

    if (saved == true && mounted) {
      // Give instant visual feedback while the database is re-read.
      final updated = _items.map((current) {
        if (current.eventId != item.eventId) return current;
        return _ReportedCaseItem(
          eventId: current.eventId,
          eventDate: current.eventDate,
          syncStatus: current.syncStatus,
          firstName: current.firstName,
          lastName: current.lastName,
          phone: current.phone,
          sex: current.sex,
          district: current.district,
          concern: current.concern,
          incidentDate: current.incidentDate,
          incidentLocation: current.incidentLocation,
          description: current.description,
          linkedTei: 'saved',
          linkedEnrollment: 'saved',
        );
      }).toList();
      setState(() => _items = updated);
      _applyFilters();
    }

    await _load();
  }

  void _showDetails(_ReportedCaseItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.intakeLabel,
                    style: TextStyle(
                      color: item.hasIntake ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _detail('Reported date', item.eventDate),
                  _detail('Phone', item.phone),
                  _detail('Sex', item.sex),
                  _detail('District', item.district),
                  _detail('Concern', item.concern),
                  _detail('Incident date', item.incidentDate),
                  _detail('Incident location', item.incidentLocation),
                  _detail('Description', item.description),
                  _detail(
                    'Synchronization',
                    item.isSynced ? 'Synced' : 'Waiting to sync',
                  ),
                  const SizedBox(height: 16),
                  if (!item.hasIntake)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openIntake(item);
                      },
                      icon: const Icon(Icons.assignment_ind_outlined),
                      label: const Text('Open Intake'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _detail(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }


  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final options = <Map<String, String>>[
          {'value': 'ALL', 'label': 'All reported cases'},
          {'value': 'PENDING', 'label': 'Awaiting intake'},
          {'value': 'INTAKE', 'label': 'Intake completed'},
          {'value': 'UNSYNCED', 'label': 'Unsynced records'},
        ];

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Filter intake records',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose which records should appear in the reporting workspace.',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12.3,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((option) {
                  final value = option['value']!;
                  final selected = _filter == value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? widget.color.withOpacity(0.08)
                          : const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected
                            ? widget.color.withOpacity(0.22)
                            : Colors.blueGrey.withOpacity(0.08),
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: value,
                      groupValue: _filter,
                      activeColor: widget.color,
                      title: Text(
                        option['label']!,
                        style: TextStyle(
                          color: selected ? widget.color : Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onChanged: (newValue) {
                        if (newValue == null) return;
                        Navigator.pop(sheetContext);
                        setState(() => _filter = newValue);
                        _applyFilters();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _activeFilterLabel() {
    switch (_filter) {
      case 'PENDING':
        return 'Awaiting intake';
      case 'INTAKE':
        return 'Intake completed';
      case 'UNSYNCED':
        return 'Unsynced';
      default:
        return 'All';
    }
  }

  Widget _caseCard(_ReportedCaseItem item) {
    final statusColor = item.hasIntake ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: statusColor.withOpacity(0.11),
                child: Icon(
                  item.hasIntake
                      ? Icons.assignment_turned_in_outlined
                      : Icons.campaign_outlined,
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
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (item.concern.isNotEmpty) item.concern,
                        if (item.district.isNotEmpty) item.district,
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _pill(item.intakeLabel, statusColor),
                        _pill(
                          item.isSynced ? 'Synced' : 'Unsynced',
                          item.isSynced ? Colors.blueGrey : Colors.deepOrange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              TextButton(
                onPressed: () => _showDetails(item),
                style: TextButton.styleFrom(
                  foregroundColor: widget.color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.2,
                  ),
                ),
                child: const Text('View report'),
              ),
              const SizedBox(width: 18),
              TextButton(
                onPressed: item.hasIntake ? null : () => _openIntake(item),
                style: TextButton.styleFrom(
                  foregroundColor: widget.color,
                  disabledForegroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.2,
                  ),
                ),
                child: Text(item.hasIntake ? 'Intake completed' : 'Open intake'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((item) => !item.hasIntake).length;

    return RefreshIndicator(
      color: widget.color,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.color, const Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Intake Queue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$pending waiting for intake • ${_items.length} total reports',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MgysdRecordCasePage(color: widget.color),
                        ),
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: 'Report new case',
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) {
                            setState(() {});
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search this device',
                            prefixIcon: Tooltip(
                              message:
                                  'Offline search: searches records stored on this device',
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: widget.color,
                                ),
                              ),
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? const Tooltip(
                                    message:
                                        'Online search will use the globe icon in a later update',
                                    child: Icon(
                                      Icons.public_outlined,
                                      color: Colors.blueGrey,
                                      size: 20,
                                    ),
                                  )
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                      _applyFilters();
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _openFilterSheet,
                              child: Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _filter == 'ALL'
                                        ? Colors.blueGrey.withOpacity(0.10)
                                        : widget.color.withOpacity(0.22),
                                  ),
                                ),
                                child: Icon(
                                  Icons.tune_outlined,
                                  color: _filter == 'ALL'
                                      ? Colors.blueGrey
                                      : widget.color,
                                ),
                              ),
                            ),
                          ),
                          if (_filter != 'ALL')
                            Positioned(
                              right: -3,
                              top: -3,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: widget.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (_filter != 'ALL') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Filter: ${_activeFilterLabel()}',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _empty(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _caseCard(_filtered[index]),
                childCount: _filtered.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: widget.color.withOpacity(0.09),
              child: Icon(
                Icons.campaign_outlined,
                color: widget.color,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No intake records found',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Reported cases remain here before and after intake has been completed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
