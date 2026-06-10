import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/app_state/mgysd_case_management_list_state/mgysd_case_management_list_state.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/case_shell/pages/mgysd_case_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

class MgysdCaseListPage extends StatefulWidget {
  const MgysdCaseListPage({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdCaseListPage> createState() => _MgysdCaseListPageState();
}

class _MgysdCaseListPageState extends State<MgysdCaseListPage> {
  final TextEditingController _searchController = TextEditingController();

  List<MgysdCase> _cases = [];
  List<MgysdCase> _filtered = [];
  bool _loading = true;

  static const String assessedHouseholdsProgramId =
      MgysdDhis2Uids.assessedHouseholdsProgram;
  static const String enrolledHouseholdsProgramId =
      MgysdDhis2Uids.enrolledHouseholdsProgram;

  static const String attFirstName = MgysdDhis2Uids.attFirstName;
  static const String attLastName = MgysdDhis2Uids.attLastName;
  static const String attPhone = MgysdDhis2Uids.attPhone;
  static const String attClientCategory = MgysdDhis2Uids.attClientCategory;
  static const String attSex = MgysdDhis2Uids.attSex;
  static const String attAge = MgysdDhis2Uids.attAge;

  static const String attHouseholdFileNumber =
      MgysdDhis2Uids.attHouseholdFileNumber;
  static const String attHouseholdDistrict =
      MgysdDhis2Uids.attHouseholdDistrict;
  static const String attHouseholdCommunityCouncil =
      MgysdDhis2Uids.attHouseholdCommunityCouncil;
  static const String attHouseholdVillage =
      MgysdDhis2Uids.attHouseholdVillage;

  static const String legacyAttPersonFirstName = 'ATTR_P_FIRSTNAME';
  static const String legacyAttPersonLastName = 'ATTR_P_LASTNAME';
  static const String legacyAttPersonPhone = 'ATTR_P_PHONE';

  @override
  void initState() {
    super.initState();
    _loadHouseholdCases();

    Future.microtask(() {
      Provider.of<MgysdCaseManagementListState>(context, listen: false)
          .refreshMgysdCasesNumber();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  Future<Map<String, String>> _loadTeiAttributes(
      Database db,
      String teiId,
      ) async {
    final rows = await db.query(
      'tracked_entity_instance_attribute',
      columns: ['attribute', 'value'],
      where: 'trackedEntityInstance = ?',
      whereArgs: [teiId],
    );

    final Map<String, String> map = {};
    for (final row in rows) {
      final att = (row['attribute'] ?? '').toString();
      final val = (row['value'] ?? '').toString();
      if (att.isNotEmpty) map[att] = val;
    }

    return map;
  }

  String _readFirstName(Map<String, String> attrs) {
    return attrs[attFirstName] ?? attrs[legacyAttPersonFirstName] ?? '';
  }

  String _readLastName(Map<String, String> attrs) {
    return attrs[attLastName] ?? attrs[legacyAttPersonLastName] ?? '';
  }

  String _readPhone(Map<String, String> attrs) {
    return attrs[attPhone] ?? attrs[legacyAttPersonPhone] ?? '';
  }

  String _prettyClientCategory(String value) {
    switch (value.toUpperCase()) {
      case 'CHILD':
        return 'Child';
      case 'ADULT_ELDERLY_PERSON':
        return 'Adult / Elderly';
      default:
        return value;
    }
  }

  Future<String?> _getPrimaryClientForHousehold(
      Database db,
      String householdTei,
      ) async {
    final primaryRows = await db.query(
      'mgysd_household_member',
      columns: ['memberTei'],
      where: 'householdTei = ? AND isPrimaryClient = ?',
      whereArgs: [householdTei, 'true'],
      limit: 1,
    );

    if (primaryRows.isNotEmpty) {
      final tei = (primaryRows.first['memberTei'] ?? '').toString().trim();
      if (tei.isNotEmpty) return tei;
    }

    final fallbackRows = await db.query(
      'mgysd_household_member',
      columns: ['memberTei'],
      where: 'householdTei = ? AND memberRole = ?',
      whereArgs: [householdTei, 'CLIENT'],
      limit: 1,
    );

    if (fallbackRows.isNotEmpty) {
      final tei = (fallbackRows.first['memberTei'] ?? '').toString().trim();
      if (tei.isNotEmpty) return tei;
    }

    return null;
  }

  Future<List<Map<String, Object?>>> _loadHouseholdEnrollmentRows(
      Database db,
      ) async {
    final rows = await db.query(
      'enrollment',
      where: 'program IN (?, ?)',
      whereArgs: [
        assessedHouseholdsProgramId,
        enrolledHouseholdsProgramId,
      ],
      orderBy: 'enrollmentDate DESC',
    );

    return rows;
  }

  Future<void> _loadHouseholdCases() async {
    setState(() => _loading = true);

    try {
      final db = await _db();
      final enrollmentRows = await _loadHouseholdEnrollmentRows(db);

      final Map<String, Map<String, Object?>> byHousehold = {};

      for (final row in enrollmentRows) {
        final householdTei =
        (row['trackedEntityInstance'] ?? '').toString().trim();
        if (householdTei.isEmpty) continue;

        final program = (row['program'] ?? '').toString().trim();

        final existing = byHousehold[householdTei];
        if (existing == null) {
          byHousehold[householdTei] = row;
        } else {
          final existingProgram =
          (existing['program'] ?? '').toString().trim();

          // Prefer the enrolled-household enrollment over the assessed-only
          // enrollment because it represents active case management.
          if (existingProgram != enrolledHouseholdsProgramId &&
              program == enrolledHouseholdsProgramId) {
            byHousehold[householdTei] = row;
          }
        }
      }

      final List<MgysdCase> list = [];

      for (final entry in byHousehold.entries) {
        final householdTei = entry.key;
        final row = entry.value;

        final enrollmentId = (row['enrollment'] ?? '').toString().trim();
        final program = (row['program'] ?? '').toString().trim();
        final enrollmentDate = (row['enrollmentDate'] ?? '').toString().trim();

        if (enrollmentId.isEmpty) continue;

        final householdAttrs = await _loadTeiAttributes(db, householdTei);

        final fileNumber =
        (householdAttrs[attHouseholdFileNumber] ?? '').trim();
        final district = (householdAttrs[attHouseholdDistrict] ?? '').trim();
        final communityCouncil =
        (householdAttrs[attHouseholdCommunityCouncil] ?? '').trim();
        final village = (householdAttrs[attHouseholdVillage] ?? '').trim();

        final clientTei = await _getPrimaryClientForHousehold(db, householdTei);
        String fullName = '(No primary client)';
        String phone = '';
        String extra = '';

        if (clientTei != null && clientTei.isNotEmpty) {
          final clientAttrs = await _loadTeiAttributes(db, clientTei);
          final firstName = _readFirstName(clientAttrs).trim();
          final lastName = _readLastName(clientAttrs).trim();
          phone = _readPhone(clientAttrs).trim();

          final category = _prettyClientCategory(
            (clientAttrs[attClientCategory] ?? '').trim(),
          );
          final sex = (clientAttrs[attSex] ?? '').trim();
          final age = (clientAttrs[attAge] ?? '').trim();

          fullName = ('$firstName $lastName').trim();
          if (fullName.isEmpty) fullName = '(No primary client)';

          extra = [
            if (category.isNotEmpty) category,
            if (sex.isNotEmpty) sex,
            if (age.isNotEmpty) '$age yrs',
          ].join(' • ');
        }

        final displayCaseNo = fileNumber.isNotEmpty ? fileNumber : enrollmentId;

        final status = program == enrolledHouseholdsProgramId
            ? 'ENROLLED'
            : 'ASSESSED';

        list.add(
          MgysdCase(
            id: enrollmentId,
            caseNo: displayCaseNo,
            fullName: extra.isEmpty ? fullName : '$fullName\n$extra',
            district: [
              district,
              communityCouncil,
              village,
            ].where((value) => value.trim().isNotEmpty).join(' • '),
            status: status,
            phone: phone,
            enrollmentDate: enrollmentDate,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _cases = list;
        _filtered = _applyFilter(list, _searchController.text);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cases = [];
        _filtered = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load household cases: $e')),
      );
    }
  }

  List<MgysdCase> _applyFilter(List<MgysdCase> source, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((c) {
      return c.caseNo.toLowerCase().contains(query) ||
          c.fullName.toLowerCase().contains(query) ||
          c.district.toLowerCase().contains(query) ||
          c.status.toLowerCase().contains(query) ||
          (c.phone ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _refresh() async {
    await _loadHouseholdCases();
    if (!mounted) return;
    Provider.of<MgysdCaseManagementListState>(context, listen: false)
        .refreshMgysdCasesNumber();
  }

  void _filter(String q) {
    setState(() {
      _filtered = _applyFilter(_cases, q);
    });
  }

  void _openCase(MgysdCase mgysdCase) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdCaseDetailPage(
          color: widget.color,
          mgysdCase: mgysdCase,
        ),
      ),
    ).then((_) => _refresh());
  }

  void _onAddCase() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use "Report Case" or "Enroll Client Case" workflow'),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ENROLLED':
        return 'Enrolled HH';
      case 'ASSESSED':
        return 'Assessed HH';
      case 'ACTIVE':
        return 'Open';
      case 'COMPLETED':
        return 'Closed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ENROLLED':
        return Colors.deepOrange;
      case 'ASSESSED':
        return Colors.blueGrey;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.redAccent;
      default:
        return widget.color;
    }
  }

  Widget _statusChip(String status) {
    final label = _statusLabel(status);
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: TextField(
        controller: _searchController,
        onChanged: _filter,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.search, color: widget.color),
          suffixIcon: _searchController.text.trim().isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
              _filter('');
            },
            icon: const Icon(Icons.close),
          )
              : null,
          hintText: 'Search households, clients, locations',
          hintStyle: const TextStyle(color: Colors.blueGrey),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.18)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.withOpacity(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: widget.color, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.8)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: widget.color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _buildHeaderSummary() {
    final assessed = _cases
        .where((item) => item.status.toUpperCase() == 'ASSESSED')
        .length;
    final enrolled = _cases
        .where((item) => item.status.toUpperCase() == 'ENROLLED')
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: widget.color.withOpacity(0.08),
        border: Border.all(color: widget.color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: widget.color.withOpacity(0.14),
                child: Icon(Icons.home_work_outlined, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MGYSD Household Case Management',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_filtered.length} household${_filtered.length == 1 ? '' : 's'} shown',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: Icon(Icons.refresh, color: widget.color),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryTile(
                label: 'Assessed',
                value: assessed.toString(),
                icon: Icons.fact_check_outlined,
              ),
              const SizedBox(width: 8),
              _summaryTile(
                label: 'Enrolled',
                value: enrolled.toString(),
                icon: Icons.verified_user_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Loading households...',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        CircleAvatar(
          radius: 34,
          backgroundColor: widget.color.withOpacity(0.10),
          child: Icon(
            Icons.home_work_outlined,
            size: 32,
            color: widget.color,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No assessed households found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Create an Intake and Initial Risk Assessment to register a household.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blueGrey,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaseCard(MgysdCase item) {
    final nameParts = item.fullName.split('\n');
    final name = nameParts.isNotEmpty ? nameParts.first : item.fullName;
    final sub = nameParts.length > 1 ? nameParts.sublist(1).join(' • ') : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Material(
        color: Colors.white,
        elevation: 1.2,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openCase(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: widget.color.withOpacity(0.12),
                  child: Icon(
                    Icons.home_outlined,
                    color: widget.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (sub.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          sub,
                          style: const TextStyle(
                            fontSize: 12.2,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'File / Household: ${item.caseNo}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statusChip(item.status),
                          if (item.district.trim().isNotEmpty)
                            _infoChip(Icons.place_outlined, item.district),
                          if ((item.phone ?? '').trim().isNotEmpty)
                            _infoChip(Icons.phone_outlined, item.phone!.trim()),
                          if ((item.enrollmentDate ?? '').trim().isNotEmpty)
                            _infoChip(
                              Icons.event_outlined,
                              item.enrollmentDate!.trim(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.blueGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.color,
        onPressed: _onAddCase,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            _buildSearchBox(),
            _buildHeaderSummary(),
            Expanded(
              child: _loading
                  ? _buildLoadingState()
                  : _filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 90, top: 4),
                itemCount: _filtered.length,
                itemBuilder: (_, index) {
                  return _buildCaseCard(_filtered[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
