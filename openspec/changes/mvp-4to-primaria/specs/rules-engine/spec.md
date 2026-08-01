# rules-engine Specification

## Purpose

Pure-Dart rules engine: dynamic tone adaptation from `StudentState.masteryMap` and streak-based pedagogical intervention. Zero inference, <5ms latency (N-03).

## Requirements

### Requirement: ToneAdapter — Mastery-Driven Tone

The system MUST adjust chat system message tone based on `StudentState.masteryMap` for the current topic, using only Dart if/else — no network, no model inference.

| Mastery Range | Tone |
|---------------|------|
| pLearned < 0.40 | Encouraging, simplified language |
| 0.40 ≤ pLearned < 0.80 | Neutral, supportive |
| pLearned ≥ 0.80 | Challenging, precise |
| consecutiveFailures ≥ 3 | Simplified encouragement (overrides pLearned) |

#### Scenario: Low mastery triggers encouragement

- GIVEN current topic pLearned=0.25, consecutiveCorrect=0
- WHEN ToneAdapter generates system message prefix
- THEN it MUST include encouraging phrasing
- AND language complexity MUST be simplified

#### Scenario: High mastery triggers challenge tone

- GIVEN current topic pLearned=0.88, consecutiveCorrect=5
- WHEN ToneAdapter generates system message prefix
- THEN it MUST use challenging framing
- AND vocabulary MUST match grade-appropriate challenge level

#### Scenario: Consecutive failures override mastery

- GIVEN current topic pLearned=0.70, consecutiveFailures=4
- WHEN ToneAdapter generates system message prefix
- THEN the tone MUST be simplified encouragement regardless of pLearned

### Requirement: DevilsAdvocate — Streak-Based Intervention

The system MUST inject trick questions or analogy-based re-explanations based on answer streaks. DevAdvocate SHALL NOT invoke Gemma inference — pure Dart logic.

#### Scenario: Trick question on correct streak

- GIVEN consecutiveCorrect ≥ 3 for current topic
- WHEN a new chat turn begins
- THEN DevilsAdvocate MUST generate a trick question at +1 difficulty
- AND the question MUST target a common misconception

#### Scenario: Analogy on failure streak

- GIVEN consecutiveFailures ≥ 3 for current topic
- WHEN a new chat turn begins
- THEN DevilsAdvocate MUST suggest an analogy-based re-explanation
- AND the analogy MUST use concrete, kid-friendly references

#### Scenario: Normal streak — no intervention

- GIVEN consecutiveCorrect < 3 AND consecutiveFailures < 3
- WHEN a new chat turn begins
- THEN DevilsAdvocate MUST NOT inject any intervention
