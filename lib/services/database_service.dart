// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/visitor_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'psa_visitors.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE visitor_logs (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        visitor_id     TEXT NOT NULL,
        visitor_name   TEXT NOT NULL,
        purpose        TEXT NOT NULL,
        agency         TEXT NOT NULL,
        visitor_type   TEXT NOT NULL DEFAULT 'individual',
        group_count    INTEGER,
        guard_on_duty  TEXT NOT NULL,
        unit_id        TEXT NOT NULL DEFAULT 'unknown',
        check_in_time  TEXT NOT NULL,
        check_out_time TEXT,
        is_active      INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_visitor_id ON visitor_logs(visitor_id)');
    await db.execute('CREATE INDEX idx_is_active  ON visitor_logs(is_active)');
    await db.execute('CREATE INDEX idx_unit_id    ON visitor_logs(unit_id)');
  }

  /// Migrate v1 → v2: add unit_id column if upgrading from old build
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE visitor_logs ADD COLUMN unit_id TEXT NOT NULL DEFAULT 'unknown'");
    }
  }

  // ── Core operations ────────────────────────────────────────────────────────

  Future<VisitorRecord?> getActiveVisit(String visitorId) async {
    final db = await database;
    final results = await db.query(
      'visitor_logs',
      where: 'visitor_id = ? AND is_active = 1',
      whereArgs: [visitorId],
      orderBy: 'check_in_time DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return VisitorRecord.fromMap(results.first);
  }

  Future<int> checkIn(VisitorRecord record) async {
    final db = await database;
    return await db.insert('visitor_logs', record.toMap());
  }

  Future<int> checkOut(int recordId, DateTime checkOutTime) async {
    final db = await database;
    return await db.update(
      'visitor_logs',
      {
        'check_out_time': checkOutTime.toIso8601String(),
        'is_active': 0,
      },
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Future<List<VisitorRecord>> getAllRecords({int limit = 500}) async {
    final db = await database;
    final results = await db.query(
      'visitor_logs',
      orderBy: 'check_in_time DESC',
      limit: limit,
    );
    return results.map((r) => VisitorRecord.fromMap(r)).toList();
  }

  Future<List<VisitorRecord>> getTodayRecords() async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));

    final results = await db.query(
      'visitor_logs',
      where: 'check_in_time >= ? AND check_in_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'check_in_time DESC',
    );
    return results.map((r) => VisitorRecord.fromMap(r)).toList();
  }

  /// Records for a specific month — used for consolidation
  Future<List<VisitorRecord>> getMonthRecords(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1);
    final end   = DateTime(year, month + 1, 1);

    final results = await db.query(
      'visitor_logs',
      where: 'check_in_time >= ? AND check_in_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'check_in_time ASC',
    );
    return results.map((r) => VisitorRecord.fromMap(r)).toList();
  }

  Future<List<VisitorRecord>> getYearRecords(int year) async {
    final db    = await database;
    final start = DateTime(year, 1, 1);
    final end   = DateTime(year + 1, 1, 1);

    final results = await db.query(
      'visitor_logs',
      where: 'check_in_time >= ? AND check_in_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'check_in_time ASC',
    );
    return results.map((r) => VisitorRecord.fromMap(r)).toList();
  }

  Future<int> getTodayCount() async =>
      (await getTodayRecords()).length;

  Future<int> getActiveCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM visitor_logs WHERE is_active = 1');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}