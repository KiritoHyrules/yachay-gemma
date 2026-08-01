# static-curriculum Specification

## Purpose

Static, flat curriculum for 4to Primaria — loaded once via `Curricula4toPrimaria.temas`. No database, no JSON DAG, no BKT (N-01, N-03).

## Requirements

### Requirement: Curriculum Data Structure

The system MUST define `Curricula4toPrimaria` with a static `List<TemaPrimaria> temas` containing ≥18 topics across 3 areas: Comunicación (≥6), Matemática (≥6), Ciencia y Tecnología (≥6).

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique topic ID (e.g. "com-01") |
| area | String | "Comunicación", "Matemática", or "Ciencia y Tecnología" |
| titulo | String | Kid-friendly Spanish title |
| explicacion | String | ≤90 words, grade-appropriate |
| chips | List\<String\> | 3-4 quick response options |
| prioridad | String | "alta", "media", or "baja" |

#### Scenario: Curriculum loads at startup

- GIVEN the app is initializing
- WHEN `Curricula4toPrimaria.temas` is first accessed
- THEN all ≥18 topics MUST be in memory
- AND no file I/O, JSON parsing, or DB query SHALL be triggered

#### Scenario: Per-area filtering

- GIVEN the curriculum is loaded
- WHEN `temas.where((t) => t.area == 'Matemática')` is evaluated
- THEN ≥6 Matemática topics MUST be returned

#### Scenario: Topic lookup by ID

- GIVEN the curriculum is loaded
- WHEN `temas.firstWhere((t) => t.id == 'com-01')` is called
- THEN the Comunicación topic "com-01" MUST be returned

#### Scenario: All areas accessible

- GIVEN the curriculum is loaded
- WHEN any module accesses `Curricula4toPrimaria.temas`
- THEN all 3 areas MUST be present and queryable
