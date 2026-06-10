import 'package:sqflite/sqflite.dart';

class MgysdProgramStageEventHelper {
  static const String contextTable = 'mgysd_stage_event_context';

  static String rootCaseId(String id) {
    final parts = id.split('__');
    return parts.isNotEmpty ? parts.first : id;
  }

  static Future<bool> tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  static Future<Set<String>> tableColumns(Database db, String tableName) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');
    return rows.map((row) => (row['name'] ?? '').toString()).toSet();
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    Set<String> columns,
    String columnName,
  ) async {
    if (columns.contains(columnName)) return;

    try {
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName TEXT');
      columns.add(columnName);
    } catch (_) {
      // Ignore if SQLite reports the column already exists or the table cannot be altered.
    }
  }

  static Future<void> ensureContextTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $contextTable (
        eventId TEXT PRIMARY KEY,
        parentCaseId TEXT,
        stageKey TEXT,
        tableName TEXT,
        programStage TEXT,
        trackedEntityInstance TEXT,
        enrollment TEXT,
        householdTei TEXT,
        householdName TEXT,
        clientName TEXT,
        subjectName TEXT,
        subjectRole TEXT,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
  }

  static Future<void> ensureEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        event TEXT PRIMARY KEY,
        id TEXT,
        caseId TEXT,
        parentCaseId TEXT,
        rootCaseId TEXT,
        stageKey TEXT,
        trackedEntityInstance TEXT,
        enrollment TEXT,
        programStage TEXT,
        orgUnit TEXT,
        status TEXT,
        eventDate TEXT,
        date TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT
      )
    ''');

    final columns = await tableColumns(db, 'events');

    for (final column in const [
      'event',
      'id',
      'caseId',
      'parentCaseId',
      'rootCaseId',
      'stageKey',
      'trackedEntityInstance',
      'enrollment',
      'programStage',
      'orgUnit',
      'status',
      'eventDate',
      'date',
      'createdAt',
      'updatedAt',
      'syncStatus',
    ]) {
      await _addColumnIfMissing(db, 'events', columns, column);
    }
  }

  static Future<void> saveContext({
    required Database db,
    required String eventId,
    required String parentCaseId,
    required String stageKey,
    required String tableName,
    required String programStage,
    required String trackedEntityInstance,
    required String enrollment,
    String? householdTei,
    String? householdName,
    String? clientName,
    String? subjectName,
    String? subjectRole,
  }) async {
    await ensureContextTable(db);

    final now = DateTime.now().toIso8601String();

    await db.insert(
      contextTable,
      {
        'eventId': eventId,
        'parentCaseId': parentCaseId,
        'stageKey': stageKey,
        'tableName': tableName,
        'programStage': programStage,
        'trackedEntityInstance': trackedEntityInstance,
        'enrollment': enrollment,
        'householdTei': householdTei ?? '',
        'householdName': householdName ?? '',
        'clientName': clientName ?? '',
        'subjectName': subjectName ?? '',
        'subjectRole': subjectRole ?? '',
        'createdAt': now,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, String>> getContext({
    required Database db,
    required String eventId,
  }) async {
    await ensureContextTable(db);

    final rows = await db.query(
      contextTable,
      where: 'eventId = ?',
      whereArgs: [eventId],
      limit: 1,
    );

    if (rows.isEmpty) return <String, String>{};

    return rows.first.map(
      (key, value) => MapEntry(key, (value ?? '').toString()),
    );
  }

  static Future<void> saveProgramStageEvent({
    required Database db,
    required String eventId,
    required String status,
    required String eventDate,
    String? orgUnit,
  }) async {
    await ensureEventsTable(db);

    final context = await getContext(db: db, eventId: eventId);
    final parentCaseId = context['parentCaseId']?.trim().isNotEmpty == true
        ? context['parentCaseId']!.trim()
        : rootCaseId(eventId);

    final now = DateTime.now().toIso8601String();

    await db.insert(
      'events',
      {
        'event': eventId,
        'id': eventId,
        'caseId': eventId,
        'parentCaseId': parentCaseId,
        'rootCaseId': parentCaseId,
        'stageKey': context['stageKey'] ?? '',
        'trackedEntityInstance': context['trackedEntityInstance'] ?? '',
        'enrollment': context['enrollment'] ?? '',
        'programStage': context['programStage'] ?? '',
        'orgUnit': orgUnit ?? '',
        'status': status,
        'eventDate': eventDate,
        'date': eventDate,
        'createdAt': now,
        'updatedAt': now,
        'syncStatus': 'not-synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
