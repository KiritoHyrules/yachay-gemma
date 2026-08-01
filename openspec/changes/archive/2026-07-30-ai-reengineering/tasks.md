# Tasks: AI Reengineering — XML Tool Dispatcher + Streaming

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1100–1200 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (Sampling) → PR 2 (Fallback) → PR 3 (Tool Interface) → PR 4 (Streaming) → PR 5 (Dispatcher) |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Conservative sampling params | PR 1 | `flutter build apk --debug` | `flutter build apk --debug` | Revert sampler chain additions + SamplingConfig constant |
| 2 | 4-layer fallback system | PR 2 | `flutter test test/modules/gemma/fallback_dispatcher_test.dart` | `flutter test` (greeting regex, keyword routing) | Delete fallback_dispatcher.dart + remove _dispatchFallback wiring |
| 3 | 6 tool handlers registered | PR 3 | `flutter test test/modules/gemma/tool_registry_test.dart` | `flutter test` (handler execution with mock context) | Delete lib/modules/gemma/tool_handlers/ + ToolRegistry wiring |
| 4 | Token streaming bridge | PR 4 | `flutter build apk --debug` | `flutter build apk --debug` | Remove generateStreamJni + kotlin generateStream handler |
| 5 | XML dispatch loop | PR 5 | `flutter test test/modules/gemma/action_parser_test.dart` | `flutter test` + `flutter build apk --debug` | Set useXmlDispatch=false → legacy methods |

## Phase 1: Sampling — Conservative Parameters [CPP][KT][DART]

- [x] 1.1 [CPP] Extend sampler chain in `gemma_engine.cpp:182–186` from 2 to 5 samplers: `init_temp` → `init_top_k` → `init_top_p` → `init_penalties` → `init_dist`. Add `topK`, `topP`, `repeatPenalty` args to `generateJni` signature. Free sampler at end.
- [x] 1.2 [KT] Update `GemmaEngine.kt` `handleGenerate()` to extract `topK`, `topP`, `repeatPenalty` from MethodChannel args map. Pass to `generateJni` call.
- [x] 1.3 [DART] Create `SamplingConfig` constant (temp=0.4, topK=64, topP=0.85, repeatPenalty=1.1, maxTokens=1024) in `gemma_service.dart`. Pass through MethodChannel args. Support caller override of individual params.

## Phase 2: Fallback — 4-Layer System [DART]

- [x] 2.1 [DART] Create `lib/modules/gemma/fallback_dispatcher.dart`: implement `dispatch(mensaje, context) → Future<String>` with 4 layers: L1 greeting regex short-circuit, L2 keyword→tool mapping from fallback JSON, L3 deterministic tool execution via ToolRegistry, L4 generic Peruvian-Spanish encouragement.
- [x] 2.2 [DART] Extend `assets/data/fallback_responses.json`: add `trivial_greetings` (regex→response), `keyword_intents` (keyword→{tool, args}), `generic_responses` (encouragement strings).
- [x] 2.3 [DART] Wire `FallbackDispatcher` into `GemmaService`: replace `_fallbackExplicacion`/`_fallbackEjercicios` with `_dispatchFallback(userMessage)`. Route TimeoutException, PlatformException, OOM, and empty-response paths through it.

## Phase 3: Tool Interface — 6 Handlers [DART]

- [x] 3.1 [DART] Create `lib/modules/gemma/tool_registry.dart`: `ToolRegistry` with `register(name, handler)`, `run(name, args, ctx)`, `ToolResult` model (`{summary, payload}`), `ToolContext`. Register all 6 tools by name.
- [x] 3.2 [DART] Create `lib/modules/gemma/tool_handlers/`: `explicar_tema.dart` (lesson content), `generar_ejercicios.dart` (exercise generation), `ejecutar_diagnostico.dart` (IRT diagnostic), `obtener_perfil.dart` (student profile), `obtener_leccion.dart` (lesson lookup), `registrar_interaccion.dart` (audit log). Each: `handler(args, ctx) → Future<ToolResult>`.
- [x] 3.3 [DART] Add `DiagnosticoService.ejecutarComoHerramienta(materia, perfil) → Future<ToolResult>` to `lib/modules/diagnostico/diagnostico_service.dart` — tool-mode wrapper without UI callbacks.

## Phase 4: Streaming — Token Bridge [CPP][KT][DART]

- [x] 4.1 [CPP] Add `generateStreamJni` to `gemma_engine.cpp`: per-token callback via JNI `env→CallVoidMethod`. Reuse extended 5-sampler chain from Phase 1. Emit each token immediately to Kotlin callback.
- [x] 4.2 [KT] Add `handleGenerateStream()` to `GemmaEngine.kt`: register `'generateStream'` MethodChannel method. Bridge per-token JNI callback → Kotlin callback issued on main thread. Throttle to every 3rd token via counter.
- [x] 4.3 [DART] Create `lib/core/models/message_stats.dart`: `MessageStats` with `timeToFirstToken` (sec), `totalLatency` (sec), `tokenCount` (int), `decodeSpeed` (tokens/sec).
- [x] 4.4 [DART] Add `sendWithStreaming(prompt, {onToken, onComplete})` to `GemmaService`: invoke `generateStream`, accumulate tokens, call `onToken` every 3rd token (UI throttle), call `onComplete` with `MessageStats` on finish.

## Phase 5: Dispatcher — XML Dispatch Loop [DART]

- [x] 5.1 [DART] Create `lib/modules/gemma/action_parser.dart`: `findNextAction(text, from)` → `ParsedAction|"incomplete"|null`. `repairXml()`, `parseActionBody()`, `emitSafeBoundary()`. `detectForcedTool(mensaje)` → tool name as rescue for malformed XML.
- [x] 5.2 [DART] Implement `procesarMensaje(mensaje)` in `GemmaService`: feature gate `useXmlDispatch` → dispatch loop max 5 rounds. Each round: `sendWithStreaming` → `findNextAction` → speak(return text) / tool(execute→feed result→loop). Force forced-tool on round 5 exhaustion.
- [x] 5.3 [DART] Create `lib/modules/gemma/grammar_builder.dart` skeleton: stub `buildGrammar(toolRegistry)` returning empty string. Deferred to post-hackathon per ADR.
- [x] 5.4 [DART] Preserve legacy `generarExplicacion`/`generarEjerciciosRefuerzo` as public methods gated behind `useXmlDispatch=false`. Production default: `true`.
- [x] 5.5 [DART] Verify: `flutter build apk --debug` succeeds with all 14 new/modified files compiled and linked.
