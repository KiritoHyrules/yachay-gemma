# interfaz-aprendiz Specification

## Purpose

Student-facing UI for Aprendo+. Three screens implement the core learner flow: diagnostic assessment, interactive lesson consumption, and learning path navigation. All screens follow Material Design 3 and operate offline-first.

## Requirements

### Requirement: Diagnostic Screen

The screen SHALL display one item at a time with: `enunciado` text, 4 tappable option buttons, and a progress bar showing `items_completados / items_totales`. After final item, results SHALL show the competency level label and a positive message — never a numeric score or grade.

#### Scenario: Student answers an item

- GIVEN the diagnostic screen displays item #3 of up to 25
- WHEN the student taps an option button
- THEN the selected option highlights briefly
- AND the next item appears within 1 second
- AND the progress bar increments

#### Scenario: Diagnostic completes with positive result

- GIVEN the final item has been answered
- WHEN the result screen renders
- THEN the level label (e.g., "Intermedio") is displayed prominently
- AND a positive encouragement message is shown
- AND no numeric score, grade, or "X/25" count appears

### Requirement: Lesson Screen

The lesson screen SHALL render JSON-driven content as a scrollable sequence: video player at top (when `video_url` present), explanation cards for text steps, and interactive exercise widgets for exercise steps. A "?" help button triggers `GemmaService.generarExplicacion()` for the current topic.

#### Scenario: Student plays video and reads explanation

- GIVEN a lesson with a video URL
- WHEN the lesson screen opens
- THEN an inline video player is displayed
- AND the student can play, pause, and seek
- AND explanation cards appear below the video as the student scrolls

#### Scenario: Help button requests AI explanation

- GIVEN the student is viewing a lesson about fractions
- WHEN the "?" help button is tapped
- THEN `GemmaService.generarExplicacion("fracciones", nivelActual)` is called
- AND the response is displayed in a modal or card overlay
- AND a loading indicator is shown if the call takes >2 seconds

### Requirement: Learning Path Screen

The screen SHALL display the 5 lessons as an ordered list with: lesson title, area icon (math/reading), completion status (⏳ pending / ▶ in progress / ✅ completed), and the student's current competency level badge at the top. Lessons unlock sequentially — the next lesson enables only after the prior is completed.

#### Scenario: Sequential lesson progression

- GIVEN the student has completed only lesson 1
- WHEN the learning path screen opens
- THEN lesson 1 shows "✅ completed"
- AND lessons 3-5 show "🔒" (locked)
- AND lesson 2 shows "▶ in progress"

#### Scenario: Level badge updates after diagnostic

- GIVEN the student has no prior diagnostic result
- WHEN a new diagnostic completes with level "Principiante"
- THEN the learning path screen shows a "Principiante" badge
- AND "Reiniciar diagnóstico" option is available

### Requirement: Offline-First Behavior

All screens MUST render content from local database and assets without requiring network. Connectivity-dependent features (video streaming, Gemma live inference) SHALL degrade gracefully with cached content or fallback responses.

#### Scenario: Video unavailable offline shows placeholder

- GIVEN the device is offline and a lesson has a remote video URL
- WHEN the lesson screen opens
- THEN a placeholder card is shown instead of the video player
- AND a message reads "Video no disponible sin conexión"
- AND all other lesson content renders normally
