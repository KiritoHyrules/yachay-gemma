import 'package:flutter_test/flutter_test.dart';

// RED phase — production code does not exist yet (compile error = RED)
// ignore_for_file: unused_import
import 'package:aprendo_plus/core/models/topic_mastery.dart';

void main() {
  // ===========================================================================
  // TopicMastery — data model
  // ===========================================================================

  group('TopicMastery — constructor', () {
    test(
        'GIVEN required fields studentId and topicId '
        'WHEN constructing TopicMastery '
        'THEN object is created with default values for optional fields', () {
      const mastery = TopicMastery(
        studentId: 'student-1',
        topicId: 'arit_nn_01a',
      );

      expect(mastery.studentId, equals('student-1'));
      expect(mastery.topicId, equals('arit_nn_01a'));
      // Defaults
      expect(mastery.pLearned, equals(0.0));
      expect(mastery.attempts, equals(0));
      expect(mastery.correctAttempts, equals(0));
      expect(mastery.consecutiveCorrect, equals(0));
      expect(mastery.lastInteraction, isNull);
      expect(mastery.yachayRecomendacion, isNull);
    });
  });

  group('TopicMastery — toJson', () {
    test(
        'GIVEN a fully populated TopicMastery '
        'WHEN toJson is called '
        'THEN returns a map with all fields using snake_case keys', () {
      final lastInteraction = DateTime(2026, 7, 30, 12, 0);
      final mastery = TopicMastery(
        studentId: 'student-1',
        topicId: 'arit_of_02a',
        pLearned: 0.75,
        attempts: 4,
        correctAttempts: 3,
        consecutiveCorrect: 2,
        lastInteraction: lastInteraction,
        yachayRecomendacion: 'Practicar más ejercicios de suma.',
      );

      final json = mastery.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json['student_id'], equals('student-1'));
      expect(json['topic_id'], equals('arit_of_02a'));
      expect(json['p_learned'], closeTo(0.75, 0.001));
      expect(json['attempts'], equals(4));
      expect(json['correct_attempts'], equals(3));
      expect(json['consecutive_correct'], equals(2));
      expect(json['last_interaction'], equals(lastInteraction.toIso8601String()));
      expect(json['yachay_recomendacion'],
          equals('Practicar más ejercicios de suma.'));
    });

    test(
        'GIVEN a TopicMastery with null optional fields '
        'WHEN toJson is called '
        'THEN null fields are omitted from the map', () {
      const mastery = TopicMastery(
        studentId: 'student-1',
        topicId: 'arit_nn_01a',
      );

      final json = mastery.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json['student_id'], equals('student-1'));
      expect(json['topic_id'], equals('arit_nn_01a'));
      // Null fields should not appear
      expect(json.containsKey('last_interaction'), isFalse);
      expect(json.containsKey('yachay_recomendacion'), isFalse);
    });
  });

  group('TopicMastery — fromJson', () {
    test(
        'GIVEN a valid JSON map with all fields '
        'WHEN fromJson is called '
        'THEN recreates the TopicMastery correctly', () {
      final json = <String, dynamic>{
        'student_id': 'student-1',
        'topic_id': 'arit_of_02a',
        'p_learned': 0.85,
        'attempts': 5,
        'correct_attempts': 4,
        'consecutive_correct': 3,
        'last_interaction': '2026-07-30T12:00:00.000',
        'yachay_recomendacion': 'Buen progreso en operaciones.',
      };

      final mastery = TopicMastery.fromJson(json);

      expect(mastery.studentId, equals('student-1'));
      expect(mastery.topicId, equals('arit_of_02a'));
      expect(mastery.pLearned, closeTo(0.85, 0.001));
      expect(mastery.attempts, equals(5));
      expect(mastery.correctAttempts, equals(4));
      expect(mastery.consecutiveCorrect, equals(3));
      expect(mastery.lastInteraction, equals(DateTime(2026, 7, 30, 12, 0)));
      expect(
          mastery.yachayRecomendacion, equals('Buen progreso en operaciones.'));
    });

    test(
        'GIVEN a JSON map with only required fields '
        'WHEN fromJson is called '
        'THEN default values are applied for missing fields', () {
      final json = <String, dynamic>{
        'student_id': 'student-2',
        'topic_id': 'arit_nn_01a',
      };

      final mastery = TopicMastery.fromJson(json);

      expect(mastery.studentId, equals('student-2'));
      expect(mastery.topicId, equals('arit_nn_01a'));
      expect(mastery.pLearned, equals(0.0));
      expect(mastery.attempts, equals(0));
      expect(mastery.correctAttempts, equals(0));
      expect(mastery.consecutiveCorrect, equals(0));
      expect(mastery.lastInteraction, isNull);
      expect(mastery.yachayRecomendacion, isNull);
    });
  });

  group('TopicMastery — toJson/fromJson roundtrip', () {
    test(
        'GIVEN a TopicMastery with all fields set '
        'WHEN toJson then fromJson '
        'THEN produces an equal TopicMastery', () {
      final original = TopicMastery(
        studentId: 'student-3',
        topicId: 'arit_nn_01a',
        pLearned: 0.92,
        attempts: 6,
        correctAttempts: 5,
        consecutiveCorrect: 4,
        lastInteraction: DateTime(2026, 7, 30, 15, 30),
        yachayRecomendacion: null,
      );

      final roundtripped = TopicMastery.fromJson(original.toJson());

      expect(roundtripped.studentId, equals(original.studentId));
      expect(roundtripped.topicId, equals(original.topicId));
      expect(roundtripped.pLearned, closeTo(original.pLearned, 0.001));
      expect(roundtripped.attempts, equals(original.attempts));
      expect(roundtripped.correctAttempts, equals(original.correctAttempts));
      expect(roundtripped.consecutiveCorrect,
          equals(original.consecutiveCorrect));
      expect(roundtripped.lastInteraction, equals(original.lastInteraction));
      expect(roundtripped.yachayRecomendacion,
          equals(original.yachayRecomendacion));
    });

    test(
        'GIVEN a TopicMastery with null optional fields '
        'WHEN toJson then fromJson '
        'THEN roundtrip preserves nulls correctly', () {
      final original = TopicMastery(
        studentId: 'student-4',
        topicId: 'arit_new',
        pLearned: 0.10,
        attempts: 1,
        correctAttempts: 0,
        consecutiveCorrect: 0,
      );

      final roundtripped = TopicMastery.fromJson(original.toJson());

      expect(roundtripped.lastInteraction, isNull);
      expect(roundtripped.yachayRecomendacion, isNull);
      expect(roundtripped.pLearned, closeTo(0.10, 0.001));
      expect(roundtripped.attempts, equals(1));
    });
  });

  group('TopicMastery — copyWith', () {
    const original = TopicMastery(
      studentId: 'student-1',
      topicId: 'arit_nn_01a',
      pLearned: 0.50,
      attempts: 3,
      correctAttempts: 2,
      consecutiveCorrect: 1,
    );

    test(
        'GIVEN a TopicMastery '
        'WHEN copyWith is called without arguments '
        'THEN returns an equal but not identical copy', () {
      final copied = original.copyWith();

      expect(copied.studentId, equals(original.studentId));
      expect(copied.topicId, equals(original.topicId));
      expect(copied.pLearned, closeTo(original.pLearned, 0.001));
      expect(copied, isNot(same(original)));
    });

    test(
        'GIVEN a TopicMastery '
        'WHEN copyWith updates pLearned '
        'THEN only pLearned changes, other fields preserved', () {
      final updated = original.copyWith(pLearned: 0.65);

      expect(updated.pLearned, closeTo(0.65, 0.001));
      // Other fields unchanged
      expect(updated.studentId, equals(original.studentId));
      expect(updated.topicId, equals(original.topicId));
      expect(updated.attempts, equals(original.attempts));
      expect(updated.correctAttempts, equals(original.correctAttempts));
      expect(updated.consecutiveCorrect, equals(original.consecutiveCorrect));
    });

    test(
        'GIVEN a TopicMastery '
        'WHEN copyWith updates attempts and consecutiveCorrect '
        'THEN both fields update independently', () {
      final updated =
          original.copyWith(attempts: 4, consecutiveCorrect: 3);

      expect(updated.attempts, equals(4));
      expect(updated.consecutiveCorrect, equals(3));
      expect(updated.pLearned, closeTo(0.50, 0.001));
      expect(updated.correctAttempts, equals(original.correctAttempts));
    });

    test(
        'GIVEN a TopicMastery '
        'WHEN copyWith sets yachayRecomendacion to a value '
        'THEN the new field is set correctly', () {
      final updated = original.copyWith(
        yachayRecomendacion: 'Necesita más práctica en valor posicional.',
      );

      expect(updated.yachayRecomendacion,
          equals('Necesita más práctica en valor posicional.'));
      // Rest unchanged
      expect(updated.studentId, equals(original.studentId));
    });
  });
}
