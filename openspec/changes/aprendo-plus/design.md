# Design: Aprendo+ — Initial Zero-to-Prototype

## Technical Approach

Greenfield Flutter monolith, Android 6+ (API 23), Provider DI root in `lib/main.dart`. Six capability modules under `lib/modules/` sharing two core services: `DatabaseService` (sqflite_sqlcipher AES-256) and `GemmaService` (MethodChannel → Kotlin → llama.cpp GGUF Q4_0). All content ships as JSON assets in APK, seeded into encrypted SQLite on first launch. Three Navigator 1.0 screens: diagnóstico → ruta de aprendizaje → lección. Gemma integration is fallback-aware: `cargarModelo()` success gates live inference vs pre-authored responses from `assets/data/fallback_responses.json`. No cloud dependencies in core flow; Firebase sync deferred to Phase 2.

Approach B (Core Only with Canned AI + Gemma attempt). Budget: 5.5–6.5h per exploration, with 60min buffer.

## Architecture Decisions

| ADR | Option | Tradeoff | Decision |
|-----|--------|----------|----------|
| **001: Monolith** | Monolith modular | Single APK, simple build, `lib/core/` + `lib/modules/` separation | **Chosen**. 5-7h window precludes multi-module build complexity |
|  | Multi-module | Independent deploy, overkill for 3 screens | Rejected |
| **002: State** | Provider + ChangeNotifier | Simple DI, 3 providers (StudentState, LessonState, GemmaState) | **Chosen**. App scope: 3 screens, no event streams needed |
|  | Riverpod/Bloc | More testable, steep learning curve, verbose for this scope | Rejected |
| **003: Content** | JSON bundled in APK assets | Offline, zero-latency, <500KB total | **Chosen**. NR-02 offline-first. Content rebuilds don't matter in hackathon |
|  | Remote fetch (Firebase) | Dynamic updates, needs network | Phase 2 only |
| **004: Gemma** | MethodChannel → Kotlin → llama.cpp | Full control, separate RAM budget, isolates native crash | **Chosen**. flutter_gemma doesn't support Gemma 4 E2B wNa8o8 yet |
|  | flutter_gemma / MediaPipe | Official, simpler — no Gemma 4 support | Rejected / fallback |
| **005: Fallback** | Pre-authored JSON responses | Always available, demo works regardless of model | **Chosen**. R1 (RAM) rated CRITICAL; fallback guarantees functional demo |
|  | Block UI until model loads | Fails completely if RAM insufficient | Rejected |

## Component Diagram

```
lib/main.dart  ← MultiProvider(DatabaseService, GemmaService, StudentState)
     │
     ├── lib/modules/diagnostico/    ← IRTAlgorithm + DiagnósticoScreen
     │        │                              │
     │        └──────── DatabaseService ──────┘  (items, results)
     │
     ├── lib/modules/aprendizaje/    ← LessonEngine + LecciónScreen + RutaScreen
     │        │              │               │
     │        └── DatabaseService ───────────┘  (lessons, progress)
     │                       │
     │                       └──── GemmaService ──── MethodChannel ──── GemmaEngine.kt
     │
     └── lib/modules/gemma/         ← GemmaService (Dart) + fallback dispatch
              │
              └── GemmaEngine.kt (android/.../kotlin/)  ← llama.cpp GGUF Q4_0
```

## Key Sequence Flows

**Diagnostic → Persist**: `DiagnósticoScreen` → `IRTAlgorithm.updateTheta(answer)` → repeat ×25 or SE≤0.3 → `StudentRepo.save(nivel, theta)` → `DatabaseService.insert(student_profile)`.

**Lesson Interaction with Fallback**: `LecciónScreen` → tap "?" → `GemmaService.generarExplicacion(tema, nivel)` → check `_modeloCargado` → if `false`: return `fallbackResponses[tema][nivel]` from JSON → show card. If `true`: `MethodChannel.invokeMethod('generate', {prompt})` → 30s timeout → fallback on timeout.

**DB Encryption Init**: `main()` → `DatabaseService.initialize()` → `AndroidKeystore.getKey()` → `sqflite_sqlcipher.openDatabase(path, password: key)` → `migrationV1(db)` → `seedContent(db, assets)`.

**Content Precarga**: First launch only → `seedTransaction`: parse `assets/data/item_bank.json` → bulk insert 50 items; parse `assets/data/lessons.json` → bulk insert 5 lessons.

## Data Flow

```
assets/data/*.json  ──seedTransaction()──>  SQLite (AES-256)
                                              │
                    ┌─────────────────────────┤
                    ▼                         ▼
            Diagnóstico (IRT)          Lecciones (Engine)
                    │                         │
                    └──────> StudentState <────┘
                    (Provider ChangeNotifier: nivel, theta, progreso)
```

Phase 2: `connectivity_plus` background sync SQLite → Firestore.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `pubspec.yaml` | Create | provider, sqflite_sqlcipher, connectivity_plus, flutter_lints |
| `analysis_options.yaml` | Create | flutter_lints recommended set |
| `android/app/build.gradle` | Create | minSdk 23, targetSdk 34, compileSdk 34, SQLCipher .so packaging |
| `android/app/proguard-rules.pro` | Create | Keep SQLCipher + llama.cpp JNI symbols |
| `lib/main.dart` | Create | MultiProvider root, MaterialApp(Material3), initial route = diagnóstico |
| `lib/core/database/database_service.dart` | Create | Encrypted DB init, migration v1, seed, CRUD |
| `lib/core/database/repositories/student_repo.dart` | Create | Student profile CRUD |
| `lib/core/database/repositories/lesson_repo.dart` | Create | Lesson content + progress queries |
| `lib/core/state/student_state.dart` | Create | ChangeNotifier: nivel, theta, leccionActual, progreso |
| `lib/modules/diagnostico/irt_algorithm.dart` | Create | IRT: theta=0.0, select by |difficulty-theta|, update via response model, stop at 25 items or SE≤0.3 |
| `lib/modules/diagnostico/diagnostico_screen.dart` | Create | Single item display, 4 option buttons, progress bar |
| `lib/modules/aprendizaje/leccion_screen.dart` | Create | JSON-driven lesson renderer, step navigation |
| `lib/modules/aprendizaje/ruta_screen.dart` | Create | 5-lesson ordered list, sequential unlock, level badge |
| `lib/modules/aprendizaje/exercise_widgets.dart` | Create | opcion_multiple, verdadero_falso, respuesta_corta widgets |
| `lib/modules/gemma/gemma_service.dart` | Create | MethodChannel facade, fallback dispatch, 30s timeout |
| `android/app/src/main/kotlin/.../GemmaEngine.kt` | Create | loadModel(path), generate(prompt), unloadModel() via llama.cpp |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Modify | Register gemma_engine MethodChannel |
| `assets/data/item_bank.json` | Create | 50 items: 25 math + 25 reading, IRT b-parameter |
| `assets/data/lessons.json` | Create | 5 lessons (3 math + 2 reading), 3–5 steps each |
| `assets/data/fallback_responses.json` | Create | Pre-authored explanations + exercises per topic × level |

## Interfaces / Contracts

**MethodChannel `gemma_engine`**: `loadModel({modelPath})→bool`, `generate({prompt, systemPrompt})→String`, `unloadModel()→bool`. 30s timeout per call. System prompt: *"Eres un tutor de matemáticas para secundaria en Perú. Explica conceptos de manera clara, usa ejemplos del contexto peruano y mantén un tono motivador sin calificaciones negativas."*

**DB Schema v1**: 4 tables — `student_profile(id TEXT PK, nivel INT, theta REAL, fecha_diagnostico TEXT)`, `interaction_log(id INTEGER PK AUTO, student_id FK, tipo TEXT, contenido TEXT, timestamp TEXT)`, `lesson_content(id TEXT PK, titulo TEXT, tipo TEXT, contenido_json TEXT)`, `generated_exercises(id INTEGER PK AUTO, lesson_id FK, enunciado TEXT, tipo TEXT, respuesta_correcta TEXT)`.

**JSON Assets**: `item_bank.json` → `[{id, area, dificultad, enunciado, opciones[4], respuesta_correcta}]`. `lessons.json` → `[{id, titulo, area, video_url?, pasos[{tipo: explicacion|ejercicio, contenido}]}]`. `fallback_responses.json` → `{explicaciones: {tema: {nivel: texto}}, ejercicios: {tema: [{enunciado, tipo, opciones, respuesta}]}}`.

## Testing Strategy

| Layer | Target | Approach |
|-------|--------|----------|
| Unit | IRT math (theta update, item selection, SE convergence) | Dart test, pure functions |
| Unit | Fallback dispatch (all 5 topics × 5 levels return non-empty) | JSON fixture validation |
| Integration | DB CRUD + migration v1 + seed (all 4 tables) | sqflite_common_ffi desktop |
| Integration | MethodChannel contract (mock native side) | setMockMethodCallHandler |
| Manual | Full flow: diagnostic → path → lesson | `flutter build apk --debug`, Android 6.0 emulator 2GB |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. MethodChannel is in-process IPC within the APK.

## Migration / Rollout

No migration required — greenfield. First APK establishes schema v1.

## Open Questions

- [ ] Gemma 4 GGUF Q4_0 actual RAM on 2GB device (verification items 3, 4, 6, 7 pending pre-hackathon)
- [ ] llama.cpp Android JNI compatibility with Gemma 4 hybrid attention (verification items 3, 6)
- [ ] sqflite_sqlcipher Windows build — fallback to plain sqflite if native compilation fails (R5)
