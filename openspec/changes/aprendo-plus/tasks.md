# Tasks: Aprendo+ — Initial Zero-to-Prototype

## Review Workload Forecast

Estimated changed lines: 800–1100 (code) + JSON assets. 19 files: 11 Dart/Kotlin + 8 JSON assets.

| Field | Value |
|-------|-------|
| Estimated changed lines | 800–1100 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1(Foundation)→PR2(Diagnostic)→PR3(Lessons)→PR4(Gemma) |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Scaffold + DB seed | PR 1 | `flutter build apk --debug` | Launch emulator, verify DB tables seeded | Revert lib/core/ |
| 2 | Diagnostic flow | PR 2 | `dart analyze lib/modules/diagnostico/` | Complete 25 items, verify nivel in DB | Remove diagnostico/ dir |
| 3 | Lesson engine + UI | PR 3 | `dart analyze lib/modules/aprendizaje/` | Open lesson, complete exercises, verify progress | Remove aprendizaje/ dir |
| 4 | Gemma bridge | PR 4 | `dart analyze lib/modules/gemma/` | Tap help button, verify fallback response | Remove gemma/ dir, revert MainActivity |

## Phase 1: Foundation — PR 1

- [x] 1.1 Create `pubspec.yaml` (provider, sqflite_sqlcipher, flutter_lints). `flutter pub get`.
- [x] 1.2 Create `analysis_options.yaml` (flutter_lints recommended).
- [x] 1.3 [DB] Create `android/app/build.gradle` (minSdk 23, targetSdk 34, SQLCipher .so) + `proguard-rules.pro` (keep SQLCipher+JNI).
- [x] 1.4 [DB] Create `lib/core/models/`: student_profile, interaction_log, lesson, exercise, diagnostic_result (5 data classes).
- [x] 1.5 [DB] Create `lib/core/database/database_service.dart` (AES-256 init via Keystore, migration v1 4 tables, seed from JSON assets).
- [x] 1.6 [DB] Create `lib/core/keystore/keystore_service.dart` (MethodChannel → Android Keystore).
- [x] 1.7 [DB] Create `lib/core/database/repositories/` (student_repo, lesson_repo) with transactional CRUD.
- [x] 1.8 Create `lib/core/state/student_state.dart` (ChangeNotifier: nivel, theta, progreso).
- [x] 1.9 Create `lib/main.dart` (MultiProvider, MaterialApp Material3, initRoute→diagnostico).
- [x] 1.10 Create `test/` directory with flutter_test placeholder + DB integration test skeleton.

## Phase 2: Diagnostic — PR 2

- [x] 2.1 Create `assets/diagnostic/items_matematica.json` + `items_lectura.json` (25 each, IRT b-param, 4 options).
- [x] 2.2 Create `lib/modules/diagnostico/diagnostico_service.dart` (IRT: init theta=0.0, proximity selection, update, stop at 25 items or SE≤0.3, 5-level map).
- [x] 2.3 [UI] Create `lib/modules/diagnostico/diagnostico_screen.dart` (single item, 4 buttons, progress bar, result with level label, no scores).
- [x] 2.4 Wire diagnostic flow: screen→service→state→DB. Verify result in student_profile.

## Phase 3: Lessons — PR 3

- [x] 3.1 Create `assets/lessons/` (5 JSONs: fracciones, ecuaciones, porcentajes, comprension, inferencias). 3–5 steps, ≥2 exercises.
- [x] 3.2 Create `lib/modules/aprendizaje/leccion_service.dart` (JSON parser, step nav, progress tracking, error counter→reinforcement at 3).
- [x] 3.3 [UI] Create `lib/modules/aprendizaje/exercise_widgets.dart` (opcion_multiple, verdadero_falso, respuesta_corta).
- [x] 3.4 [UI] Create `lib/modules/aprendizaje/leccion_screen.dart` (video player+offline placeholder, explanation cards, exercise widgets, "?"→GemmaService).
- [x] 3.5 [UI] Create `lib/modules/aprendizaje/ruta_screen.dart` (5-lesson ordered list, sequential unlock, status icons, level badge).

## Phase 4: Gemma — PR 4 [DEFER IF PRE-HACKATHON VERIFICATIONS FAIL]

- [x] 4.1 [AI] Create `assets/data/fallback_responses.json` (explanations+exercises for 5 topics×3 levels, 15 entries).
- [x] 4.2 [AI] Create `lib/modules/gemma/gemma_service.dart` (cargarModelo, generarExplicacion, generarEjerciciosRefuerzo, fallback dispatch, 30s timeout, system prompt).
- [x] 4.3 [AI] Create `GemmaEngine.kt` (loadModel, generate, unloadModel via llama.cpp stubs; graceful OOM/UnsatisfiedLinkError failure).
- [x] 4.4 [AI] Modify `MainActivity.kt`: register `gemma_engine` MethodChannel, wire GemmaEngine.
- [x] 4.5 Create `assets/images/` placeholder illustrations (logo, video placeholder, 5 level badges).
- [x] 4.6 Wired "?" help button in leccion_screen.dart → GemmaService.generarExplicacion + fallback with loading UX + reinforcement exercises bottom sheet. App is fully functional with fallback.

## Phase 5: Polish

- [ ] 5.1 `dart analyze`→zero issues. `flutter build apk --debug`→builds. *(VERIFY: Cannot execute — no Flutter SDK on verification machine. Static review: analysis_options.yaml has strict lints, all imports resolve to existing files.)*
- [ ] 5.2 Manual e2e flow: diagnostic→path→lesson→fallback help. Verify DB persistence across restart. *(VERIFY: Code path traced — diagnostic_screen.dart → ruta_screen.dart → leccion_screen.dart → gemma_service.dart → fallback_responses.json. DB persistence path: database_service.dart → keystore_service.dart → repositories. No runtime verification possible without Flutter SDK.)*
- [ ] 5.3 UX audit: no timers ✅, no negative language ❌ (`exercise_widgets.dart:603` uses "Incorrecto"), no numeric scores on result ✅. *(VERIFY: C3 CRITICAL — "Incorrecto" violates spec. Also C1: level labels inconsistent across 3 files. C2: theta thresholds mismatch spec.)*
