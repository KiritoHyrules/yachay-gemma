import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../keystore/keystore_service.dart';

export 'package:sqflite_sqlcipher/sqflite.dart' show Database;

class DatabaseService {
  static Database? _database;
  static String? _dbPassword;

  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? get database => _database;

  Future<Database> initialize() async {
    if (_database != null) return _database!;

    final password = await _resolvePassword();
    _dbPassword = password;

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = '${appDir.path}/aprendo_plus.db';

    _database = await openDatabase(
      dbPath,
      password: password,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );

    await _seedContentIfNeeded();

    return _database!;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA cipher_memory_security = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE student_profile (
        id TEXT PRIMARY KEY,
        alias TEXT NOT NULL,
        diagnostic_date TEXT NOT NULL,
        math_level INTEGER NOT NULL DEFAULT 1,
        reading_level INTEGER NOT NULL DEFAULT 1,
        current_lesson TEXT,
        total_time_min INTEGER NOT NULL DEFAULT 0,
        last_sync_ts TEXT,
        theta REAL NOT NULL DEFAULT 0.0,
        nivel INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE interaction_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        response TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        error_type TEXT,
        time_spent_sec INTEGER NOT NULL DEFAULT 0,
        gemma_used INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE lesson_content (
        id TEXT PRIMARY KEY,
        subject TEXT NOT NULL,
        title TEXT NOT NULL,
        difficulty_level INTEGER NOT NULL DEFAULT 1,
        video_path TEXT,
        explanation_json TEXT,
        exercises_json TEXT NOT NULL DEFAULT '[]',
        prerequisites_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE generated_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id TEXT NOT NULL,
        enunciado TEXT NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'opcion_multiple',
        respuesta_correcta TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES lesson_content(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_interaction_sync
      ON interaction_log(sync_status, timestamp)
    ''');

    // Run v2 migration for brand-new databases (version goes 1→2 via onUpgrade)
    // but in case of a direct v2 creation, also create the table.
    await DatabaseService.migrateV2(db);
    // Also create v3 table for brand-new v3 databases.
    await DatabaseService.migrateV3(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await DatabaseService.migrateV2(db);
    }
    if (oldVersion < 3) {
      await DatabaseService.migrateV3(db);
    }
  }

  /// Creates the `student_mastery` table if it does not already exist.
  ///
  /// Idempotent via `CREATE TABLE IF NOT EXISTS`. Called from both
  /// `onUpgrade` (v1→v2) and `_onCreate` (brand-new databases).
  static Future<void> migrateV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_mastery (
        student_id TEXT NOT NULL,
        topic_id TEXT NOT NULL,
        p_learned REAL NOT NULL DEFAULT 0.0,
        attempts INTEGER NOT NULL DEFAULT 0,
        correct_attempts INTEGER NOT NULL DEFAULT 0,
        consecutive_correct INTEGER NOT NULL DEFAULT 0,
        last_interaction TEXT,
        yachay_recomendacion TEXT,
        PRIMARY KEY (student_id, topic_id),
        FOREIGN KEY (student_id) REFERENCES student_profile(id)
      )
    ''');
  }

  /// Creates the `oom_checkpoint` table for OOM recovery (v3 migration).
  ///
  /// Stores pre-inference checkpoints so that, if the native OOM killer
  /// terminates the process during inference, the app can recover the last
  /// user message on next start and display a graceful fallback.
  ///
  /// Idempotent via `CREATE TABLE IF NOT EXISTS`.
  static Future<void> migrateV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS oom_checkpoint (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        user_message TEXT NOT NULL,
        system_prompt TEXT,
        timestamp TEXT NOT NULL,
        pending_tool TEXT,
        recovered INTEGER NOT NULL DEFAULT 0,
        recovery_response TEXT
      )
    ''');
  }

  Future<void> _seedContentIfNeeded() async {
    final db = _database;
    if (db == null) return;

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM lesson_content'),
    );

    if (count != null && count > 0) return;

    try {
      final lessonsJson = await rootBundle.loadString('assets/data/lessons.json');
      final lessons = jsonDecode(lessonsJson) as List<dynamic>;

      final batch = db.batch();
      for (final l in lessons) {
        final lesson = l as Map<String, dynamic>;
        batch.insert('lesson_content', {
          'id': lesson['id'],
          'subject': lesson['subject'] ?? lesson['area'],
          'title': lesson['title'] ?? lesson['titulo'],
          'difficulty_level': lesson['difficulty_level'] ?? lesson['dificultad'] ?? 1,
          'video_path': lesson['video_path'] ?? lesson['video_url'],
          'explanation_json': lesson['explanation_json'] != null
              ? jsonEncode(lesson['explanation_json'])
              : null,
          'exercises_json': lesson['exercises'] != null
              ? jsonEncode(lesson['exercises'])
              : jsonEncode(lesson['pasos'] ?? []),
          'prerequisites_json': lesson['prerequisites'] != null
              ? jsonEncode(lesson['prerequisites'])
              : null,
        });
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // Assets not available yet — will seed when assets are added
      // Graceful fallback: no content seeded
    }

    try {
      final itemsJson = await rootBundle.loadString('assets/data/item_bank.json');
      final items = jsonDecode(itemsJson) as List<dynamic>;

      final batch = db.batch();
      for (final i in items) {
        final item = i as Map<String, dynamic>;
        batch.insert('lesson_content', {
          'id': 'item_${item['id']}',
          'subject': item['area'] ?? 'general',
          'title': item['enunciado'] ?? '',
          'difficulty_level': item['dificultad'] ?? 1,
          'video_path': null,
          'explanation_json': jsonEncode(item),
          'exercises_json': '[]',
          'prerequisites_json': null,
        });
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // Diagnostic items not yet available — graceful fallback
    }
  }

  Future<String> _resolvePassword() async {
    final keystore = KeystoreService.instance;
    final storedKey = await keystore.getKey();

    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }

    final derivedKey = _deriveFallbackKey();
    await keystore.storeKey(derivedKey);
    return derivedKey;
  }

  String _deriveFallbackKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
