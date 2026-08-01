/// Pure Dart keyword-overlap scorer for curriculum-topic matching.
///
/// Uses Spanish stop-word filtering and token overlap to match student messages
/// against [TemaPrimaria] entries from [Curricula4toPrimaria].
///
/// No Flutter dependencies. No file I/O. Deterministic.
library;

import '../../core/data/learning_data.dart';

class TopicMatcher {
  TopicMatcher._();

  /// Spanish stop words filtered out before matching.
  static const _stopWords = {
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'de',
    'del',
    'que',
    'y',
    'o',
    'a',
    'en',
    'por',
    'para',
    'con',
    'sin',
    'es',
    'no',
    'sí',
    'si',
    'me',
    'te',
    'se',
    'lo',
    'le',
    'mi',
    'tu',
    'su',
    'qué',
    'cómo',
    'cuál',
    'porque',
    'cuando',
    'donde',
    'quiero',
    'dame',
    'ejemplo',
    'ejercicio',
    'practicar',
    'seguir',
    'otro',
    'tema',
    'más',
    'simple',
  };

  /// Splits [text] into lowercase tokens, stripping common Spanish
  /// punctuation (¿ ? ¡ ! . , ; : ( ) " - –).
  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[¿?¡!.,;:()"\-\–]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Returns the best matching [TemaPrimaria] for the given [message],
  /// or `null` if no topic matches.
  ///
  /// The message is tokenized and stop words are removed. For each topic
  /// in [topics], titulo and chips are tokenized and the overlap with the
  /// message tokens is counted. A topic matches when ≥ 2 tokens overlap.
  /// The topic with the highest overlap is returned.
  static TemaPrimaria? findMatchingTopic(
    String message,
    List<TemaPrimaria> topics,
  ) {
    final messageTokens =
        _tokenize(message).where((t) => !_stopWords.contains(t)).toList();

    TemaPrimaria? bestMatch;
    int bestOverlap = 0;

    for (final topic in topics) {
      // Build keyword set from titulo + chips.
      final topicTokens = <String>{
        ..._tokenize(topic.titulo),
        for (final chip in topic.chips) ..._tokenize(chip),
      };

      final overlap =
          messageTokens.where((mt) => topicTokens.contains(mt)).length;

      if (overlap >= 1 && overlap > bestOverlap) {
        bestOverlap = overlap;
        bestMatch = topic;
      }
    }

    return bestMatch;
  }

  /// Returns `true` if the message has no curriculum topic matches
  /// AND is long enough to be considered a real message (≥ 4 tokens
  /// after stop-word filtering).
  ///
  /// Short messages (like "sí", "no", "ok") are exempt and always
  /// return `false`.
  static bool isOffTopic(
    String message,
    List<TemaPrimaria> topics,
  ) {
    final tokens =
        _tokenize(message).where((t) => !_stopWords.contains(t)).toList();

    // Too short to judge — exempt from off-topic flag.
    if (tokens.length < 2) return false;

    return findMatchingTopic(message, topics) == null;
  }
}
