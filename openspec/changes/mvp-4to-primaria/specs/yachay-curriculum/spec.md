# Delta for yachay-curriculum

## ADDED Requirements

### Requirement: Flat Curriculum Replacement

The system MUST load curriculum from `Curricula4toPrimaria.temas` (static Dart list) instead of `assets/curriculum/aritmetica_1.json` (JSON DAG). `CurriculoService` SHALL reference the static list directly with no file I/O.

#### Scenario: Static curriculum loads at startup

- GIVEN the app initializes
- WHEN `CurriculoService.inicializar()` is called
- THEN `Curricula4toPrimaria.temas` MUST be the sole data source
- AND no JSON parsing or asset loading SHALL be triggered

## MODIFIED Requirements

### Requirement: Knowledge Graph Asset

The system SHALL provide a flat `Curricula4toPrimaria.temas` list with ≥18 topics across 3 areas: Comunicación (≥6), Matemática (≥6), Ciencia y Tecnología (≥6). Each topic has id, area, titulo, explicacion (≤90 words), chips (3-4), and prioridad (alta/media/baja). No prerequisite DAG — all topics are always accessible.

(Previously: JSON DAG from `aritmetica_1.json` with 45 subtopic nodes, prerequisite edges, difficulty levels.)

#### Scenario: Flat list loads successfully

- GIVEN `Curricula4toPrimaria.temas` is defined statically
- WHEN `CurriculoService.inicializar()` is called
- THEN all ≥18 topics MUST be available in memory
- AND `obtener_plan_completo()` MUST return all topics

#### Scenario: No asset-level failure mode needed

- GIVEN curriculum is static Dart code
- WHEN `CurriculoService.inicializar()` is called
- THEN no fallback logic for missing assets is required
- AND the app MUST remain functional (N-04)

### Requirement: Tool `obtener_siguiente_tema`

The tool `obtener_siguiente_tema()` SHALL iterate the flat `Curricula4toPrimaria.temas` list and return the first unmastered topic (pLearned < 0.80). If all topics are mastered, return a completion message. No prerequisite DAG traversal required.

(Previously: traversed DAG prerequisite chain, required P(L) ≥ 0.90 on all prerequisites.)

#### Scenario: First unmastered topic found

- GIVEN topics "com-01" and "mat-01" are mastered, "com-02" is not
- WHEN `obtener_siguiente_tema()` is called
- THEN it MUST return `{id: "com-02", titulo: "...", descripcion: "..."}`

#### Scenario: All topics mastered

- GIVEN all ≥18 topics have pLearned ≥ 0.80
- WHEN `obtener_siguiente_tema()` is called
- THEN it MUST return a completion message

### Requirement: Tool `obtener_plan_completo`

The tool `obtener_plan_completo()` SHALL return all topics from `Curricula4toPrimaria.temas` with mastery status: `{id, titulo, area, dominado, p_learned}`. No `bloqueado` field — all topics are always unlocked.

(Previously: returned 45 subtopics with `bloqueado` field based on DAG prerequisites.)

#### Scenario: Full plan with mastery

- GIVEN 3 of 18 topics have pLearned ≥ 0.80
- WHEN `obtener_plan_completo()` is called
- THEN it MUST return all 18 topics with `dominado: true/false`
- AND no topic SHALL have `bloqueado: true`

## REMOVED Requirements

### Requirement: Prerequisite DAG Traversal

(Reason: 4to Primaria curriculum is flat — no prerequisite hierarchy needed for 9-10 year olds.)
(Migration: `obtener_siguiente_tema()` now iterates flat list — see MODIFIED above. Remove all DAG traversal and `prerrequisitos` logic from `CurriculoService`.)
