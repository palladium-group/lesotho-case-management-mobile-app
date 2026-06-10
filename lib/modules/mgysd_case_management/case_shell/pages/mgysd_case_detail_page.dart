import 'package:flutter/material.dart';
import 'package:lncmis_mobile_app/core/offline_db/offline_db_provider.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/constants/mgysd_dhis2_uids.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/shared/models/mgysd_case.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/workflow/pages/mgysd_repeatable_stage_list_page.dart';
import 'package:lncmis_mobile_app/modules/mgysd_case_management/service_provision/pages/mgysd_service_provision_page.dart';
import 'package:sqflite/sqflite.dart';

class MgysdCaseDetailPage extends StatefulWidget {
  const MgysdCaseDetailPage({
    Key? key,
    required this.color,
    required this.mgysdCase,
  }) : super(key: key);

  final Color color;
  final MgysdCase mgysdCase;

  @override
  State<MgysdCaseDetailPage> createState() => _MgysdCaseDetailPageState();
}

class _WorkflowStepSummary {
  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final String latestDate;
  final String tableName;
  final String stageKey;
  final String programStage;

  const _WorkflowStepSummary({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.latestDate,
    required this.tableName,
    required this.stageKey,
    required this.programStage,
  });
}

class _HouseholdInfo {
  final String tei;
  final String fileNumber;
  final String name;
  final String district;
  final String communityCouncil;
  final String village;
  final String address;

  const _HouseholdInfo({
    required this.tei,
    required this.fileNumber,
    required this.name,
    required this.district,
    required this.communityCouncil,
    required this.village,
    required this.address,
  });

  bool get hasAnyData =>
      fileNumber.trim().isNotEmpty ||
          name.trim().isNotEmpty ||
          district.trim().isNotEmpty ||
          communityCouncil.trim().isNotEmpty ||
          village.trim().isNotEmpty ||
          address.trim().isNotEmpty;
}

class _HouseholdMember {
  final String tei;
  final String enrollment;
  final String role;
  final bool isPrimaryClient;
  final String firstName;
  final String lastName;
  final String dob;
  final String age;
  final String sex;
  final String phone;
  final String relationship;
  final String disability;
  final int openGoals;
  final int services;

  const _HouseholdMember({
    required this.tei,
    required this.enrollment,
    required this.role,
    required this.isPrimaryClient,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.age,
    required this.sex,
    required this.phone,
    required this.relationship,
    required this.disability,
    required this.openGoals,
    required this.services,
  });

  String get fullName {
    final full = ('$firstName $lastName').trim();
    return full.isEmpty ? '(No name)' : full;
  }
}

class _CaseDetailData {
  final String householdTei;
  final String householdEnrollment;
  final String householdProgramStatus;
  final String clientTei;
  final String clientEnrollment;
  final String clientName;
  final String clientPhone;
  final String clientAge;
  final String clientSex;
  final String riskLevel;
  final int carePlans;
  final int activeCarePlans;
  final int householdOpenGoals;
  final int householdServices;
  final _HouseholdInfo? household;
  final List<_HouseholdMember> householdMembers;
  final List<_WorkflowStepSummary> workflowSteps;

  const _CaseDetailData({
    required this.householdTei,
    required this.householdEnrollment,
    required this.householdProgramStatus,
    required this.clientTei,
    required this.clientEnrollment,
    required this.clientName,
    required this.clientPhone,
    required this.clientAge,
    required this.clientSex,
    required this.riskLevel,
    required this.carePlans,
    required this.activeCarePlans,
    required this.householdOpenGoals,
    required this.householdServices,
    required this.household,
    required this.householdMembers,
    required this.workflowSteps,
  });
}

class _MgysdCaseDetailPageState extends State<MgysdCaseDetailPage> {
  late Future<_CaseDetailData> _future;
  int _selectedTab = 0;

  static const String psSocialInvestigation =
      MgysdDhis2Uids.socialInvestigationStage;
  static const String psReferral = MgysdDhis2Uids.referralStage;
  static const String psMonitoring = MgysdDhis2Uids.monitoringStage;

  static const String familyPsServiceProvision =
      MgysdDhis2Uids.familyServiceProvisionStage;
  static const String familyPsReferral = MgysdDhis2Uids.familyReferralStage;

  static const String tableSocialInvestigation = 'mgysd_social_investigation';
  static const String tableReferral = 'mgysd_referral';
  static const String tableMonitoring = 'mgysd_monitoring';

  static const String attFirstName = MgysdDhis2Uids.attFirstName;
  static const String attLastName = MgysdDhis2Uids.attLastName;
  static const String attDob = MgysdDhis2Uids.attDob;
  static const String attAge = MgysdDhis2Uids.attAge;
  static const String attSex = MgysdDhis2Uids.attSex;
  static const String attPhone = MgysdDhis2Uids.attPhone;
  static const String attRelationshipToClient =
      MgysdDhis2Uids.attRelationshipToClient;
  static const String attHasDisability = MgysdDhis2Uids.attHasDisability;
  static const String attDisabilitySpecify =
      MgysdDhis2Uids.attDisabilitySpecify;
  static const String attRiskLevel = MgysdDhis2Uids.attRiskLevel;

  static const String legacyAttPersonFirstName = 'ATTR_P_FIRSTNAME';
  static const String legacyAttPersonLastName = 'ATTR_P_LASTNAME';
  static const String legacyAttPersonDob = 'ATTR_P_DOB';
  static const String legacyAttPersonPhone = 'ATTR_P_PHONE';

  static const String attHouseholdCode = 'ATTR_HOUSEHOLD_CODE';
  static const String attHouseholdFileNumber =
      MgysdDhis2Uids.attHouseholdFileNumber;
  static const String attHouseholdName = 'ATTR_HOUSEHOLD_NAME';
  static const String attHouseholdDistrict =
      MgysdDhis2Uids.attHouseholdDistrict;
  static const String attHouseholdCommunityCouncil =
      MgysdDhis2Uids.attHouseholdCommunityCouncil;
  static const String attHouseholdVillage =
      MgysdDhis2Uids.attHouseholdVillage;
  static const String attHouseholdAddress =
      MgysdDhis2Uids.attHouseholdAddress;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<Database> _db() async {
    final dbClient = await OfflineDbProvider().db;
    if (dbClient == null) throw Exception('Offline DB not initialized');
    return dbClient;
  }

  String get _caseRootId {
    final parts = widget.mgysdCase.id.split('__');
    return parts.isNotEmpty ? parts.first : widget.mgysdCase.id;
  }

  String _dateOnly(String value) {
    final v = value.trim();
    if (v.length >= 10) return v.substring(0, 10);
    return v;
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

  Future<Map<String, String>> _attrs(Database db, String tei) async {
    try {
      final rows = await db.query(
        'tracked_entity_instance_attribute',
        columns: ['attribute', 'value'],
        where: 'trackedEntityInstance = ?',
        whereArgs: [tei],
      );

      final map = <String, String>{};
      for (final row in rows) {
        final key = (row['attribute'] ?? '').toString();
        final value = (row['value'] ?? '').toString();
        if (key.isNotEmpty) map[key] = value;
      }
      return map;
    } catch (_) {
      return <String, String>{};
    }
  }

  String _readFirstName(Map<String, String> attrs) {
    return attrs[attFirstName] ?? attrs[legacyAttPersonFirstName] ?? '';
  }

  String _readLastName(Map<String, String> attrs) {
    return attrs[attLastName] ?? attrs[legacyAttPersonLastName] ?? '';
  }

  String _readDob(Map<String, String> attrs) {
    return attrs[attDob] ?? attrs[legacyAttPersonDob] ?? '';
  }

  String _readPhone(Map<String, String> attrs) {
    return attrs[attPhone] ?? attrs[legacyAttPersonPhone] ?? '';
  }

  String _prettyRole(String role) {
    switch (role.toUpperCase()) {
      case 'CLIENT':
        return 'Client';
      case 'MOTHER':
        return 'Mother';
      case 'FATHER':
        return 'Father';
      case 'CAREGIVER':
        return 'Caregiver';
      case 'PERSONAL_ASSISTANT':
        return 'Personal assistant';
      case 'GUARDIAN':
        return 'Guardian';
      case 'SPOUSE':
        return 'Spouse';
      case 'CHILD':
        return 'Child';
      case 'BROTHER':
        return 'Brother';
      case 'SISTER':
        return 'Sister';
      case 'HOUSEHOLD_MEMBER':
        return 'Household member';
      default:
        return role.replaceAll('_', ' ').trim();
    }
  }

  Future<Map<String, String>> _caseEnrollmentInfo(Database db) async {
    try {
      final rows = await db.query(
        'enrollment',
        where: 'enrollment = ?',
        whereArgs: [_caseRootId],
        limit: 1,
      );

      if (rows.isEmpty) return <String, String>{};

      final row = rows.first;
      final householdTei =
      (row['trackedEntityInstance'] ?? '').toString().trim();
      final householdEnrollment = (row['enrollment'] ?? '').toString().trim();
      final program = (row['program'] ?? '').toString().trim();

      final clientTei = householdTei.isEmpty
          ? ''
          : ((await _primaryClientTeiFromHousehold(db, householdTei)) ?? '');

      final clientEnrollment =
      clientTei.isEmpty ? '' : await _memberEnrollment(db, clientTei);

      return {
        'householdEnrollment': householdEnrollment,
        'householdTei': householdTei,
        'program': program,
        'clientTei': clientTei,
        'clientEnrollment': clientEnrollment,
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String?> _primaryClientTeiFromHousehold(
      Database db,
      String householdTei,
      ) async {
    try {
      final rows = await db.query(
        'mgysd_household_member',
        columns: ['memberTei'],
        where: 'householdTei = ? AND isPrimaryClient = ?',
        whereArgs: [householdTei, 'true'],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final tei = (rows.first['memberTei'] ?? '').toString().trim();
        if (tei.isNotEmpty) return tei;
      }

      final fallbackRows = await db.query(
        'mgysd_household_member',
        columns: ['memberTei'],
        where: 'householdTei = ? AND memberRole = ?',
        whereArgs: [householdTei, 'CLIENT'],
        limit: 1,
      );

      if (fallbackRows.isEmpty) return null;

      final tei = (fallbackRows.first['memberTei'] ?? '').toString().trim();
      return tei.isEmpty ? null : tei;
    } catch (_) {
      return null;
    }
  }

  Future<String> _memberEnrollment(Database db, String memberTei) async {
    try {
      final rows = await db.query(
        'enrollment',
        columns: ['enrollment'],
        where: 'trackedEntityInstance = ?',
        whereArgs: [memberTei],
        orderBy: 'enrollmentDate DESC',
        limit: 1,
      );

      if (rows.isEmpty) return '';
      return (rows.first['enrollment'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<_HouseholdInfo?> _loadHousehold(
      Database db,
      String householdTei,
      ) async {
    final attrs = await _attrs(db, householdTei);

    return _HouseholdInfo(
      tei: householdTei,
      fileNumber: attrs[attHouseholdFileNumber] ?? attrs[attHouseholdCode] ?? '',
      name: attrs[attHouseholdName] ?? '',
      district: attrs[attHouseholdDistrict] ?? '',
      communityCouncil: attrs[attHouseholdCommunityCouncil] ?? '',
      village: attrs[attHouseholdVillage] ?? '',
      address: attrs[attHouseholdAddress] ?? '',
    );
  }

  Future<int> _countRows(
      Database db,
      String tableName,
      String where,
      List<Object?> whereArgs,
      ) async {
    try {
      if (!await _tableExists(db, tableName)) return 0;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $tableName WHERE $where',
        whereArgs,
      );
      if (rows.isEmpty) return 0;
      return int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countOpenGoals(Database db, String tei) async {
    if (tei.trim().isEmpty) return 0;
    try {
      if (!await _tableExists(db, 'mgysd_care_plan_goal')) return 0;
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c
        FROM mgysd_care_plan_goal
        WHERE (targetTei = ? OR subjectTei = ?)
        AND LOWER(COALESCE(goalStatus, 'open')) != 'achieved'
      ''', [tei, tei]);
      if (rows.isEmpty) return 0;
      return int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countMemberServices(Database db, String tei) async {
    if (tei.trim().isEmpty) return 0;
    return _countRows(db, 'mgysd_service_provision', 'memberTei = ?', [tei]);
  }

  Future<List<_HouseholdMember>> _loadHouseholdMembers(
      Database db,
      String householdTei,
      ) async {
    try {
      final helperRows = await db.query(
        'mgysd_household_member',
        where: 'householdTei = ?',
        whereArgs: [householdTei],
      );

      final members = <_HouseholdMember>[];

      for (final row in helperRows) {
        final tei = (row['memberTei'] ?? '').toString().trim();
        if (tei.isEmpty) continue;

        final attrs = await _attrs(db, tei);
        final role = (row['memberRole'] ?? '').toString().trim();
        final isPrimaryClient =
            (row['isPrimaryClient'] ?? '').toString().toLowerCase() == 'true' ||
                role.toUpperCase() == 'CLIENT';

        final disability = [
          attrs[attHasDisability] ?? '',
          attrs[attDisabilitySpecify] ?? '',
        ].where((v) => v.trim().isNotEmpty).join(': ');

        members.add(
          _HouseholdMember(
            tei: tei,
            enrollment: await _memberEnrollment(db, tei),
            role: role,
            isPrimaryClient: isPrimaryClient,
            firstName: _readFirstName(attrs),
            lastName: _readLastName(attrs),
            dob: _readDob(attrs),
            age: attrs[attAge] ?? '',
            sex: attrs[attSex] ?? '',
            phone: _readPhone(attrs),
            relationship: attrs[attRelationshipToClient] ?? role,
            disability: disability,
            openGoals: await _countOpenGoals(db, tei),
            services: await _countMemberServices(db, tei),
          ),
        );
      }

      members.sort((a, b) {
        if (a.isPrimaryClient && !b.isPrimaryClient) return -1;
        if (!a.isPrimaryClient && b.isPrimaryClient) return 1;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });

      return members;
    } catch (_) {
      return <_HouseholdMember>[];
    }
  }

  Future<int> _countCarePlans(Database db, String householdTei) async {
    if (householdTei.trim().isEmpty) return 0;
    return _countRows(db, 'mgysd_care_plan', 'householdTei = ?', [householdTei]);
  }

  Future<int> _countActiveCarePlans(Database db, String householdTei) async {
    if (householdTei.trim().isEmpty) return 0;
    try {
      if (!await _tableExists(db, 'mgysd_care_plan')) return 0;

      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS c
        FROM mgysd_care_plan
        WHERE householdTei = ?
        AND UPPER(
          COALESCE(
            NULLIF(carePlanStatus, ''),
            NULLIF(planStatus, ''),
            'ACTIVE'
          )
        ) = 'ACTIVE'
      ''', [householdTei]);

      if (rows.isEmpty) return 0;
      return int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countLegacyTableRecords({
    required Database db,
    required String tableName,
    required String stageKey,
  }) async {
    try {
      if (!await _tableExists(db, tableName)) return 0;

      final rows = await db.query(tableName);
      final prefix = '${_caseRootId}__$stageKey';

      return rows.where((row) {
        for (final entry in row.entries) {
          final value = (entry.value ?? '').toString();

          if ((entry.key == 'parentCaseId' || entry.key == 'rootCaseId') &&
              value == _caseRootId) {
            return true;
          }

          if ((entry.key == 'id' ||
              entry.key == 'caseId' ||
              entry.key == 'event') &&
              value.startsWith(prefix)) {
            return true;
          }

          if (value.contains(prefix)) return true;
        }

        return false;
      }).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countProgramStageEvents({
    required Database db,
    required String tei,
    required String enrollment,
    required String programStage,
  }) async {
    try {
      if (!await _tableExists(db, 'events')) return 0;

      final rows = await db.query('events');

      return rows.where((row) {
        final rowTei = (row['trackedEntityInstance'] ?? '').toString();
        final rowProgramStage = (row['programStage'] ?? '').toString();

        final teiMatches = tei.trim().isNotEmpty && rowTei == tei;
        final stageMatches =
            programStage.trim().isNotEmpty && rowProgramStage == programStage;

        return stageMatches && teiMatches;
      }).length;
    } catch (_) {
      return 0;
    }
  }

  Future<String> _latestEventDate({
    required Database db,
    required String tei,
    required String enrollment,
    required String programStage,
    required String legacyTable,
    required String stageKey,
  }) async {
    final dates = <String>[];

    try {
      if (await _tableExists(db, 'events')) {
        final rows = await db.query('events');

        for (final row in rows) {
          final rowTei = (row['trackedEntityInstance'] ?? '').toString();
          final rowProgramStage = (row['programStage'] ?? '').toString();

          final teiMatches = tei.trim().isNotEmpty && rowTei == tei;
          final stageMatches =
              programStage.trim().isNotEmpty && rowProgramStage == programStage;

          if (stageMatches && teiMatches) {
            final date = (row['eventDate'] ?? '').toString();
            if (date.trim().isNotEmpty) dates.add(date);
          }
        }
      }

      if (await _tableExists(db, legacyTable)) {
        final rows = await db.query(legacyTable);
        final prefix = '${_caseRootId}__$stageKey';

        for (final row in rows) {
          final matches = row.values.any((value) {
            final text = (value ?? '').toString();
            return text == _caseRootId ||
                text.startsWith(prefix) ||
                text.contains(prefix);
          });

          if (matches) {
            final date = (row['eventDate'] ??
                row['date'] ??
                row['assessmentDate'] ??
                row['investigationDate'] ??
                row['referralDate'] ??
                row['monitoringDate'] ??
                row['planDate'] ??
                row['updatedAt'] ??
                '')
                .toString();

            if (date.trim().isNotEmpty) dates.add(date);
          }
        }
      }
    } catch (_) {}

    dates.sort((a, b) => b.compareTo(a));
    return dates.isEmpty ? '' : dates.first;
  }

  Future<_WorkflowStepSummary> _workflowSummary({
    required Database db,
    required String title,
    required String subtitle,
    required IconData icon,
    required String tableName,
    required String stageKey,
    required String programStage,
    required String tei,
    required String enrollment,
  }) async {
    final eventCount = await _countProgramStageEvents(
      db: db,
      tei: tei,
      enrollment: enrollment,
      programStage: programStage,
    );

    final legacyCount = await _countLegacyTableRecords(
      db: db,
      tableName: tableName,
      stageKey: stageKey,
    );

    final count = eventCount > 0 ? eventCount : legacyCount;

    final latestDate = await _latestEventDate(
      db: db,
      tei: tei,
      enrollment: enrollment,
      programStage: programStage,
      legacyTable: tableName,
      stageKey: stageKey,
    );

    return _WorkflowStepSummary(
      title: title,
      subtitle: subtitle,
      icon: icon,
      count: count,
      latestDate: latestDate,
      tableName: tableName,
      stageKey: stageKey,
      programStage: programStage,
    );
  }

  Future<_CaseDetailData> _loadData() async {
    final db = await _db();

    final enrollmentInfo = await _caseEnrollmentInfo(db);
    final householdTei = enrollmentInfo['householdTei'] ?? '';
    final householdEnrollment =
        enrollmentInfo['householdEnrollment'] ?? _caseRootId;
    final householdProgram = enrollmentInfo['program'] ?? '';
    final clientTei = enrollmentInfo['clientTei'] ?? '';
    final clientEnrollment = enrollmentInfo['clientEnrollment'] ?? '';

    final clientAttrs = clientTei.trim().isEmpty
        ? <String, String>{}
        : await _attrs(db, clientTei);

    final clientName = [
      _readFirstName(clientAttrs),
      _readLastName(clientAttrs),
    ].where((v) => v.trim().isNotEmpty).join(' ').trim();

    final household = householdTei.trim().isEmpty
        ? null
        : await _loadHousehold(db, householdTei);

    final members = householdTei.trim().isEmpty
        ? <_HouseholdMember>[]
        : await _loadHouseholdMembers(db, householdTei);

    final workflowSteps = <_WorkflowStepSummary>[
      await _workflowSummary(
        db: db,
        title: 'Social Investigation',
        subtitle: 'Creates the investigation record and its linked care plan cycle',
        icon: Icons.fact_check_outlined,
        tableName: tableSocialInvestigation,
        stageKey: 'social_investigation',
        programStage: psSocialInvestigation,
        tei: householdTei,
        enrollment: householdEnrollment,
      ),
      await _workflowSummary(
        db: db,
        title: 'Referral',
        subtitle: 'Referrals made for this household case',
        icon: Icons.handshake_outlined,
        tableName: tableReferral,
        stageKey: 'referral',
        programStage: psReferral,
        tei: householdTei,
        enrollment: householdEnrollment,
      ),
      await _workflowSummary(
        db: db,
        title: 'Monitoring',
        subtitle: 'Routine progress review or reassessment cycle',
        icon: Icons.monitor_heart_outlined,
        tableName: tableMonitoring,
        stageKey: 'monitoring',
        programStage: psMonitoring,
        tei: householdTei,
        enrollment: householdEnrollment,
      ),
    ];

    return _CaseDetailData(
      householdTei: householdTei,
      householdEnrollment: householdEnrollment,
      householdProgramStatus:
      householdProgram == MgysdDhis2Uids.enrolledHouseholdsProgram
          ? 'ENROLLED'
          : 'ASSESSED',
      clientTei: clientTei,
      clientEnrollment: clientEnrollment,
      clientName: clientName.isEmpty ? widget.mgysdCase.fullName : clientName,
      clientPhone: _readPhone(clientAttrs).isEmpty
          ? (widget.mgysdCase.phone ?? '')
          : _readPhone(clientAttrs),
      clientAge: clientAttrs[attAge] ?? '',
      clientSex: clientAttrs[attSex] ?? '',
      riskLevel: clientAttrs[attRiskLevel] ?? '',
      carePlans: await _countCarePlans(db, householdTei),
      activeCarePlans: await _countActiveCarePlans(db, householdTei),
      householdOpenGoals: await _countOpenGoals(db, householdTei),
      householdServices: await _countMemberServices(db, householdTei),
      household: household,
      householdMembers: members,
      workflowSteps: workflowSteps,
    );
  }

  Future<void> _refresh() async {
    final nextFuture = _loadData();

    if (!mounted) return;

    setState(() {
      _future = nextFuture;
    });

    await nextFuture;
  }

  Future<void> _openWorkflowStep(
      _CaseDetailData data,
      _WorkflowStepSummary step,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdRepeatableStageListPage(
          color: widget.color,
          parentCase: widget.mgysdCase,
          stageTitle: step.title,
          tableName: step.tableName,
          stageKey: step.stageKey,
          programStage: step.programStage,
          icon: step.icon,
          trackedEntityInstance: data.householdTei,
          enrollment: data.householdEnrollment,
          householdTei: data.household?.tei,
          householdName: data.household?.name,
          clientName: data.clientName,
          subjectName: data.clientName,
          subjectRole: 'Primary client',
        ),
      ),
    );

    await _refresh();
  }

  Future<void> _openHouseholdServices(_CaseDetailData data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdServiceProvisionPage(
          color: widget.color,
          mgysdCase: widget.mgysdCase,
          householdTei: data.household?.tei ?? data.householdTei,
          householdName: data.household?.name,
          clientName: data.clientName,
          memberTei: null,
          memberName: data.household?.name?.trim().isNotEmpty == true
              ? data.household!.name
              : 'Household',
          memberRole: 'Household',
        ),
      ),
    );

    await _refresh();
  }

  Future<void> _openMemberServices({
    required _CaseDetailData data,
    required _HouseholdMember member,
  }) async {
    final roleLabel = _prettyRole(
      member.relationship.isEmpty ? member.role : member.relationship,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdServiceProvisionPage(
          color: widget.color,
          mgysdCase: widget.mgysdCase,
          householdTei: data.household?.tei ?? data.householdTei,
          householdName: data.household?.name,
          clientName: data.clientName,
          memberTei: member.tei,
          memberName: member.fullName,
          memberRole: roleLabel,
        ),
      ),
    );

    await _refresh();
  }

  Future<void> _openMemberStageList({
    required _CaseDetailData data,
    required _HouseholdMember member,
    required String title,
    required String stageKey,
    required String programStage,
    required IconData icon,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MgysdRepeatableStageListPage(
          color: widget.color,
          parentCase: widget.mgysdCase,
          stageTitle: title,
          tableName: 'events',
          stageKey: stageKey,
          programStage: programStage,
          icon: icon,
          trackedEntityInstance: member.tei,
          enrollment: member.enrollment,
          householdTei: data.household?.tei,
          householdName: data.household?.name,
          clientName: data.clientName,
          subjectName: member.fullName,
          subjectRole: _prettyRole(
            member.relationship.isEmpty ? member.role : member.relationship,
          ),
        ),
      ),
    );

    await _refresh();
  }

  int _totalActivities(_CaseDetailData data) {
    return data.workflowSteps.fold<int>(0, (sum, step) => sum + step.count) +
        data.carePlans;
  }

  int _completedStages(_CaseDetailData data) {
    return data.workflowSteps.where((step) => step.count > 0).length;
  }

  String _priorityLabel(_CaseDetailData data) {
    if (data.householdProgramStatus != 'ENROLLED') return 'Assessed only';

    final social = data.workflowSteps.firstWhere(
          (e) => e.stageKey == 'social_investigation',
      orElse: () => data.workflowSteps.first,
    );

    final monitoring = data.workflowSteps.firstWhere(
          (e) => e.stageKey == 'monitoring',
      orElse: () => data.workflowSteps.last,
    );

    if (social.count == 0) return 'New enrolled case';
    if (data.activeCarePlans == 0) return 'Care plan needed';
    if (data.activeCarePlans > 1) return 'Review active plans';
    if (monitoring.count == 0) return 'Follow-up needed';
    return 'Active support';
  }

  Color _priorityColor(_CaseDetailData data) {
    final label = _priorityLabel(data);
    if (label == 'Assessed only') return Colors.blueGrey;
    if (label == 'New enrolled case') return Colors.deepOrange;
    if (label == 'Care plan needed') return Colors.deepPurple;
    if (label == 'Review active plans') return Colors.redAccent;
    if (label == 'Follow-up needed') return Colors.amber.shade800;
    return Colors.green;
  }

  List<String> _caseInsights(_CaseDetailData data) {
    final insights = <String>[];

    final social = data.workflowSteps.firstWhere(
          (e) => e.stageKey == 'social_investigation',
      orElse: () => data.workflowSteps.first,
    );
    final monitoring = data.workflowSteps.firstWhere(
          (e) => e.stageKey == 'monitoring',
      orElse: () => data.workflowSteps.first,
    );
    final referral = data.workflowSteps.firstWhere(
          (e) => e.stageKey == 'referral',
      orElse: () => data.workflowSteps.first,
    );

    if (data.householdProgramStatus != 'ENROLLED') {
      insights.add(
        'This household is assessed only. Enrolment starts when risk is above No/Low.',
      );
    } else if (social.count == 0) {
      insights.add(
        'Start with Social Investigation. The linked Care Plan will be opened from that investigation record.',
      );
    }

    if (social.count > 0 && data.activeCarePlans == 0) {
      insights.add(
        'A Social Investigation exists but no active Care Plan is available. Open the investigation and check its linked Care Plan.',
      );
    }
    if (data.activeCarePlans > 1) {
      insights.add(
        'More than one active Care Plan is detected. Only the latest plan should remain active for service provision.',
      );
    }
    if (referral.count == 0) {
      insights.add('No referrals have been recorded for this household case.');
    }
    if (monitoring.count == 0) {
      insights.add('No monitoring visit has been recorded yet.');
    }
    if (data.householdMembers.length <= 1) {
      insights.add('Household linkage may be incomplete. Review household members.');
    }
    if (data.householdMembers.any((m) => m.disability.trim().isNotEmpty)) {
      insights.add('Household includes disability-related support needs.');
    }

    if (insights.isEmpty) {
      insights.add('Case has active workflow records and household linkage.');
    }

    return insights.take(3).toList();
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(15),
        child: child,
      ),
    );
  }

  Widget _chip(String label, {Color? color, bool strong = false}) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    final c = color ?? Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(strong ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(strong ? 0.22 : 0.10)),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _softPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 11.5,
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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.blueGrey,
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _tabChip(String label, int index, IconData icon) {
    final selected = _selectedTab == index;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? widget.color : Colors.blueGrey,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: widget.color.withOpacity(0.14),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? widget.color : Colors.black87,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? widget.color.withOpacity(0.35)
            : Colors.blueGrey.withOpacity(0.15),
      ),
      onSelected: (_) => setState(() => _selectedTab = index),
    );
  }

  Widget _heroMiniMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _heroCard(_CaseDetailData data) {
    final household = data.household;
    final priority = _priorityLabel(data);
    final priorityColor = _priorityColor(data);

    final latestDates = data.workflowSteps
        .map((e) => e.latestDate)
        .where((d) => d.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final lastActivity =
    latestDates.isEmpty ? 'No activity yet' : _dateOnly(latestDates.first);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            widget.color,
            widget.color.withOpacity(0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chip(
              priority.toUpperCase(),
              color: priorityColor == Colors.green ? Colors.white : Colors.white,
              strong: true,
            ),
            const SizedBox(height: 18),
            Text(
              data.clientName.trim().isEmpty
                  ? widget.mgysdCase.caseNo
                  : data.clientName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.mgysdCase.caseNo,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  data.householdProgramStatus == 'ENROLLED'
                      ? 'ENROLLED HOUSEHOLD'
                      : 'ASSESSED HOUSEHOLD',
                  color: Colors.white,
                  strong: true,
                ),
                if (data.riskLevel.trim().isNotEmpty)
                  _chip('Risk: ${data.riskLevel}', color: Colors.white),
                _chip('Care Plans: ${data.carePlans}', color: Colors.white),
                if (data.activeCarePlans > 0)
                  _chip('Active: ${data.activeCarePlans}', color: Colors.white),
                if (data.activeCarePlans > 1)
                  _chip('Review active plans', color: Colors.white),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Last activity: $lastActivity', color: Colors.white),
                if (data.clientAge.trim().isNotEmpty)
                  _chip('${data.clientAge} yrs', color: Colors.white),
                if (data.clientSex.trim().isNotEmpty)
                  _chip(data.clientSex, color: Colors.white),
                if ((household?.district ?? '').trim().isNotEmpty)
                  _chip(household!.district, color: Colors.white),
                if ((household?.village ?? '').trim().isNotEmpty)
                  _chip(household!.village, color: Colors.white),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _heroMiniMetric(
                      icon: Icons.groups_2_outlined,
                      value: '${data.householdMembers.length}',
                      label: 'Household',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    color: Colors.white.withOpacity(0.18),
                  ),
                  Expanded(
                    child: _heroMiniMetric(
                      icon: Icons.assignment_turned_in_outlined,
                      value:
                      '${_completedStages(data)}/${data.workflowSteps.length}',
                      label: 'Stages',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    color: Colors.white.withOpacity(0.18),
                  ),
                  Expanded(
                    child: _heroMiniMetric(
                      icon: Icons.timeline_outlined,
                      value: '${_totalActivities(data)}',
                      label: 'Records',
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

  Widget _insightsCard(_CaseDetailData data) {
    final insights = _caseInsights(data);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Case Focus',
            'Important prompts to guide the next case-management action.',
          ),
          const SizedBox(height: 12),
          Column(
            children: insights.map((insight) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amber.withOpacity(0.14)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        insight,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _workflowTile(
      _CaseDetailData data,
      _WorkflowStepSummary step,
      int index,
      ) {
    final hasRecords = step.count > 0;
    final isLast = index == data.workflowSteps.length - 1;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openWorkflowStep(data, step),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasRecords ? widget.color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasRecords
                        ? widget.color
                        : Colors.blueGrey.withOpacity(0.25),
                    width: 2,
                  ),
                  boxShadow: hasRecords
                      ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                      : [],
                ),
                child: hasRecords
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 54,
                  color: hasRecords
                      ? widget.color.withOpacity(0.45)
                      : Colors.blueGrey.withOpacity(0.14),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                hasRecords ? widget.color.withOpacity(0.055) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasRecords
                      ? widget.color.withOpacity(0.16)
                      : Colors.blueGrey.withOpacity(0.08),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: widget.color.withOpacity(0.10),
                    child: Icon(step.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.subtitle,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12.3,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _chip(
                              hasRecords
                                  ? '${step.count} record${step.count == 1 ? '' : 's'}'
                                  : 'Not started',
                              color: hasRecords ? widget.color : Colors.blueGrey,
                              strong: hasRecords,
                            ),
                            if (step.latestDate.trim().isNotEmpty)
                              _chip('Latest: ${_dateOnly(step.latestDate)}'),
                            if (step.stageKey == 'social_investigation')
                              _chip('Care Plan opens inside record',
                                  color: Colors.deepPurple),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.blueGrey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseDetails(_CaseDetailData data) {
    final social = data.workflowSteps.firstWhere(
          (step) => step.stageKey == 'social_investigation',
    );
    final referrals = data.workflowSteps.firstWhere(
          (step) => step.stageKey == 'referral',
    );
    final monitoring = data.workflowSteps.firstWhere(
          (step) => step.stageKey == 'monitoring',
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _heroCard(data),
        _insightsCard(data),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'Household Case Snapshot',
                'A quick operational view of this household case.',
              ),
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _softPill(
                    label: 'Household members',
                    value: '${data.householdMembers.length}',
                    icon: Icons.groups_outlined,
                    color: widget.color,
                  ),
                  const SizedBox(width: 10),
                  _softPill(
                    label: 'Investigations',
                    value: '${social.count}',
                    icon: Icons.fact_check_outlined,
                    color: Colors.indigo,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _softPill(
                    label: 'Care Plans',
                    value: '${data.carePlans}',
                    icon: Icons.assignment_outlined,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 10),
                  _softPill(
                    label: 'Monitoring',
                    value: '${monitoring.count}',
                    icon: Icons.monitor_heart_outlined,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _softPill(
                    label: 'Referrals',
                    value: '${referrals.count}',
                    icon: Icons.handshake_outlined,
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(width: 10),
                  _softPill(
                    label: 'Active Plans',
                    value: '${data.activeCarePlans}',
                    icon: Icons.play_circle_outline,
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'Household Case Workflow',
                'Care Plans are no longer created here. Open a Social Investigation record to view or create its linked Care Plan.',
              ),
              const SizedBox(height: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(data.workflowSteps.length, (index) {
                  return _workflowTile(data, data.workflowSteps[index], index);
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.blueGrey, height: 1.35),
      ),
    );
  }

  Widget _memberActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.color,
        side: BorderSide(color: widget.color.withOpacity(0.45)),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _householdSummary(_CaseDetailData data) {
    final clientCount =
        data.householdMembers.where((m) => m.isPrimaryClient).length;

    final disabilityCount = data.householdMembers
        .where((m) => m.disability.trim().isNotEmpty)
        .length;

    final adults = data.householdMembers.where((m) {
      final age = int.tryParse(m.age);
      return age != null && age >= 18;
    }).length;

    final totalOpenGoals = data.householdOpenGoals +
        data.householdMembers.fold<int>(0, (sum, m) => sum + m.openGoals);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Household Overview',
            'Family composition, service workload and support indicators.',
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _softPill(
                label: 'Members',
                value: '${data.householdMembers.length}',
                icon: Icons.groups_2_outlined,
                color: widget.color,
              ),
              const SizedBox(width: 10),
              _softPill(
                label: 'Adults',
                value: '$adults',
                icon: Icons.person_outline,
                color: Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _softPill(
                label: 'Primary client',
                value: '$clientCount',
                icon: Icons.person_pin_circle_outlined,
                color: Colors.teal,
              ),
              const SizedBox(width: 10),
              _softPill(
                label: 'Disability needs',
                value: '$disabilityCount',
                icon: Icons.accessible_outlined,
                color: Colors.deepOrange,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _softPill(
                label: 'Open goals',
                value: '$totalOpenGoals',
                icon: Icons.track_changes_outlined,
                color: Colors.deepPurple,
              ),
              const SizedBox(width: 10),
              _softPill(
                label: 'HH services',
                value: '${data.householdServices}',
                icon: Icons.home_repair_service_outlined,
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memberCard(_CaseDetailData data, _HouseholdMember member) {
    final roleLabel = _prettyRole(
      member.relationship.trim().isEmpty ? member.role : member.relationship,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: member.isPrimaryClient
            ? widget.color.withOpacity(0.055)
            : const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: member.isPrimaryClient
              ? widget.color.withOpacity(0.18)
              : Colors.blueGrey.withOpacity(0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: widget.color.withOpacity(0.12),
                child: Icon(
                  member.isPrimaryClient
                      ? Icons.person_pin_circle
                      : Icons.person_outline,
                  color: widget.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _chip(
                          member.isPrimaryClient ? 'Primary client' : roleLabel,
                          color: member.isPrimaryClient
                              ? widget.color
                              : Colors.blueGrey,
                          strong: member.isPrimaryClient,
                        ),
                        if (member.sex.trim().isNotEmpty) _chip(member.sex),
                        if (member.age.trim().isNotEmpty)
                          _chip('${member.age} yrs'),
                        if (member.phone.trim().isNotEmpty) _chip(member.phone),
                        if (member.disability.trim().isNotEmpty)
                          _chip(member.disability, color: Colors.deepOrange),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Open goals: ${member.openGoals}',
                        color: Colors.deepPurple, strong: member.openGoals > 0),
                    _chip('Services: ${member.services}',
                        color: Colors.teal, strong: member.services > 0),
                    if (member.enrollment.trim().isEmpty)
                      _chip('Not enrolled for services', color: Colors.blueGrey),
                  ],
                ),
                if (member.enrollment.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 145,
                        child: _memberActionButton(
                          label: 'Service',
                          icon: Icons.volunteer_activism_outlined,
                          onTap: () => _openMemberServices(
                            data: data,
                            member: member,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 145,
                        child: _memberActionButton(
                          label: 'Referral',
                          icon: Icons.handshake_outlined,
                          onTap: () => _openMemberStageList(
                            data: data,
                            member: member,
                            title: 'Referral',
                            stageKey: 'referral',
                            programStage: familyPsReferral,
                            icon: Icons.handshake_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberGroup({
    required String title,
    required List<_HouseholdMember> members,
    required _CaseDetailData data,
  }) {
    if (members.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title,
            '${members.length} member${members.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: members.map((m) => _memberCard(data, m)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdDetails(_CaseDetailData data) {
    final household = data.household;

    final primary =
    data.householdMembers.where((m) => m.isPrimaryClient).toList();

    final caregivers = data.householdMembers
        .where(
          (m) =>
      !m.isPrimaryClient &&
          [
            'MOTHER',
            'FATHER',
            'CAREGIVER',
            'GUARDIAN',
            'PERSONAL_ASSISTANT'
          ].contains(m.role.toUpperCase()),
    )
        .toList();

    final others = data.householdMembers
        .where((m) => !primary.contains(m) && !caregivers.contains(m))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _heroCard(data),
        _householdSummary(data),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'Household Location',
                'Where this household is registered or located.',
              ),
              const SizedBox(height: 12),
              if (household == null || !household.hasAnyData)
                _emptyBox('No household information linked to this case yet.')
              else ...[
                _kv('File Number', household.fileNumber),
                _kv('Name', household.name),
                _kv('District', household.district),
                _kv('Council', household.communityCouncil),
                _kv('Village', household.village),
                _kv('Address', household.address),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.055),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.color.withOpacity(0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Household-level services',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Use this for goals that belong to the whole household, such as shelter, food security, documents, or family-wide support. Household-level service can be applied to all members where appropriate.',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 12.5, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip('Open HH goals: ${data.householdOpenGoals}',
                              color: Colors.deepPurple,
                              strong: data.householdOpenGoals > 0),
                          _chip('HH services: ${data.householdServices}',
                              color: Colors.teal,
                              strong: data.householdServices > 0),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _memberActionButton(
                          label: 'Household Services',
                          icon: Icons.home_repair_service_outlined,
                          onTap: () => _openHouseholdServices(data),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        _memberGroup(
          title: 'Primary Client',
          members: primary,
          data: data,
        ),
        _memberGroup(
          title: 'Caregivers and Key Support',
          members: caregivers,
          data: data,
        ),
        _memberGroup(
          title: 'Other Household Members',
          members: others,
          data: data,
        ),
      ],
    );
  }

  Widget _selectedBody(_CaseDetailData data) {
    if (_selectedTab == 1) return _buildHouseholdDetails(data);
    return _buildCaseDetails(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.color,
        title: const Text('Household Case'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_CaseDetailData>(
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
                      'Loading case details...',
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
                  Text(
                    'Failed to load case details: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              );
            }

            final data = snapshot.data!;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tabChip('Case Details', 0, Icons.folder_open_outlined),
                    _tabChip('Household Details', 1, Icons.home_work_outlined),
                  ],
                ),
                const SizedBox(height: 14),
                _selectedBody(data),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

