```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:a62a71ce209479f76a6d541d13aefe896a03feb962ce84d0b6d38d22d4866837
verdict: fail
blockers: 1
critical_findings: 2
requirements: 13/15
scenarios: 18/21
test_command: flutter test test/modules/gemma/
test_exit_code: 1
test_output_hash: sha256:120bf17211f8759b176e13f96d70f1999b610218f52e873637fb4ddaa71ec55b
build_command: flutter build apk --debug
build_exit_code: 1
build_output_hash: sha256:0351f12a30a9a6fc7f6f66f4331a5d01194ad58300de5efb4247d252b138d39a
```

## Verification Report

**Change**: ai-reengineering
**Version**: N/A (all specs are delta specs)
**Mode**: Standard (strict TDD false per AGENTS.md)

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 25 |
| Tasks complete | 25 |
| Tasks incomplete | 0 |

### Build & Tests Execution

**Build**: ❌ Failed — Kotlin compilation error
```
e: file:///.../GemmaEngine.kt:177:26 Unresolved reference 'generateJni'.
```
Root cause: `GemmaEngine.kt` calls `generateJni()` at line 177 in `handleGenerate()` but the external JNI declaration is missing. The external declarations are: `loadModelJni`, `generateStreamJni`, `unloadModelJni` — `generateJni` was removed during Phase 4 streaming refactor. C++ `Java_com_aprendoplus_app_GemmaEngine_generateJni` exists at gemma_engine.cpp:134-232.

**Tests**: ✅ 76 passed / ❌ 6 failed

```
flutter test test/modules/gemma/
00:00 +76 -6: Some tests failed.
```

**Failure breakdown**:

| # | Test | File | Error | Category |
|---|------|------|-------|----------|
| 1 | `emitSafeBoundary` — buffer `"<a"` | action_parser_test.dart:506 | Expected 12, got 14 | BUG: emitSafeBoundary doesn't protect `<a` partial |
| 2 | `emitSafeBoundary` — buffer with complete `</action>` | action_parser_test.dart:493 | Expected 78, got 0 | BUG: emitSafeBoundary holds at opening `<action` even when `</action>` present |
| 3 | `emitSafeBoundary` — buffer `"<act"` | action_parser_test.dart:479 | Expected ≤26, got 30 | BUG: doesn't detect `<act` as partial `<action` |
| 4 | `sendWithStreaming` args propagation | streaming_test.dart:185 | Expected not null | TEST DESIGN: model-not-loaded guard prevents mock invocation |
| 5 | `sendWithStreaming` 3-token throttle | streaming_test.dart:278 | Expected ≥1 batch | TEST DESIGN: same root cause as #4 |
| 6 | `sendWithStreaming` onComplete stats | streaming_test.dart:358 | Expected 4 tokens | TEST DESIGN: same root cause as #4 |

**Static Analysis**: `flutter analyze` — 2 warnings, 13 infos (0 errors)
- WARNING: Unused variable `lastEnd` in `action_parser.dart:148`
- WARNING: Unused element `_fallbackExplicacion` in `gemma_service.dart:622`

**Coverage**: ➖ Not available (no coverage tool configured)

### Spec Compliance Matrix

#### ai-sampling (3 requirements, 4 scenarios)

| Requirement | Scenario | Evidence | Result |
|-------------|----------|----------|--------|
| Conservative Sampling Config | Inference uses conservative parameters | `gemma_engine.cpp:186-194` — 5-sampler chain with temp=0.4, topK, topP, penalties, dist | ✅ COMPLIANT (source-verified) |
| Conservative Sampling Config | Backward-compatible parameter override | `gemma_service.dart:776-794` `_buildSamplingArgs()` accepts overrides | ✅ COMPLIANT |
| SamplingConfig Pass-Through | Dart-to-native parameter flow | `streaming_test.dart:196` verifies args in MethodChannel; `GemmaEngine.kt:160-163` extracts args | ⚠️ PARTIAL (streaming test fails #4, but Kotlin extraction is source-verified) |
| Sampler Chain (C++) | Complete sampler chain initialization | `gemma_engine.cpp:186-194` — exact 5-sampler order | ✅ COMPLIANT (source-verified) |

#### ai-fallback (2 requirements, 4 scenarios)

| Requirement | Scenario | Evidence | Result |
|-------------|----------|----------|--------|
| 4-Layer Fallback System | Greeting short-circuits all layers | `fallback_dispatcher_test.dart` tests 1,2 — passed | ✅ COMPLIANT |
| 4-Layer Fallback System | Keyword routes to tool | `fallback_dispatcher_test.dart` tests 3,4,5 — passed | ✅ COMPLIANT |
| 4-Layer Fallback System | Unmatched query reaches layer 4 | `fallback_dispatcher_test.dart` test 7 — passed | ✅ COMPLIANT |
| Emergency Fallback | Inference timeout triggers fallback | `gemma_service.dart:165-174, 338-353` — TimeoutException handlers route through `_dispatchFallback` | ⚠️ PARTIAL (source-verified; streaming timeout test #6 is TEST DESIGN issue, not implementation) |

#### ai-tool-dispatcher (6 requirements, 8 scenarios)

| Requirement | Scenario | Evidence | Result |
|-------------|----------|----------|--------|
| XML Action Format | Model emits valid action | `action_parser_test.dart` Group 1 (4 tests) — all passed | ✅ COMPLIANT |
| Action Parser | Parse complete action | `action_parser_test.dart` Group 1 — all passed | ✅ COMPLIANT |
| Action Parser | Incomplete action during streaming | `action_parser_test.dart` Group 2 (4 tests) — all passed | ⚠️ PARTIAL (findNextAction passes; emitSafeBoundary edge cases fail #1,2,3) |
| Dispatch Loop | Single tool call resolves | `action_parser_test.dart` Group 6 test 1 — passed | ✅ COMPLIANT |
| Dispatch Loop | Max rounds exhausted | `gemma_service.dart:508-521` force-speak on round 5 exhaustion + detectForcedTool rescue | ✅ COMPLIANT (source-verified) |
| Tool Registry | Tool handler execution | `tool_registry_test.dart` Groups 2-7 (19 tests) — all passed | ✅ COMPLIANT |
| Forced Tool Detection | Rescue after XML parse failure | `action_parser_test.dart` Group 3 (4 tests) — all passed | ✅ COMPLIANT |
| Feature Gate | Feature gate disabled | `action_parser_test.dart` Group 6 tests 1,4,5 — all passed | ✅ COMPLIANT |

#### ai-streaming (4 requirements, 5 scenarios)

| Requirement | Scenario | Evidence | Result |
|-------------|----------|----------|--------|
| Streaming MethodChannel Bridge | Streaming with event sink | `gemma_engine.cpp:262-397` `generateStreamJni` with per-token `CallVoidMethod`; `GemmaEngine.kt:210-284` `handleGenerateStream` with `TokenCallback` | ⚠️ PARTIAL (source-verified; streaming tests #4,5,6 fail due to model-not-loaded guard in Dart) |
| Streaming API Contract | Happy path streaming call | `gemma_service.dart:259-383` `sendWithStreaming` with `onToken`/`onComplete` | ⚠️ PARTIAL (source-verified; test #5 fails — throttle can't fire without loaded model) |
| Streaming API Contract | Streaming fails gracefully | `gemma_service.dart:267-272` returns `MessageStats(tokenCount: 0)` when model not loaded | ✅ COMPLIANT |
| Token Throttling | UI throttle at 3-token intervals | `gemma_service.dart:296-301` — 3-token buffer flush | ⚠️ PARTIAL (source-verified; test #5 blocked by model guard) |
| MessageStats Metrics | Accurate performance metrics | `streaming_test.dart` Group 1 (4 tests) — all passed | ✅ COMPLIANT |

**Compliance summary**: 18/21 scenarios compliant or partially compliant (source-verified where runtime test blocked)

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| SamplingConfig (temp=0.4, topK=64, topP=0.85, repeatPenalty=1.1) | ✅ Implemented | `gemma_service.dart:26-44`, C++ chain matches |
| 4-layer fallback (greeting→keyword→tool→generic) | ✅ Implemented | `fallback_dispatcher.dart:19-228`, all 11 tests pass |
| 6 tool handlers + ToolRegistry | ✅ Implemented | All 26 tests pass, all 6 tools with specs and handlers |
| Streaming bridge (C++→Kotlin→Dart) | ✅ Source-verified | `generateStreamJni` in C++, `handleGenerateStream` in Kotlin, `sendWithStreaming` in Dart |
| XML action parser | ⚠️ Implemented with edge-case bugs | `action_parser.dart`: `findNextAction` correct, `emitSafeBoundary` has 3 boundary-detection bugs |
| Dispatch loop (max 5 rounds) | ✅ Implemented | `gemma_service.dart:407-524`, feature gate works |
| Legacy method preservation | ✅ Implemented | `generarExplicacion` and `generarEjerciciosRefuerzo` preserved behind `useXmlDispatch=false` |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| XML format `<action name="x"><param>v</param></action>` | ✅ Yes | `action_parser.dart` regex matches design.md format |
| Streaming via MethodChannel callback | ✅ Yes | `generateStream` MethodChannel + `gemma_engine_stream` event channel |
| llama.cpp via JNI (not flutter_gemma plugin) | ✅ Yes | `gemma_engine.cpp` uses JNI with `llama.h` |
| Grammar deferred (stub only) | ✅ Yes | `grammar_builder.dart:24` returns empty string per ADR |
| 5-round dispatch loop | ✅ Yes | `gemma_service.dart:426` `for (int round = 0; round < 5; round++)` |
| One-flag rollback (useXmlDispatch) | ✅ Yes | `gemma_service.dart:83` static flag, `procesarMensaje()` routes to legacy when false |
| Legacy methods preserved | ✅ Yes | Public methods `generarExplicacion()` and `generarEjerciciosRefuerzo()` retained |
| Chained PR delivery (stacked-to-main) | ✅ Yes | 5 PRs delivered in stacked order across 5 phases |

### Issues Found

**CRITICAL**:
1. **BUILD FAILS**: `GemmaEngine.kt:177` — `Unresolved reference 'generateJni'`. The external JNI declaration for `generateJni` is missing from `GemmaEngine.kt` lines 287-313. The C++ function `Java_com_aprendoplus_app_GemmaEngine_generateJni` exists at `gemma_engine.cpp:134-232` with correct 7-parameter signature. The `handleGenerate()` method cannot compile. Fix: add `private external fun generateJni(ctx: Long, prompt: String, maxTokens: Int, temperature: Double, topP: Double, topK: Int, repeatPenalty: Double): String` to the Kotlin external declarations block.

**WARNING**:
1. **emitSafeBoundary edge-case bugs** (action_parser.dart:188-208): The function only protects against `<action` prefix (7+ chars) but not shorter partials like `<a` or `<act`. It also incorrectly holds back at an opening `<action` even when a closing `</action>` is present in the buffer. Affects 3 of 34 action_parser tests. Impact: during streaming, partially-formed action tags shorter than `<action` may be emitted to the UI prematurely.
2. **Unused element `_fallbackExplicacion`** (gemma_service.dart:622): Legacy fallback method is no longer referenced — `_dispatchFallback` has replaced all call sites. Consider removing or marking `@visibleForTesting`.
3. **Streaming tests #4-6 fail due to test design**: `sendWithStreaming` correctly guards against unloaded model, but the mock infrastructure returns before the stream channel is set up. Tests need to mock `_modeloCargado` as `true` or simulate model loading.

**SUGGESTION**:
1. **`analysis_options.yaml` compliance**: 13 `info`-level lint suggestions across action_parser, gemma_service, and tool handlers (prefer_final_locals, prefer_const_constructors, prefer_conditional_assignment, unnecessary_const). None are errors.
2. **AGP/Kotlin version warnings**: Android Gradle Plugin 8.9.1 and Kotlin 2.0.21 are below Flutter's recommended minimums (8.11.1 and 2.2.20 respectively). Not blocking for hackathon but will cause deprecation at next Flutter update.
3. **Coverage tooling**: No test coverage tool configured. Recommend adding `test_coverage` to `opencode.json` for future SDD cycles.

### Verdict

**FAIL**

Blocked by Kotlin compilation error — `generateJni` external declaration missing from `GemmaEngine.kt`, preventing APK build. Must be fixed before archive. 13 of 15 requirements have source-verified or tested implementation; 18 of 21 scenarios are compliant or partially compliant (source-verified where runtime tests were blocked by model-not-loaded guard). 3 `emitSafeBoundary` edge-case bugs exist in the action parser but do not break core dispatch functionality.
