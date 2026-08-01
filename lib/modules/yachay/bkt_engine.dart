/// Bayesian Knowledge Tracing engine for per-subtopic mastery estimation.
///
/// Uses a 4-parameter BKT model to estimate latent knowledge P(L) separately
/// from observed performance. Conservative defaults prevent premature mastery:
/// students reach ≥0.90 only after multiple consecutive correct answers.
///
/// **Formula (correct answer)**:
///   P(L|correct) = P(L) + (1 − P(L)) × P(T)
///
/// **Formula (incorrect answer)**:
///   P(L|incorrect) = P(L)·(1−P(S)) / [P(L)·(1−P(S)) + (1−P(L))·P(G)]
///
/// | Param | Default | Meaning                               |
/// |-------|---------|---------------------------------------|
/// | P(L₀) | 0.0     | Prior knowledge probability            |
/// | P(T)  | 0.15    | Probability of learning per attempt    |
/// | P(G)  | 0.20    | Guess probability                      |
/// | P(S)  | 0.10    | Slip probability                       |
class BktEngine {
  BktEngine._();

  /// Prior knowledge probability — assumes student knows nothing initially.
  static const double pLearn0 = 0.0;

  /// Probability of transitioning from "not known" to "known" per attempt.
  static const double pTransit = 0.15;

  /// Probability of guessing correctly when the student does NOT know.
  static const double pGuess = 0.20;

  /// Probability of slipping (making an error) when the student DOES know.
  static const double pSlip = 0.10;

  /// P(L) threshold at which a topic is considered mastered.
  static const double masteryThreshold = 0.90;

  /// Updates the latent knowledge probability P(L) given an observation.
  ///
  /// [currentPL] is the current P(L) value (0.0–1.0).
  /// [correct] is `true` when the student answered correctly.
  ///
  /// Returns the updated P(L), clamped to [0.0, 1.0].
  static double updatePLearned(double currentPL, bool correct) {
    if (correct) {
      // P(L|correct) = P(L) + (1 − P(L)) × P(T)
      return (currentPL + (1.0 - currentPL) * pTransit).clamp(0.0, 1.0);
    } else {
      // P(L|incorrect) = P(L)·(1−P(S)) / [P(L)·(1−P(S)) + (1−P(L))·P(G)]
      final slipTerm = currentPL * (1.0 - pSlip);
      final guessTerm = (1.0 - currentPL) * pGuess;
      final denominator = slipTerm + guessTerm;
      if (denominator == 0.0) return 0.0;
      return (slipTerm / denominator).clamp(0.0, 1.0);
    }
  }

  /// Whether [pLearned] meets or exceeds the [masteryThreshold].
  static bool isMastered(double pLearned) {
    return pLearned >= masteryThreshold;
  }
}
