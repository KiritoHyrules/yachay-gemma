# Delta for yachay-mastery

## MODIFIED Requirements

### Requirement: Mastery Model

The system SHALL maintain a `student_mastery` SQLite table with per-topic state: `topic_id`, `p_learned` (0.0–1.0), `attempts`, `correct_attempts`, `consecutive_correct`, `last_interaction`. Mastery SHALL be computed as `pLearned = correctAttempts / max(attempts, 1)`. A topic is "mastered" when `pLearned ≥ 0.80`.

(Previously: Bayesian Knowledge Tracing with P(L₀)=0.0, P(T)=0.15, P(G)=0.20, P(S)=0.10; mastery threshold was 0.90.)

#### Scenario: First correct answer on new topic

- GIVEN student has never attempted `com-01` (attempts=0, correctAttempts=0)
- WHEN `evaluar_respuesta("com-01", correcta: true)` is called
- THEN pLearned MUST be `1 / max(1, 1)` = 1.0
- AND `attempts` MUST increment to 1
- AND `consecutive_correct` MUST be 1

#### Scenario: Mixed answers yield proportional mastery

- GIVEN student has 7 correct out of 10 attempts on `mat-03`
- WHEN mastery is computed
- THEN pLearned MUST be `7 / 10` = 0.70
- AND the topic MUST NOT be marked mastered (0.70 < 0.80)

#### Scenario: Three consecutive correct answers reach mastery

- GIVEN student has pLearned=0.75, consecutiveCorrect=2 on `com-02`
- WHEN another correct answer is recorded
- THEN pLearned MUST be `4 / 5` = 0.80
- AND the topic MUST be marked mastered (0.80 ≥ 0.80)

#### Scenario: Incorrect answer resets streak only

- GIVEN student has consecutiveCorrect=2 on `mat-01`
- WHEN an incorrect answer is recorded
- THEN `consecutive_correct` MUST reset to 0
- AND pLearned MUST decrease proportionally (pLearned = correct / total)

### Requirement: Tool `consultar_estado`

The tool `consultar_estado(tema: String)` SHALL query `student_mastery` and return `{p_learned, attempts, mastered, last_interaction}` with flat-ratio pLearned.

(Previously: returned BKT-calculated P(L) with slip/guess factors.)

#### Scenario: Query mastered topic

- GIVEN `com-01` has pLearned=0.83 in the database
- WHEN `consultar_estado("com-01")` is called
- THEN it MUST return `{p_learned: 0.83, mastered: true, attempts: 6}`

### Requirement: Tool `evaluar_respuesta`

The tool `evaluar_respuesta(tema: String, correcta: bool)` SHALL update `correctAttempts`/`attempts`, recompute pLearned as `correct/total`, persist to SQLite, and return the updated state.

(Previously: invoked BKT formula with P(L₀), P(T), P(G), P(S) parameters.)

#### Scenario: Gemma evaluates student answer

- GIVEN Gemma determines the student's answer is correct for `com-03`
- WHEN Gemma calls `evaluar_respuesta("com-03", correcta: true)`
- THEN pLearned MUST update via `correctAttempts / attempts`
- AND the new state MUST be persisted to `student_mastery`
- AND the result MUST return `{p_learned, mastered, mensaje: "¡Correcto! ..."}`

### Requirement: Mastery Persistence

Mastery state SHALL persist across app sessions via SQLCipher-encrypted SQLite. On app launch, `student_mastery` MUST be loaded into memory.

(Previously: same requirement — no behavioral change. Preserved for continuity.)

#### Scenario: App restart preserves mastery

- GIVEN a student mastered `com-01` in a previous session
- WHEN the app launches again
- THEN `consultar_estado("com-01")` MUST return `mastered: true`
- AND pLearned MUST match the last persisted value
