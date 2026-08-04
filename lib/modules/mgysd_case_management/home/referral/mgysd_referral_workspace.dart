import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/pages/mgysd_repeatable_stage_list_page.dart';
import 'package:sqflite/sqflite.dart';

class MgysdReferralWorkspace extends StatefulWidget {
  const MgysdReferralWorkspace({
    Key? key,
    required this.color,
  }) : super(key: key);

  final Color color;

  @override
  State<MgysdReferralWorkspace> createState() =>
      _MgysdReferralWorkspaceState();
}

class _ReferralMember {
  const _ReferralMember({
    required this.tei,
    required this.enrollment,
    required this.name,
    required this.role,
    required this.sex,
    required this.age,
    required this.isPrimary,
    required this.referralCount,
  });

  final String tei;
  final String enrollment;
  final String name;
  final String role;
  final String sex;
  final String age;
  final bool isPrimary;
  final int referralCount;
}

class _ReferralHousehold {
  const _ReferralHousehold({
    required this.enrollmentId,
    required this.householdTei,
    required this.fileNumber,
    required this.clientName,
    required this.location,
    required this.enrollmentDate,
    required this.householdReferralCount,
    required this.members,
  });

  final String enrollmentId;
  final String householdTei;
  final String fileNumber;
  final String clientName;
  final String location;
  final String enrollmentDate;
  final int householdReferralCount;
  final List<_ReferralMember> members;

  int get totalReferrals =>
      householdReferralCount +
          members.fold<int>(0, (total, member) => total + member.referralCount);

  String get searchableText => [
    fileNumber,
    clientName,
    location,
    ...members.map((member) => '${member.name} ${member.role}'),
  ].join(' ').toLowerCase();
}

class _MgysdReferralWorkspaceState extends State<MgysdReferralWorkspace> {
  final TextEditingController _searchController = TextEditingController();

  List<_ReferralHousehold> _items = [];
  List<_ReferralHousehold> _filtered = [];
  bool _loading = true;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<Map<String, String>> _attributes(Database db, String tei) async {
    final result = <String, String>{};
    if (!await _tableExists(db, 'tracked_entity_instance_attribute')) {
      return result;
    }

    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        where: 'trackedEntityInstance = ?',
        whereArgs: [tei],
      );
      for (final row in rows) {
        final key = '${row['attribute'] ?? ''}'.trim();
        final value = '${row['value'] ?? ''}'.trim();
        if (key.isNotEmpty) result[key] = value;
      }
    } catch (_) {}
    return result;
  }

  String _first(Map<String, String> values, List<String> keys) {
    for (final key in keys) {
      final value = (values[key] ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _name(Map<String, String> attrs, String fallback) {
    final first = _first(attrs, [
      MgysdDhis2Uids.attFirstName,
      'ATTR_P_FIRSTNAME',
      'firstName',
    ]);
    final last = _first(attrs, [
      MgysdDhis2Uids.attLastName,
      'ATTR_P_LASTNAME',
      'lastName',
    ]);
    final value = '$first $last'.trim();
    return value.isEmpty ? fallback : value;
  }

  Future<String> _memberEnrollment(Database db, String tei) async {
    try {
      final rows = await db.query(
        'enrollment',
        where: 'trackedEntityInstance = ? AND program = ?',
        whereArgs: [tei, MgysdDhis2Uids.familyMemberTrackerProgram],
        orderBy: 'enrollmentDate DESC',
        limit: 1,
      );
      if (rows.isEmpty) return '';
      return '${rows.first['enrollment'] ?? rows.first['id'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  Future<int> _eventCount(
      Database db, {
        required String tei,
        required String stage,
      }) async {
    if (stage == MgysdDhis2Uids.referralStage &&
        await _tableExists(db, 'mgysd_referral')) {
      try {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM mgysd_referral '
              'WHERE householdTei = ?',
          [tei],
        );
        final count = int.tryParse('${rows.first['c'] ?? 0}') ?? 0;
        if (count > 0) return count;
      } catch (_) {}
    }

    if (!await _tableExists(db, 'events')) return 0;
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM events '
            'WHERE trackedEntityInstance = ? AND programStage = ?',
        [tei, stage],
      );
      return int.tryParse('${rows.first['c'] ?? 0}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> _primaryClientTei(Database db, String householdTei) async {
    if (!await _tableExists(db, 'mgysd_household_member')) return null;
    try {
      var rows = await db.query(
        'mgysd_household_member',
        where: 'householdTei = ? AND isPrimaryClient = ?',
        whereArgs: [householdTei, 'true'],
        limit: 1,
      );
      if (rows.isEmpty) {
        rows = await db.query(
          'mgysd_household_member',
          where: 'householdTei = ? AND memberRole = ?',
          whereArgs: [householdTei, 'CLIENT'],
          limit: 1,
        );
      }
      if (rows.isEmpty) return null;
      return '${rows.first['memberTei'] ?? ''}';
    } catch (_) {
      return null;
    }
  }

  Future<List<_ReferralMember>> _members(
      Database db,
      String householdTei,
      ) async {
    if (!await _tableExists(db, 'mgysd_household_member')) return [];

    final result = <_ReferralMember>[];
    try {
      final rows = await db.query(
        'mgysd_household_member',
        where: 'householdTei = ?',
        whereArgs: [householdTei],
      );

      for (final row in rows) {
        final tei = '${row['memberTei'] ?? ''}'.trim();
        if (tei.isEmpty) continue;

        final attrs = await _attributes(db, tei);
        final role = '${row['memberRole'] ?? 'MEMBER'}'
            .replaceAll('_', ' ')
            .trim();

        result.add(
          _ReferralMember(
            tei: tei,
            enrollment: await _memberEnrollment(db, tei),
            name: _name(attrs, role),
            role: role,
            sex: _first(attrs, [MgysdDhis2Uids.attSex, 'sex']),
            age: _first(attrs, [MgysdDhis2Uids.attAge, 'age']),
            isPrimary:
            '${row['isPrimaryClient'] ?? ''}'.toLowerCase() == 'true',
            referralCount: await _eventCount(
              db,
              tei: tei,
              stage: MgysdDhis2Uids.familyReferralStage,
            ),
          ),
        );
      }
    } catch (_) {}

    result.sort((a, b) {
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      return a.name.compareTo(b.name);
    });
    return result;
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final db = await _db();
      final rows = await db.query(
        'enrollment',
        where: 'program = ?',
        whereArgs: [MgysdDhis2Uids.enrolledHouseholdsProgram],
        orderBy: 'enrollmentDate DESC',
      );

      final unique = <String, Map<String, Object?>>{};
      for (final row in rows) {
        final tei = '${row['trackedEntityInstance'] ?? ''}'.trim();
        if (tei.isNotEmpty) unique.putIfAbsent(tei, () => row);
      }

      final result = <_ReferralHousehold>[];
      for (final entry in unique.entries) {
        final householdTei = entry.key;
        final enrollment = entry.value;
        final hhAttrs = await _attributes(db, householdTei);
        final primaryTei = await _primaryClientTei(db, householdTei);
        final clientAttrs =
        primaryTei == null ? <String, String>{} : await _attributes(db, primaryTei);

        final fileNo = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdFileNumber,
          'ATTR_HH_FILE_NUMBER',
        ]);
        final district = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdDistrict,
          'district',
        ]);
        final council = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdCommunityCouncil,
          'communityCouncil',
        ]);
        final village = _first(hhAttrs, [
          MgysdDhis2Uids.attHouseholdVillage,
          'village',
        ]);

        result.add(
          _ReferralHousehold(
            enrollmentId:
            '${enrollment['enrollment'] ?? enrollment['id'] ?? ''}',
            householdTei: householdTei,
            fileNumber: fileNo.isEmpty ? householdTei : fileNo,
            clientName: _name(clientAttrs, 'Household client'),
            location: [district, council, village]
                .where((value) => value.isNotEmpty)
                .join(' • '),
            enrollmentDate: '${enrollment['enrollmentDate'] ?? ''}',
            householdReferralCount: await _eventCount(
              db,
              tei: householdTei,
              stage: MgysdDhis2Uids.referralStage,
            ),
            members: await _members(db, householdTei),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _items = result;
        _loading = false;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load referrals: $error')),
      );
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _items.where((item) {
        if (_filter == 'WITH' && item.totalReferrals == 0) return false;
        if (_filter == 'NONE' && item.totalReferrals > 0) return false;
        return query.isEmpty || item.searchableText.contains(query);
      }).toList();
    });
  }

  MgysdCase _case(_ReferralHousehold household) {
    return MgysdCase(
      id: household.enrollmentId,
      caseNo: household.fileNumber,
      fullName: household.clientName,
      district: household.location,
      status: 'ENROLLED',
      enrollmentDate: household.enrollmentDate,
    );
  }

  Future<void> _openHouseholdReferrals(_ReferralHousehold household) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdRepeatableStageListPage(
          color: widget.color,
          parentCase: _case(household),
          stageTitle: 'Household Referrals',
          tableName: 'mgysd_referral',
          stageKey: 'referral',
          programStage: MgysdDhis2Uids.referralStage,
          icon: Icons.handshake_outlined,
          trackedEntityInstance: household.householdTei,
          enrollment: household.enrollmentId,
          householdTei: household.householdTei,
          householdName: household.fileNumber,
          clientName: household.clientName,
          subjectName: household.clientName,
          subjectRole: 'HOUSEHOLD',
        ),
      ),
    );
    await _load();
  }

  Future<void> _openMemberReferrals(
      _ReferralHousehold household,
      _ReferralMember member,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdRepeatableStageListPage(
          color: widget.color,
          parentCase: _case(household),
          stageTitle: '${member.name} Referrals',
          tableName: 'mgysd_referral',
          stageKey: 'referral',
          programStage: MgysdDhis2Uids.familyReferralStage,
          icon: Icons.handshake_outlined,
          trackedEntityInstance: member.tei,
          enrollment: member.enrollment,
          householdTei: household.householdTei,
          householdName: household.fileNumber,
          clientName: household.clientName,
          subjectName: member.name,
          subjectRole: member.role,
          memberTei: member.tei,
          memberName: member.name,
          memberRole: member.role,
        ),
      ),
    );
    await _load();
  }

  void _openFilterSheet() {
    final options = [
      {'value': 'ALL', 'label': 'All enrolled households'},
      {'value': 'WITH', 'label': 'Referrals recorded'},
      {'value': 'NONE', 'label': 'No referrals recorded'},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
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
                  'Filter referrals',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 10),
              ...options.map((option) {
                final selected = _filter == option['value'];
                return RadioListTile<String>(
                  value: option['value']!,
                  groupValue: _filter,
                  activeColor: widget.color,
                  title: Text(
                    option['label']!,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    Navigator.pop(sheetContext);
                    _filter = value;
                    _applyFilters();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _card(_ReferralHousehold household) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withOpacity(0.08)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: widget.color.withOpacity(0.10),
          child: Icon(Icons.home_work_outlined, color: widget.color),
        ),
        title: Text(
          household.clientName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _pill('File ${household.fileNumber}', Colors.blueGrey),
              _pill(
                '${household.totalReferrals} referral${household.totalReferrals == 1 ? '' : 's'}',
                household.totalReferrals > 0 ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _openHouseholdReferrals(household),
              child: const Text(
                'HH Referrals',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.blueGrey),
          ],
        ),
        children: [
          if (household.members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No household members found.'),
            )
          else
            ...household.members.map((member) {
              final detail = [
                member.role,
                if (member.sex.isNotEmpty) member.sex,
                if (member.age.isNotEmpty) '${member.age} yrs',
              ].join(' • ');

              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      member.isPrimary
                          ? Icons.person_pin_outlined
                          : Icons.person_outline,
                      color: widget.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            detail,
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openMemberReferrals(household, member),
                      child: Text(
                        member.referralCount == 0
                            ? 'Referrals'
                            : 'Referrals (${member.referralCount})',
                        style: const TextStyle(
                          fontSize: 11.3,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (sum, item) => sum + item.totalReferrals);

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
                  const Icon(Icons.handshake_outlined,
                      color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Referrals\n$total referral${total == 1 ? '' : 's'} recorded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
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
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Icon(Icons.circle,
                              size: 12, color: widget.color),
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? const Icon(Icons.public_outlined,
                            color: Colors.blueGrey)
                            : IconButton(
                          onPressed: () {
                            _searchController.clear();
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
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: IconButton(
                      onPressed: _openFilterSheet,
                      icon: Icon(
                        Icons.tune_outlined,
                        color:
                        _filter == 'ALL' ? Colors.blueGrey : widget.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No referral households found')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, index) => _card(_filtered[index]),
                childCount: _filtered.length,
              ),
            ),
        ],
      ),
    );
  }
}