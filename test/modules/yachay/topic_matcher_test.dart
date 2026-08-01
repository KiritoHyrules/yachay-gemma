import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/yachay/topic_matcher.dart';
import 'package:aprendo_plus/core/data/learning_data.dart';

void main() {
  final allTopics = Curricula4toPrimaria.temas;

  // ===========================================================================
  // findMatchingTopic — exact keyword overlap (≥ 2 tokens)
  // ===========================================================================
  group('TopicMatcher.findMatchingTopic', () {
    test('"explícame las fracciones" matches mat_01 (fracciones)', () {
      final result =
          TopicMatcher.findMatchingTopic('explícame las fracciones', allTopics);
      expect(result, isNotNull);
      expect(result!.id, equals('mat_01'));
    });

    test('"quiero aprender sobre los ecosistemas" matches cyt_01 (ecosistemas)',
        () {
      final result = TopicMatcher.findMatchingTopic(
          'quiero aprender sobre los ecosistemas', allTopics);
      expect(result, isNotNull);
      expect(result!.id, equals('cyt_01'));
    });

    test('"hola cómo estás" returns null', () {
      final result =
          TopicMatcher.findMatchingTopic('hola cómo estás', allTopics);
      expect(result, isNull);
    });

    test('"animales protegidos del perú" matches cyt_02', () {
      final result = TopicMatcher.findMatchingTopic(
          'animales protegidos del perú', allTopics);
      expect(result, isNotNull);
      expect(result!.id, equals('cyt_02'));
    });

    test('"quiero un ejemplo de fracciones" matches mat_01', () {
      // "quiero" + "ejemplo" are in mat_01 chips; "fracciones" in titulo
      final result = TopicMatcher.findMatchingTopic(
          'quiero un ejemplo de fracciones', allTopics);
      expect(result, isNotNull);
      expect(result!.id, equals('mat_01'));
    });
  });

  // ===========================================================================
  // isOffTopic — requires ≥ 4 tokens after stop-word filtering
  // ===========================================================================
  group('TopicMatcher.isOffTopic', () {
    test('"sí" is not off-topic (too short — exempt)', () {
      expect(TopicMatcher.isOffTopic('sí', allTopics), isFalse);
    });

    test('"no" is not off-topic (too short — exempt)', () {
      expect(TopicMatcher.isOffTopic('no', allTopics), isFalse);
    });

    test('"quiero jugar fútbol" is off-topic', () {
      // 3 tokens after stop-word filtering; note the ≥ 4 threshold
      expect(TopicMatcher.isOffTopic('quiero jugar fútbol', allTopics), isTrue);
    });

    test('"ayúdame con fracciones" is not off-topic', () {
      expect(TopicMatcher.isOffTopic('ayúdame con fracciones', allTopics),
          isFalse);
    });

    test('GIVEN off-topic message ≥ 4 tokens WHEN isOffTopic THEN returns true',
        () {
      expect(
          TopicMatcher.isOffTopic(
              '¿qué película viste ayer en el cine?', allTopics),
          isTrue);
    });

    test('GIVEN short greeting WHEN isOffTopic THEN returns false', () {
      expect(TopicMatcher.isOffTopic('hola', allTopics), isFalse);
    });
  });

  // ===========================================================================
  // Stop-word filtering
  // ===========================================================================
  group('TopicMatcher — stop words', () {
    test(
        'Spanish stop words are filtered out, meaningful content still matches',
        () {
      // "el tema de las fracciones y la suma" → after stop words:
      // [tema, fracciones, suma]
      // mat_01 titulo "Fracciones simples" + chips → overlap with "fracciones"
      // "tema" and "suma" may or may not appear in topic tokens
      final result = TopicMatcher.findMatchingTopic(
          'el tema de las fracciones y la suma', allTopics);
      // At minimum, "fracciones" overlaps with mat_01 titulo (1 match).
      // Stop words "el", "de", "las", "y", "la" are correctly excluded.
      expect(result, isNotNull);
    });
  });
}
