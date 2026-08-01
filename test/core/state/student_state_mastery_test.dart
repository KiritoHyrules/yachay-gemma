import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// RED phase — masteryMap, actualizarMastery, cargarMastery don't exist yet
// ignore_for_file: unused_import
import 'package:aprendo_plus/core/state/student_state.dart';
import 'package:aprendo_plus/core/database/database_service.dart';
import 'package:aprendo_plus/core/models/topic_mastery.dart';
import 'package:aprendo_plus/modules/yachay/bkt_engine.dart';

import '../../fixtures/bkt_fixtures.dart';

void main() {
  // ===========================================================================
  // StudentState — mastery tracking (BKT integration)
  // ===========================================================================

  group('StudentState — mastery API', () {
    test(
        'GIVEN StudentState instance (no DB init) '
        'WHEN masteryMap is accessed '
        'THEN returns a Map<String, TopicMastery> (initially empty)', () {
      final state = StudentState(DatabaseService.instance);
      final map = state.masteryMap;

      expect(map, isA<Map<String, TopicMastery>>());
      expect(map, isEmpty);
    });

    test(
        'GIVEN StudentState instance '
        'WHEN cargarMastery is called '
        'THEN method exists (async, takes String id, no throw on null DB)', () async {
      final state = StudentState(DatabaseService.instance);
      await state.cargarMastery('student-1');
      // No exception — graceful null check when DB not initialized
    });
  });

  group('StudentState — actualizarMastery (in-memory BKT track)', () {
    test(
        'GIVEN a StudentState with empty mastery map '
        'WHEN actualizarMastery("student-1", "arit_nn_01a", true) '
        'THEN mastery map has TopicMastery with pLearned=0.15', () async {
      final state = StudentState(DatabaseService.instance);

      await state.actualizarMastery(testStudent1, testTopicNN, true);

      final mastery = state.masteryMap['$testStudent1|$testTopicNN'];
      expect(mastery, isNotNull);
      expectBktUpdate(
        mastery: mastery!,
        expectedStudentId: testStudent1,
        expectedTopicId: testTopicNN,
        expectedAttempts: 1,
        expectedCorrect: 1,
        expectedConsecutive: 1,
        expectedPL: bktStep1,
      );
    });

    test(
        'GIVEN mastery at P(L)=0.15 for arit_nn_01a '
        'WHEN another correct answer is recorded '
        'THEN P(L) increases to ~0.2775 and streaks increment', () async {
      final state = StudentState(DatabaseService.instance);

      await state.actualizarMastery(testStudent1, testTopicNN, true);
      await state.actualizarMastery(testStudent1, testTopicNN, true);

      final mastery = state.masteryMap['$testStudent1|$testTopicNN'];
      expect(mastery, isNotNull);
      expectBktUpdate(
        mastery: mastery!,
        expectedStudentId: testStudent1,
        expectedTopicId: testTopicNN,
        expectedAttempts: 2,
        expectedCorrect: 2,
        expectedConsecutive: 2,
        expectedPL: bktStep2,
      );
    });

    test(
        'GIVEN mastery with consecutive_correct=2 '
        'WHEN an incorrect answer is recorded '
        'THEN consecutive_correct resets to 0', () async {
      final state = StudentState(DatabaseService.instance);

      await state.actualizarMastery(testStudent1, testTopicNN, true);
      await state.actualizarMastery(testStudent1, testTopicNN, true);
      await state.actualizarMastery(testStudent1, testTopicNN, false);

      final mastery = state.masteryMap['$testStudent1|$testTopicNN'];
      expect(mastery, isNotNull);
      expect(mastery!.attempts, equals(3));
      expect(mastery.correctAttempts, equals(2));
      expect(mastery.consecutiveCorrect, equals(0));
    });

    test(
        'GIVEN two different topics '
        'WHEN actualizarMastery is called for each '
        'THEN mastery map tracks them independently', () async {
      final state = StudentState(DatabaseService.instance);

      await state.actualizarMastery(testStudent1, testTopicNN, true);
      await state.actualizarMastery(testStudent1, testTopicFR, true);

      expect(state.masteryMap.length, equals(2));
      expect(state.masteryMap.containsKey('$testStudent1|$testTopicNN'), isTrue);
      expect(state.masteryMap.containsKey('$testStudent1|$testTopicFR'), isTrue);
    });

    test(
        'GIVEN a StudentState '
        'WHEN actualizarMastery is called '
        'THEN notifyListeners is triggered', () async {
      final state = StudentState(DatabaseService.instance);
      var notified = false;
      state.addListener(() {
        notified = true;
      });

      await state.actualizarMastery(testStudent1, testTopicNN, true);

      expect(notified, isTrue);
    });

    test(
        'GIVEN a StudentState '
        'WHEN actualizarMastery records a correct answer '
        'THEN lastInteraction is updated', () async {
      final state = StudentState(DatabaseService.instance);

      await state.actualizarMastery(testStudent2, testTopicNN, true);

      final mastery = state.masteryMap['$testStudent2|$testTopicNN'];
      expect(mastery, isNotNull);
      expect(mastery!.lastInteraction, isNotNull);
      final delta = DateTime.now().difference(mastery.lastInteraction!);
      expect(delta.inSeconds, lessThan(10));
    });
  });
}
