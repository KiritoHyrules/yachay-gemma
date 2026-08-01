import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../database_service.dart';
import '../../models/lesson.dart';
import '../../models/exercise.dart';

class LessonRepository {
  final DatabaseService _dbService;

  LessonRepository(this._dbService);

  Future<Lesson?> getById(String id) async {
    final db = _dbService.database;
    if (db == null) return null;

    final rows = await db.query(
      'lesson_content',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _rowToLesson(rows.first);
  }

  Future<List<Lesson>> getBySubjectAndLevel(String subject, int level) async {
    final db = _dbService.database;
    if (db == null) return [];

    final rows = await db.query(
      'lesson_content',
      where: 'subject = ? AND difficulty_level <= ?',
      whereArgs: [subject, level],
      orderBy: 'difficulty_level ASC',
    );

    return rows.map(_rowToLesson).toList();
  }

  Future<List<Lesson>> getBySubject(String subject) async {
    final db = _dbService.database;
    if (db == null) return [];

    final rows = await db.query(
      'lesson_content',
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'difficulty_level ASC',
    );

    return rows.map(_rowToLesson).toList();
  }

  Future<List<Lesson>> getPrerequisites(String lessonId) async {
    final db = _dbService.database;
    if (db == null) return [];

    final rows = await db.query(
      'lesson_content',
      where: 'id = ?',
      whereArgs: [lessonId],
      columns: ['prerequisites_json'],
      limit: 1,
    );

    if (rows.isEmpty) return [];

    final prereqsJson = rows.first['prerequisites_json'] as String?;
    if (prereqsJson == null) return [];

    final prereqIds = (jsonDecode(prereqsJson) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    if (prereqIds.isEmpty) return [];

    final placeholders = prereqIds.map((_) => '?').join(',');
    final prereqRows = await db.rawQuery(
      'SELECT * FROM lesson_content WHERE id IN ($placeholders)',
      prereqIds,
    );

    return prereqRows.map(_rowToLesson).toList();
  }

  Future<List<Lesson>> getAllLessons() async {
    final db = _dbService.database;
    if (db == null) return [];

    final rows = await db.query(
      'lesson_content',
      orderBy: 'subject ASC, difficulty_level ASC',
    );

    return rows.map(_rowToLesson).toList();
  }

  Lesson _rowToLesson(Map<String, dynamic> row) {
    final exercisesJson = row['exercises_json'] as String? ?? '[]';
    final exercises = (jsonDecode(exercisesJson) as List<dynamic>)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();

    List<String>? prerequisites;
    if (row['prerequisites_json'] != null) {
      prerequisites = (jsonDecode(row['prerequisites_json'] as String) as List<dynamic>)
          .map((e) => e as String)
          .toList();
    }

    return Lesson(
      id: row['id'] as String,
      subject: row['subject'] as String,
      title: row['title'] as String,
      difficultyLevel: row['difficulty_level'] as int? ?? 1,
      videoPath: row['video_path'] as String?,
      explanationJson: row['explanation_json'] as String?,
      exercises: exercises,
      prerequisites: prerequisites,
    );
  }

}
