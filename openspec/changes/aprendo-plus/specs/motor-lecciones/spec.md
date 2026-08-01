# motor-lecciones Specification

## Purpose

JSON-driven lesson rendering engine for Aprendo+. Delivers pre-authored lessons with video, text explanations, and interactive exercises. Tracks errors and progress per student.

## Requirements

### Requirement: JSON-Driven Lesson Rendering

The system MUST parse lesson definitions from JSON with the structure: `{ "id", "titulo", "area", "video_url", "pasos": [{ "tipo": "explicacion"|"ejercicio", "contenido": ... }] }`. Each step type renders its corresponding widget: explanation (text + optional image), exercise (interactive with response validation).

#### Scenario: Lesson with explanation steps renders

- GIVEN a lesson JSON with 3 explanation steps
- WHEN the lesson engine renders the lesson
- THEN 3 explanation widgets are displayed sequentially
- AND the student can navigate between steps

#### Scenario: Exercise step validates response

- GIVEN a lesson step of type "ejercicio" with respuesta_correcta defined
- WHEN the student submits an answer
- THEN the engine validates correctness
- AND immediate feedback is shown
- AND the response is logged to `interaction_log`

### Requirement: Preloaded Lesson Content

5 lessons MUST be precargada from assets: 3 math (Fracciones, Ecuaciones básicas, Porcentajes) and 2 reading (Comprensión literal, Inferencias). Each SHALL have 3-5 steps with at least 2 exercise steps.

#### Scenario: All lessons available offline

- GIVEN the app has never connected to the internet
- WHEN the student navigates to the learning path
- THEN all 5 lessons are listed and accessible
- AND each lesson renders its full content from local assets

### Requirement: Exercise Type Support

The engine SHALL support 3 exercise types — `opcion_multiple` (4 options), `verdadero_falso` (2 options), and `respuesta_corta` (free text with exact-match validation). Each type renders its own input widget.

#### Scenario: Multiple choice renders radio options

- GIVEN an exercise of type "opcion_multiple" with 4 options
- WHEN the lesson step renders
- THEN 4 selectable options are displayed
- AND the student can tap one and submit

### Requirement: Error Pattern Tracking

The system MUST count same-type exercise errors per student. When 3 or more errors of the same exercise type accumulate, the engine SHALL trigger a reinforcement card explaining the concept with an additional practice exercise.

#### Scenario: Reinforcement triggers after 3 errors

- GIVEN the student has made 3 errors on "opcion_multiple" exercises about fractions
- WHEN the 3rd error is recorded
- THEN a reinforcement explanation card is inserted before the next step
- AND a supplementary practice exercise is appended to the lesson

### Requirement: Progress Tracking

Lesson completion status per student SHALL persist to `interaction_log` with `tipo = "lesson_completed"`. A student returning to a partially completed lesson MUST resume from the last uncompleted step.

#### Scenario: Lesson progress persists across restarts

- GIVEN a student completed 2 of 4 steps in a lesson
- WHEN the app is closed and reopened
- THEN the lesson resumes at step 3
- AND previously completed steps are marked as done
