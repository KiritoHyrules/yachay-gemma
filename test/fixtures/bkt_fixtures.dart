/// Shared BKT test fixtures — constants and helpers used across
/// `bkt_engine_test.dart`, `student_state_mastery_test.dart`, and
/// future Yachay tool tests.
///
/// Centralising these values prevents test drift and makes BKT parameter
/// changes a single-point update.

import 'package:flutter_test/flutter_test.dart';
import 'package:aprendo_plus/core/models/topic_mastery.dart';
import 'package:aprendo_plus/modules/yachay/bkt_engine.dart';

// ---------------------------------------------------------------------------
// BKT progression expectations (P(L₀)=0 → mastery)
// ---------------------------------------------------------------------------

/// Expected P(L) after one correct answer from scratch.
const double bktStep1 = 0.15;

/// Expected P(L) after two consecutive correct answers from scratch.
const double bktStep2 = 0.2775;

/// Expected P(L) after three consecutive correct answers from scratch.
const double bktStep3 = 0.385875;

/// Expected P(L) when starting from 0.80 and answering correctly.
const double bktFrom80 = 0.83;

/// Expected P(L) when starting from 0.88 and answering correctly.
const double bktFrom88 = 0.898;

// ---------------------------------------------------------------------------
// Common test identifiers
// ---------------------------------------------------------------------------

const String testStudent1 = 'student-1';
const String testStudent2 = 'student-2';
const String testTopicNN = 'arit_nn_01a'; // Valor Posicional
const String testTopicFR = 'arit_fr_01a'; // Concepto de Fracción

// ---------------------------------------------------------------------------
// Mastery threshold boundary values
// ---------------------------------------------------------------------------

const double justBelowMastery = 0.89;
const double atMastery = 0.90;
const double justAboveMastery = 0.92;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Verifies that [mastery] has been updated correctly by BKT after [correct]
/// consecutive answers from a known [previousPL].
///
/// Checks `pLearned`, `attempts`, `correctAttempts`, and
/// `consecutiveCorrect` are consistent.
void expectBktUpdate({
  required TopicMastery mastery,
  required String expectedStudentId,
  required String expectedTopicId,
  required int expectedAttempts,
  required int expectedCorrect,
  required int expectedConsecutive,
  required double expectedPL,
  double delta = 0.001,
}) {
  expect(mastery.studentId, equals(expectedStudentId));
  expect(mastery.topicId, equals(expectedTopicId));
  expect(mastery.attempts, equals(expectedAttempts));
  expect(mastery.correctAttempts, equals(expectedCorrect));
  expect(mastery.consecutiveCorrect, equals(expectedConsecutive));
  expect(mastery.pLearned, closeTo(expectedPL, delta));
}

/// Convenience to compute expected P(L) after [n] consecutive correct
/// answers starting from [startPL].  Useful for triangulation and
/// longer chains.
double expectedPLAfterNCorrect(int n, {double startPL = 0.0}) {
  var pl = startPL;
  for (var i = 0; i < n; i++) {
    pl = BktEngine.updatePLearned(pl, true);
  }
  return pl;
}
