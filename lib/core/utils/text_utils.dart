/// Lightweight response truncation for educational chat output.
///
/// Truncates [text] at the last complete sentence boundary using only native
/// [String] methods — **zero RegExp**. Priority: `'. '` > `'.'` > `'!'` > `'?'`.
///
/// If no sentence-ending punctuation is found, returns the full text unchanged.
/// This is safe for all Unicode input including emoji and accented characters
/// because it operates on code-unit offsets of literal ASCII delimiters.

String truncateAtSentence(String text) {
  if (text.isEmpty) return text;

  // Priority 1: '. ' (period-space — strongest sentence boundary).
  int idx = text.lastIndexOf('. ');
  if (idx > 0) return text.substring(0, idx + 1);

  // Priority 2: '.' (period at end of sentence).
  idx = text.lastIndexOf('.');
  if (idx > 0) return text.substring(0, idx + 1);

  // Priority 3: '!' (exclamation).
  idx = text.lastIndexOf('!');
  if (idx > 0) return text.substring(0, idx + 1);

  // Priority 4: '?' (question mark).
  idx = text.lastIndexOf('?');
  if (idx > 0) return text.substring(0, idx + 1);

  // No sentence-ending punctuation found — return full text.
  return text;
}
