# yachay-mastery Specification

> NEW capability: BKT-based student mastery tracking with persistent per-subtopic probabilities

## Purpose

Track what the student has truly mastered — not just what they've seen. Bayesian Knowledge Tracing (BKT) updates per-subtopic probability P(L) on each interaction, driving adaptive progression (N-03, N-15).

## Requirements

### Requirement: BKT Mastery Model

The system SHALL maintain a `student_mastery` SQLite table with per-subtopic BKT state: `topic_id`, `p_learned` (0.0–1.0), `attempts`, `correct_attempts`, `consecutive_correct`, `last_interaction`. A topic is "mastered" when `p_learned ≥ 0.90`.

| BKT Param | Default | Meaning |
|-----------|---------|---------|
| P(L₀) | 0.0 | Prior knowledge probability |
| P(T) | 0.15 | Probability of learning per attempt |
| P(G) | 0.20 | Guess probability |
| P(S) | 0.10 | Slip probability |

#### Scenario: First correct answer on new topic

- GIVEN student has never attempted `arit_nn_01a` (P(L)=0.0)
- WHEN `evaluar_respuesta("arit_nn_01a", correcta: true)` is called
- THEN P(L) MUST update using BKT formula: P(L) = P(L₀) + (1-P(L₀)) × P(T) = 0.15
- AND `attempts` MUST increment to 1
- AND `consecutive_correct` MUST be set to 1

#### Scenario: Three consecutive correct answers reach mastery

- GIVEN student has P(L)=0.70, consecutive_correct=2 on `arit_of_02a`
- WHEN another correct answer is recorded
- THEN P(L) MUST update to ≥0.90
- AND the topic MUST be marked as mastered
- AND `obtener_siguiente_tema()` MUST return the next unlocked topic

#### Scenario: Incorrect answer resets streak

- GIVEN student has consecutive_correct=2 on `arit_nn_01a`
- WHEN an incorrect answer is recorded
- THEN `consecutive_correct` MUST reset to 0
- AND P(L) MUST decrease via BKT slip formula

### Requirement: Tool `consultar_estado`

The tool `consultar_estado(tema: String)` SHALL query `student_mastery` and return `{p_learned, attempts, mastered, last_interaction}` for the given topic.

#### Scenario: Query mastered topic

- GIVEN `arit_nn_01a` has P(L)=0.93 in the database
- WHEN `consultar_estado("arit_nn_01a")` is called
- THEN it MUST return `{p_learned: 0.93, mastered: true, attempts: 5}`

### Requirement: Tool `evaluar_respuesta`

The tool `evaluar_respuesta(tema: String, correcta: bool)` SHALL invoke the BKT update, persist to SQLite, and return the updated state plus a pedagogically appropriate response.

#### Scenario: Gemma evaluates student answer

- GIVEN Gemma determines the student's answer to a fractions exercise is correct
- WHEN Gemma calls `evaluar_respuesta("arit_nn_01a", correcta: true)`
- THEN the BKT probability MUST be updated
- AND the new state MUST be persisted to `student_mastery`
- AND the tool result MUST return `{p_learned, mastered, mensaje: "¡Correcto! ..."}`

### Requirement: Mastery Persistence

Mastery state SHALL persist across app sessions via SQLCipher-encrypted SQLite. On app launch, `student_mastery` MUST be loaded into memory.

#### Scenario: App restart preserves mastery

- GIVEN a student mastered `arit_nn_01a` in a previous session
- WHEN the app launches again
- THEN `consultar_estado("arit_nn_01a")` MUST return `mastered: true`
- AND P(L) MUST match the last persisted value
