# AGENTS.md — Aprendo+

Flutter/Dart Android app: offline-first AI tutor for Peruvian secondary students.

## Commands that actually work here

`flutter` is not on `PATH`; use the local SDK explicitly:

```powershell
& "C:\flutter\bin\flutter.bat" pub get
& "C:\flutter\bin\dart.bat" format lib/modules/gemma/gemma_service.dart
& "C:\flutter\bin\flutter.bat" analyze
& "C:\flutter\bin\flutter.bat" test
& "C:\flutter\bin\flutter.bat" build apk --debug
& "C:\flutter\bin\flutter.bat" devices
& "C:\flutter\bin\flutter.bat" run -d AXLKCP4515402262
```

Verified local toolchain: Flutter 3.44.8 / Dart 3.12.2 at `C:\flutter`.
Debug APK currently builds at `build/app/outputs/flutter-apk/app-debug.apk`.

## Architecture boundaries

- Entry point: `lib/main.dart` (`MaterialApp`, Spanish locale, `MultiProvider`).
- State: `provider` + `StudentState`; do not introduce Riverpod/BLoC without an explicit decision.
- `lib/core/`: database, keystore wrapper, models, app state.
- `lib/modules/diagnostico/`: adaptive diagnostic flow.
- `lib/modules/aprendizaje/`: lessons, routes, exercises.
- `lib/modules/gemma/`: `flutter_gemma` integration, tools, fallback responses.
- `lib/modules/yachay/`: Socratic tutor/chat/orchestration layer.

## Language and UI

The app is Spanish-only (`locale: Locale('es')`). UI strings, educational content, tool names exposed to the app, and learner-facing messages must remain Spanish unless the user explicitly asks otherwise.

## Gemma runtime status

- Current default runtime is `flutter_gemma`, not Kotlin/JNI/llama.cpp.
- Dependency is `flutter_gemma: ^0.10.0` (`pubspec.lock` resolves 0.10.6).
- Default model file is `gemma-3n-E2B-it-int4.task` in the app documents directory; `GemmaService` points `modelManager.setModelPath(...)` there before `createModel(...)`.
- If the `.task` model is missing, runtime logs `Gemma Model is not installed yet` and falls back to `assets/data/fallback_responses.json`.
- Real-device check on WDY LX3 / Android 14 confirmed build/install/launch, but Gemma real inference did not activate because the model was not installed.
- Legacy `MethodChannel('gemma_engine')` / GGUF code still exists in `GemmaService` as fallback/rollback debt; do not treat it as the main path.

## Build/test quirks

- `flutter build apk --debug` passes, with a Kotlin warning: `android/build.gradle` still declares `ext.kotlin_version = '2.0.21'` while `android/settings.gradle` declares Kotlin plugin `2.2.20`.
- `flutter analyze` runs but currently reports warnings/infos; do not assume a clean analyzer baseline.
- `flutter test` currently runs many tests but has known failures in Yachay integration/UI tests (`1° Sec` not found, `pumpAndSettle timed out`). Do not report tests as fully passing unless re-verified.
- `analysis_options.yaml` excludes `Proyecto referencia/**` and vendored `android/app/src/main/cpp/llama.cpp/**`; keep reference code out of app analysis.

## Files and directories to treat carefully

- `Proyecto referencia/`: read-only inspiration/reference, not part of Aprendo+ app code.
- `android/app/src/main/cpp/llama.cpp/`: vendored legacy source; do not edit casually. It is no longer wired into `android/app/build.gradle`.
- `assets/models/`: do not assume large models are versioned; current app expects external `.task` installation.
- `scripts/download_model.py` and `scripts/quantize_model.py`: GGUF/llama.cpp-era tooling; verify before using for the current `flutter_gemma` path.
- `openspec/`: SDD artifacts exist, but `openspec/config.yaml` contains stale prose about pre-implementation and MethodChannel. Trust executable code/config over that prose.
- `IDEA E INVSTIGAION PARA EL PROYECTO/`: ISO 15288 traceability docs; useful for requirements language, not build truth.

## Database and keystore gotcha

Database uses `sqflite_sqlcipher` and `PRAGMA cipher_memory_security = ON`. The Dart keystore wrapper exists, but Android `MainActivity.kt` currently returns `notImplemented()` for key storage methods, so verify encryption-key behavior before relying on Android Keystore claims.

## Current repo state

No `.github/workflows/`, no `opencode.json`, and no root `README*` were found. Many files are still untracked in git; check `git status --short` before destructive edits.
