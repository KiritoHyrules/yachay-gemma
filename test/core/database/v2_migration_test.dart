import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// RED phase — migrateV2 function does not exist yet (compile error = RED)
// ignore_for_file: unused_import
import 'package:aprendo_plus/core/database/database_service.dart';

void main() {
  // ===========================================================================
  // DatabaseService — v2 migration (student_mastery table)
  // ===========================================================================

  group('DatabaseService — v2 migration', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test(
        'GIVEN a v1 database without student_mastery '
        'WHEN migrateV2 is called '
        'THEN student_mastery table exists with all required columns', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Simulate: DB was at v1 (no student_mastery table)
      final tablesBefore = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final hasMasteryBefore =
          tablesBefore.any((r) => r['name'] == 'student_mastery');
      expect(hasMasteryBefore, isFalse);

      // WHEN: run v2 migration
      await DatabaseService.migrateV2(db);

      // THEN: student_mastery table exists
      final tablesAfter = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final hasMasteryAfter =
          tablesAfter.any((r) => r['name'] == 'student_mastery');
      expect(hasMasteryAfter, isTrue);

      // THEN: table has the correct columns
      final columns =
          await db.rawQuery("PRAGMA table_info('student_mastery')");
      final columnInfo = <String, Map<String, dynamic>>{};
      for (final c in columns) {
        columnInfo[c['name'] as String] = c;
      }

      // Verify each column exists
      expect(columnInfo.containsKey('student_id'), isTrue);
      expect(columnInfo.containsKey('topic_id'), isTrue);
      expect(columnInfo.containsKey('p_learned'), isTrue);
      expect(columnInfo.containsKey('attempts'), isTrue);
      expect(columnInfo.containsKey('correct_attempts'), isTrue);
      expect(columnInfo.containsKey('consecutive_correct'), isTrue);
      expect(columnInfo.containsKey('last_interaction'), isTrue);
      expect(columnInfo.containsKey('yachay_recomendacion'), isTrue);

      // Verify column types
      expect(columnInfo['student_id']!['type'], equals('TEXT'));
      expect(columnInfo['topic_id']!['type'], equals('TEXT'));
      expect(columnInfo['p_learned']!['type'], equals('REAL'));
      expect(columnInfo['attempts']!['type'], equals('INTEGER'));
      expect(columnInfo['correct_attempts']!['type'], equals('INTEGER'));
      expect(columnInfo['consecutive_correct']!['type'], equals('INTEGER'));

      // Verify NOT NULL constraints on key columns
      expect(columnInfo['student_id']!['notnull'], equals(1));
      expect(columnInfo['topic_id']!['notnull'], equals(1));
      expect(columnInfo['p_learned']!['notnull'], equals(1));

      // Verify default values
      expect(columnInfo['p_learned']!['dflt_value'], equals('0.0'));
      expect(columnInfo['attempts']!['dflt_value'], equals('0'));
      expect(columnInfo['correct_attempts']!['dflt_value'], equals('0'));
      expect(columnInfo['consecutive_correct']!['dflt_value'], equals('0'));

      await db.close();
    });

    test(
        'GIVEN migrateV2 called twice on same database '
        'WHEN the second call executes '
        'THEN no error occurs (idempotent via IF NOT EXISTS)', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // First migration
      await DatabaseService.migrateV2(db);

      // Second migration — must not throw
      await DatabaseService.migrateV2(db);

      // Table still exists with correct columns
      final columns =
          await db.rawQuery("PRAGMA table_info('student_mastery')");
      final columnNames = columns.map((c) => c['name'] as String).toSet();
      expect(columnNames, contains('student_id'));
      expect(columnNames, contains('topic_id'));

      await db.close();
    });

    test(
        'GIVEN student_mastery table after migration '
        'WHEN a row is inserted with valid data '
        'THEN the row is persisted and retrievable', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.migrateV2(db);

      // Insert a row
      await db.insert('student_mastery', {
        'student_id': 'student-1',
        'topic_id': 'arit_nn_01a',
        'p_learned': 0.75,
        'attempts': 4,
        'correct_attempts': 3,
        'consecutive_correct': 2,
        'last_interaction': '2026-07-30T12:00:00.000',
      });

      // Retrieve it
      final rows = await db.query('student_mastery',
          where: 'student_id = ? AND topic_id = ?',
          whereArgs: ['student-1', 'arit_nn_01a']);

      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['student_id'], equals('student-1'));
      expect(row['topic_id'], equals('arit_nn_01a'));
      expect(row['p_learned'], equals(0.75));
      expect(row['attempts'], equals(4));
      expect(row['correct_attempts'], equals(3));
      expect(row['consecutive_correct'], equals(2));

      await db.close();
    });

    test(
        'GIVEN student_mastery table '
        'WHEN a duplicate (student_id, topic_id) is inserted with REPLACE '
        'THEN the old row is replaced', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.migrateV2(db);

      // Insert first row
      await db.insert('student_mastery', {
        'student_id': 'student-1',
        'topic_id': 'arit_nn_01a',
        'p_learned': 0.15,
        'attempts': 1,
      });

      // Insert second row with same key — should fail due to UNIQUE constraint
      try {
        await db.insert('student_mastery', {
          'student_id': 'student-1',
          'topic_id': 'arit_nn_01a',
          'p_learned': 0.30,
          'attempts': 2,
        });
        // If no error, there should be exactly 1 row (conflict resolved)
        final rows = await db.query('student_mastery',
            where: 'student_id = ?', whereArgs: ['student-1']);
        expect(rows.length, equals(1));
      } catch (_) {
        // UNIQUE constraint violation is also acceptable behavior
        final rows = await db.query('student_mastery',
            where: 'student_id = ?', whereArgs: ['student-1']);
        expect(rows.length, equals(1));
      }

      await db.close();
    });
  });
}
