# yachay-dashboard Specification

> NEW capability: teacher dashboard reading directly from SQLite

## Purpose

Provide teachers a read-only view of group progress without requiring Gemma inference, respecting offline constraints and privacy (N-06, N-08, N-15).

## Requirements

### Requirement: Student List with Mastery Overview

The teacher dashboard SHALL display a list of all students stored in the local SQLite database. Each student row MUST show: name, last active date, topics mastered / total topics, and overall accuracy.

#### Scenario: Dashboard loads student list

- GIVEN the local database contains 3 student profiles
- WHEN the teacher opens the dashboard
- THEN all 3 students MUST appear in the list
- AND each row MUST show mastery progress as "5/45" format
- AND no Gemma inference SHALL be triggered

### Requirement: Per-Student Topic Breakdown

Tapping a student row SHALL navigate to a detailed view showing every curriculum topic with that student's mastery percentage, color-coded (green/yellow/white/gray) identically to the Camino screen.

#### Scenario: Teacher views student detail

- GIVEN the teacher taps student "María" who has 3 mastered topics
- WHEN the detail screen loads
- THEN all 45 curriculum subtopics MUST display with María's mastery state
- AND mastered topics MUST render green bars
- AND the teacher MUST be able to scroll the full list

### Requirement: "Recomendación de Yachay"

The student detail screen SHALL display a "Recomendación de Yachay" section containing insight text generated during student sessions and stored in the `student_mastery` table (field `yachay_recomendacion`). This text MUST NOT invoke Gemma at dashboard render time — it is pre-computed.

#### Scenario: Stored recommendation displays

- GIVEN Yachay previously stored `yachay_recomendacion: "María confunde numerador con denominador. Recomiendo ejercicios visuales con fracciones."`
- WHEN the teacher views María's detail screen
- THEN the recommendation MUST display verbatim
- AND no inference call SHALL be made

#### Scenario: No recommendation available

- GIVEN no `yachay_recomendacion` has been stored for a student
- WHEN the teacher views that student's detail
- THEN the section MUST display "Yachay aún no tiene recomendaciones para este estudiante."

### Requirement: Offline-Only Operation

The dashboard SHALL operate entirely from local SQLite. It MUST NOT require network connectivity or Gemma model availability. All queries SHALL be read-only — the teacher CANNOT modify student data.

#### Scenario: Dashboard works without model loaded

- GIVEN the Gemma model failed to load (fallback mode)
- WHEN the teacher opens the dashboard
- THEN the student list and detail views MUST render normally
- AND all data MUST come from SQLite queries
