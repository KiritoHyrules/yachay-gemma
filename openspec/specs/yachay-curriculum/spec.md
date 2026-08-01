# yachay-curriculum Specification

> NEW capability: Aritmética 1° secundaria knowledge graph as prerequisite DAG

## Purpose

Provide a structured, traversable curriculum that Gemma queries to determine what to teach next — replacing the flat 5-lesson list with a real competency hierarchy (N-01, N-08).

## Requirements

### Requirement: Knowledge Graph Asset

The system SHALL load `assets/curriculum/aritmetica_1.json` at app startup and cache the DAG in memory. The graph MUST define at least 15 competencies, each with 2-4 subtopics, prerequisite edges, and difficulty levels (1-3). Total node count MUST NOT exceed 50 subtopic nodes (MVP scope).

#### Scenario: Graph loads successfully

- GIVEN `assets/curriculum/aritmetica_1.json` exists and is valid
- WHEN `CurriculoService.inicializar()` is called on app start
- THEN the DAG MUST be parsed and stored in memory
- AND `obtener_plan_completo()` MUST return all competencies with their subtopics

#### Scenario: Missing or corrupt asset

- GIVEN the JSON file is missing or has invalid JSON
- WHEN `CurriculoService.inicializar()` is called
- THEN the system MUST log the error and fall back to an embedded minimal default (3 topics)
- AND the app MUST remain functional (N-04)

### Requirement: Prerequisite DAG Traversal

Each competency node SHALL declare `prerrequisitos: string[]` referencing prerequisite node IDs. A subtopic is "unlocked" when ALL its prerequisite chain nodes have P(L) ≥ 0.90 in `student_mastery`.

#### Scenario: Topic locked by unmet prerequisite

- GIVEN `arit_of_02` requires `arit_nn_01` as prerequisite
- AND `arit_nn_01` has P(L)=0.45 (not mastered)
- WHEN `obtener_siguiente_tema()` is called
- THEN `arit_of_02` MUST NOT appear in unlockable topics
- AND the returned topic MUST be from the mastered frontier

#### Scenario: Prerequisites all met

- GIVEN all prerequisites for `arit_of_02` have P(L) ≥ 0.90
- WHEN `obtener_siguiente_tema()` is called
- THEN `arit_of_02` MAY appear as a recommended next topic

### Requirement: Tool `obtener_siguiente_tema`

The tool `obtener_siguiente_tema()` SHALL traverse the DAG and return the first unlocked, unmastered subtopic ID, title, and description. If all topics are mastered, it MUST return a completion message.

#### Scenario: First unmastered topic found

- GIVEN topics A and A.1 are mastered, A.2 is unlocked but not mastered
- WHEN `obtener_siguiente_tema()` is called
- THEN it MUST return `{id: "A.2", titulo: "...", descripcion: "..."}`

### Requirement: Tool `obtener_plan_completo`

The tool `obtener_plan_completo()` SHALL return the full curriculum with each subtopic annotated with mastery status from `student_mastery`: `{id, titulo, grado, dominado, p_learned, bloqueado}`.

#### Scenario: Full plan with mastery

- GIVEN 3 of 45 subtopics are mastered
- WHEN `obtener_plan_completo()` is called
- THEN it MUST return all 45 subtopics with `dominado: true/false` per subtopic
- AND locked subtopics MUST have `bloqueado: true`
