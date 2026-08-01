# session-analyzer Specification

## Purpose

Post-session analysis: aggregates last N `TopicMastery` entries into a JSON summary consumed by the Rules Engine (N-01, N-03).

## Requirements

### Requirement: Session Summary Generation

The system MUST provide `SessionAnalyzer.analizar(List<TopicMastery> entries, {int n})` that returns:

```json
{
  "fortalezas": ["id1", "id2"],
  "debilidades": ["id3"],
  "recomendaciones": ["text", "text"]
}
```

#### Scenario: Mixed mastery generates balanced summary

- GIVEN last 5 entries: 3 with pLearned ≥ 0.80, 2 with pLearned < 0.40
- WHEN `analizar(entries, n: 5)` is called
- THEN `fortalezas` MUST contain the 3 high-mastery topic IDs
- AND `debilidades` MUST contain the 2 low-mastery topic IDs
- AND `recomendaciones` MUST include ≥1 suggestion per debilidad

#### Scenario: All-mastered session

- GIVEN last 5 entries all have pLearned ≥ 0.80
- WHEN `analizar(entries, n: 5)` is called
- THEN `debilidades` MUST be empty
- AND `recomendaciones` MUST suggest advancing to next area

#### Scenario: Empty entries list

- GIVEN an empty entries list
- WHEN `analizar([], n: 5)` is called
- THEN all three arrays MUST be empty
- AND no exception SHALL be thrown

#### Scenario: End-of-session only — not mid-conversation

- GIVEN a chat session is active
- WHEN the student is mid-conversation
- THEN `SessionAnalyzer.analizar()` MUST NOT be called
- AND it MUST only run when the session explicitly ends
