# diagnostico-adaptativo Specification

## Purpose

Adaptive diagnostic module using a simplified Item Response Theory (IRT) algorithm. Assesses student competency in math and reading, adapts item difficulty in real time, and maps results to a 5-level framework.

## Requirements

### Requirement: IRT Algorithm Execution

The system MUST implement a simplified IRT algorithm that: (a) initializes theta at 0.0, (b) selects the next item with difficulty closest to current theta, (c) updates theta after each response using a response model, (d) stops at 25 items or when standard error ≤0.3.

#### Scenario: Diagnostic completes after 25 items

- GIVEN a student starts the diagnostic with no prior estimate
- WHEN the student answers 25 items
- THEN the diagnostic terminates
- AND the final theta estimate is persisted to `student_profile`

#### Scenario: Early termination on low error

- GIVEN the standard error of theta drops to ≤0.3 before 25 items
- WHEN the algorithm checks the termination condition
- THEN the diagnostic terminates early
- AND the result is accepted as sufficiently precise

### Requirement: Item Bank Structure

The system SHALL load a 50-item bank from `assets/data/item_bank.json`, structured as 25 math items and 25 reading items. Each item MUST carry: `id`, `area` (math/reading), `dificultad` (IRT b-parameter, -3 to +3), `enunciado`, `opciones` (4 choices), `respuesta_correcta` (index 0-3).

#### Scenario: Item bank loads correctly

- GIVEN the diagnostic module initializes
- WHEN the item bank JSON is parsed
- THEN 50 items are available with 25 in each area
- AND every item has a valid difficulty parameter and 4 options

### Requirement: Item Selection by Proximity

Each step MUST select the unanswered item whose difficulty parameter is closest to the current theta estimate, alternating between math and reading areas to avoid fatigue bias.

#### Scenario: Adaptive difficulty rises with correct answers

- GIVEN the current theta is 1.2 after several correct answers
- WHEN the algorithm selects the next item
- THEN the selected item has difficulty closest to 1.2
- AND items with difficulty far from 1.2 are deprioritized

### Requirement: Competency Level Mapping

Final theta SHALL be mapped to a 5-level label:

| Theta Range | Level | Label |
|-------------|-------|-------|
| ≤ -1.5 | 1 | Explorador |
| -1.49 to -0.5 | 2 | Principiante |
| -0.49 to 0.5 | 3 | Intermedio |
| 0.51 to 1.5 | 4 | Avanzado |
| ≥ 1.51 | 5 | Experto |

#### Scenario: High performer maps to Experto

- GIVEN final theta is 1.8
- WHEN the level mapping is applied
- THEN the student receives level 5 ("Experto")

### Requirement: Positive UX Constraints

The diagnostic SHALL NOT display timers, countdowns, penalties for wrong answers, or negative language (e.g., "Incorrecto", "Fallaste"). Feedback SHALL use neutral-to-positive phrasing.

#### Scenario: Wrong answer feedback is neutral

- GIVEN the student selects an incorrect option
- WHEN the app displays feedback
- THEN no negative language appears
- AND the student sees a neutral transition to the next item
- AND there is no score penalty
