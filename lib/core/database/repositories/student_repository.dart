import 'package:sqflite_sqlcipher/sqflite.dart';

import '../database_service.dart';
import '../../models/student_profile.dart';
import '../../models/diagnostic_result.dart';

class StudentRepository {
  final DatabaseService _dbService;

  StudentRepository(this._dbService);

  Future<StudentProfile?> loadProfile(String id) async {
    final db = _dbService.database;
    if (db == null) return null;

    final rows = await db.query(
      'student_profile',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return StudentProfile.fromJson(rows.first);
  }

  Future<void> saveProfile(StudentProfile profile) async {
    final db = _dbService.database;
    if (db == null) return;

    await db.insert(
      'student_profile',
      profile.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMathLevel(String id, int level) async {
    final db = _dbService.database;
    if (db == null) return;

    await db.update(
      'student_profile',
      {'math_level': level},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateReadingLevel(String id, int level) async {
    final db = _dbService.database;
    if (db == null) return;

    await db.update(
      'student_profile',
      {'reading_level': level},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCurrentLesson(String id, String? lessonId) async {
    final db = _dbService.database;
    if (db == null) return;

    await db.update(
      'student_profile',
      {'current_lesson': lessonId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDiagnosticResult(
    String id,
    DiagnosticResult result,
  ) async {
    final db = _dbService.database;
    if (db == null) return;

    await db.update(
      'student_profile',
      {
        'theta': result.theta,
        'nivel': result.nivel,
        'diagnostic_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTotalTime(String id, int additionalMinutes) async {
    final db = _dbService.database;
    if (db == null) return;

    await db.rawUpdate(
      'UPDATE student_profile SET total_time_min = total_time_min + ? WHERE id = ?',
      [additionalMinutes, id],
    );
  }

  Future<void> updateSyncTimestamp(String id) async {
    final db = _dbService.database;
    if (db == null) return;

    await db.update(
      'student_profile',
      {'last_sync_ts': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
