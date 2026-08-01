/// AI response performance metrics for streaming generation.
///
/// Computed from timing data collected during token-by-token generation.
/// All timing values are in seconds; speeds are tokens per second.
///
/// Mirrors the reference pattern from gemma-vision's `MessageStats`
/// (Proyecto referencia/gemma-vision/lib/chat_page/models/message_models.dart:61-74).
class MessageStats {
  /// Time from prompt submission to first generated token, in seconds.
  /// `null` if no token was ever produced (e.g., model failed immediately).
  final double? timeToFirstToken;

  /// Total wall-clock time from prompt submission to generation completion,
  /// in seconds.
  final double? totalLatency;

  /// Number of tokens generated in this response.
  final int tokenCount;

  /// Decode speed in tokens per second, measured from the first token onward.
  /// `null` if fewer than 2 tokens were generated (cannot compute a rate).
  final double? decodeSpeed;

  const MessageStats({
    this.timeToFirstToken,
    this.totalLatency,
    required this.tokenCount,
    this.decodeSpeed,
  });

  /// Computes [MessageStats] from raw timing data.
  ///
  /// All [DateTime] parameters use UTC for consistency.
  ///
  /// - [startTime]: wall-clock moment when prompt was submitted.
  /// - [firstTokenTime]: wall-clock moment when the first token arrived,
  ///   or `null` if no token was produced.
  /// - [endTime]: wall-clock moment when generation completed.
  /// - [tokenCount]: total tokens generated.
  factory MessageStats.compute({
    required DateTime startTime,
    DateTime? firstTokenTime,
    required DateTime endTime,
    required int tokenCount,
  }) {
    final totalLatencySec =
        endTime.difference(startTime).inMicroseconds / 1000000.0;

    double? ttft;
    if (firstTokenTime != null) {
      ttft = firstTokenTime.difference(startTime).inMicroseconds / 1000000.0;
    }

    double? decode;
    if (firstTokenTime != null && tokenCount > 1) {
      final decodeWindowSec =
          endTime.difference(firstTokenTime).inMicroseconds / 1000000.0;
      if (decodeWindowSec > 0) {
        decode = (tokenCount - 1) / decodeWindowSec;
      }
    }

    return MessageStats(
      timeToFirstToken: ttft,
      totalLatency: totalLatencySec,
      tokenCount: tokenCount,
      decodeSpeed: decode,
    );
  }
}
