# Tasks: flutter-gemma-migration

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~500 authored (rewrite + new files) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (pubspec + service rewrite) → PR 2 (native removal + verify) |
| Delivery strategy | ask-on-risk |
| Chain strategy | feature-branch-chain |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| # | Goal | PR | Focused test | Runtime harness | Rollback boundary |
|---|------|----|-------------|-----------------|-------------------|
| 1 | Add flutter_gemma + rewrite GemmaService | PR 1 | `flutter test test/gemma_service_migration_test.dart` | `flutter build apk --debug` (may still have CMake refs) | Revert gemma_service.dart + pubspec.yaml |
| 2 | Remove native code + verify build | PR 2 | `flutter build apk --debug` | `flutter test` (all specs) | Restore cpp/ + GemmaEngine.kt from `legacy-llamacpp` branch |

## Phase 1: Plugin + Model Download (PR 1 · feature-branch-chain base)

- [x] 1.1 [RED] Write failing test `GemmaServiceMigrationTest`: init creates model via FlutterGemmaPlugin; download triggered when model absent
- [x] 1.2 [GREEN] Add `flutter_gemma: ^0.10.0` + `flutter_web_auth_2: ^4.1.0` to pubspec.yaml; run `flutter pub get`; create `lib/modules/gemma/model_download_service.dart` with OAuth download wrapper

## Phase 2: GemmaService Rewrite (PR 1)

- [x] 2.1 [RED] Write failing tests: (a) streaming tokens via `generateChatResponseAsync().listen()`, (b) tool execution via `FunctionCallResponse`, (c) `useFlutterGemma=false` routes to legacy path
- [x] 2.2 [GREEN] Rewrite `gemma_service.dart`: replace MethodChannel with FlutterGemmaPlugin singleton; implement `init()`, `sendWithStreaming()` using native stream + 30s timeout; add `useFlutterGemma` gate
- [x] 2.3 [GREEN] Adapt `tool_registry.dart` — add `toFlutterGemmaTools()` returning `List<Tool>`; simplify `fallback_dispatcher.dart` — move registry init to service; delete `action_parser.dart` + `grammar_builder.dart`

## Phase 3: Native Code Removal (PR 2 → tracker base: PR 1 branch)

- [x] 3.1 [GREEN] Remove `externalNativeBuild` cmake block, `aaptOptions { noCompress 'gguf' }`, and `ndk { abiFilters 'arm64-v8a' }` from `android/app/build.gradle`
- [x] 3.2 [GREEN] Remove GemmaEngine instantiation + registration from `MainActivity.kt` (lines 14, 39-45); preserve Keystore MethodChannel (lines 20-35)
- [x] 3.3 [GREEN] Delete `android/.../GemmaEngine.kt` and `android/app/src/main/cpp/` directory

## Phase 4: Integration + Build Verification (PR 2)

- [x] 4.1 [VERIFY] Run `flutter test` — all migration tests pass: init, streaming, 13 tools, fallback, feature gate (209 pass, 4 pre-existing widget test failures)
- [x] 4.2 [VERIFY] Run `flutter build apk --debug` — zero CMake/JNI references; APK 224MB (debug, flutter_gemma native .so ~200MB); no MissingPluginException for 'gemma_engine' channel

## Verification Checklist

- [ ] `git checkout legacy-llamacpp` + `flutter build apk --debug` succeeds (rollback proven)
- [ ] `useFlutterGemma = false` produces same output as pre-migration GemmaService
- [ ] All 13 ToolSpec entries map to valid flutter_gemma `Tool` objects
- [ ] `assets/data/fallback_responses.json` still loaded on model init failure
