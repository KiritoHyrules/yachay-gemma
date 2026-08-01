# Design: AI Reengineering — XML Tool Dispatcher + Streaming

## Technical Approach

Replace `GemmaService`'s 2 monolithic methods (`generarExplicacion`, `generarEjerciciosRefuerzo`) with a single `procesarMensaje()` dispatch loop backed by XML tool calling, conservative sampling, and token-level streaming. Keep llama.cpp + GGUF; add 3 layers on top: sampling (C++), dispatch (Dart), streaming (Dart→Kotlin bridge). Preserve legacy methods behind `useXmlDispatch` flag.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| Tool format | XML `<action name="x"><param>v</param></action>` | JSON (LIKAS) | XML survives partial streaming without JSON parse errors; gemma-chat's `emitSafeBoundary` prevents split tags; matches reference pattern |
| Streaming bridge | MethodChannel `generateStream` with callback | EventChannel | EventChannel adds lifecycle complexity; MethodChannel callback pattern is proven in gemma-vision reference; simpler for 5-7h hackathon |
| Inference engine | llama.cpp via JNI | flutter_gemma plugin | Already vendored in `android/app/src/main/cpp/llama.cpp/`; flutter_gemma bundles its own llama.cpp → binary bloat conflict; JNI avoids migration risk |
| Grammar | Deferred (post-hackathon) | GBNF now | XML parsing + `detectForcedTool` rescue is sufficient for MVP ≥70% success rate; grammar adds C++ complexity + malformed grammar crash risk |

## Data Flow

### Streaming Dispatch Loop

```
Dart: procesarMensaje(prompt)
  │
  ├─ Feature gate: useXmlDispatch? → no → legacy methods → RETURN
  │
  ├─ FallbackDispatcher.dispatch(prompt) → 4 layers
  │     L1: Trivial greeting? → instant speak
  │     L2: Keyword match? → tool with bundled data
  │     L3: Tool locally (model unavailable)
  │     L4: Generic encouragement
  │
  └─ Model available → dispatch loop (max 5 rounds):
       LOOP:
         ┌─ sendWithStreaming(prompt, onToken, onComplete)
         │    ├─ Dart: MethodChannel('generateStream', {prompt, …params})
         │    ├─ Kotlin: generateStream() → JNI → C++ sampler chain → token callback
         │    └─ Dart: onToken every 3rd token (UI throttle)
         ├─ findNextAction(buffer) → ParsedAction?
         │    ├─ speak → return accumulated text
         │    └─ tool  → ToolRegistry.run(name, args, ctx) → feed result to LOOP
         └─ detectForcedTool(): keyword→tool rescue when XML parse fails
```

### Token Bridge Detail

```
Dart GemmaService            Kotlin GemmaEngine           C++ gemma_engine.cpp
      │                            │                            │
      │── invokeMethod(            │                            │
      │   'generateStream',        │                            │
      │   {prompt, params})        │                            │
      │                            │── generateStreamJni() ────>│
      │                            │                            │── sampler chain
      │                            │    <── token callback ─────│   (temp→topK→topP
      │    <── result.success ─────│    (per token)             │    →penalties→dist)
      │    (every 3rd token        │                            │
      │     via throttle)          │                            │
```

## Dispatch Loop State Machine

```
START → FEATURE_GATE(useXmlDispatch?)
  → [no] LEGACY_METHOD → RETURN
  → [yes] GREETING_GATE(regex)
      → [match] SPEAK → RETURN
      → [no] KEYWORD_ROUTER
          → [match] EXECUTE_TOOL → SPEAK → RETURN
          → [no] MODEL_INFERENCE
              → PARSE_OUTPUT
                  → {speak}: RETURN
                  → {tool}: EXECUTE_TOOL → FEED_RESULT → MODEL_INFERENCE (loop)
                  → {xml_error}: detectForcedTool → EXECUTE_TOOL → RETURN
              → MAX_ROUNDS(5) → force speak → RETURN
```

## Sampling Configuration (C++ Sampler Chain)

After change, `gemma_engine.cpp` builds:

```cpp
auto sparams = llama_sampler_chain_default_params();
g_state.smpl = llama_sampler_chain_init(sparams);
llama_sampler_chain_add(g_state.smpl, llama_sampler_init_temp(0.4));
llama_sampler_chain_add(g_state.smpl, llama_sampler_init_top_k(64));
llama_sampler_chain_add(g_state.smpl, llama_sampler_init_top_p(0.85));
llama_sampler_chain_add(g_state.smpl, llama_sampler_init_penalties(
    n_ctx, 1.1, 0.0, 0.0));  // repeat_penalty=1.1
llama_sampler_chain_add(g_state.smpl, llama_sampler_init_dist(42));
```

Previously: only `init_temp(0.7)` + `init_dist(42)`. maxTokens: 256 → 1024.

## Component Design

### File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/modules/gemma/gemma_service.dart` | Modify | Replace 2 monolithic methods with `procesarMensaje()`. Add `SamplingConfig`, `sendWithStreaming()`. Preserve legacy as private behind `useXmlDispatch` flag |
| `lib/modules/gemma/action_parser.dart` | Create | `findNextAction()`, `repairXml()`, `parseActionBody()`, `emitSafeBoundary()` — mirrors gemma-chat `tools.ts:508-579` |
| `lib/modules/gemma/tool_registry.dart` | Create | `ToolRegistry` with 6 tools: `explicar_tema`, `generar_ejercicios`, `ejecutar_diagnostico`, `obtener_perfil`, `obtener_leccion`, `registrar_interaccion` |
| `lib/modules/gemma/fallback_dispatcher.dart` | Create | 4-layer dispatch: greeting gate → keyword router → tool execution → generic defaults |
| `lib/modules/gemma/grammar_builder.dart` | Create | Skeleton only — GBNF builder deferred to post-hackathon |
| `lib/modules/gemma/tool_handlers/` (6 files) | Create | Per-tool wrappers calling existing services |
| `lib/core/models/message_stats.dart` | Create | `MessageStats`: `timeToFirstToken`, `totalLatency`, `tokenCount`, `decodeSpeed` |
| `android/.../GemmaEngine.kt` | Modify | Add `handleGenerateStream()` with per-token callback; pass `topP`, `topK`, `repeatPenalty` args |
| `android/.../cpp/gemma_engine.cpp` | Modify | New `generateStreamJni()` with token callback; extend sampler chain from 2 to 5 samplers |
| `assets/data/fallback_responses.json` | Modify | Add `trivial_greetings`, `keyword_intents`, `generic_responses` sections |
| `lib/modules/diagnostico/diagnostico_service.dart` | Modify | Add `ejecutarComoHerramienta()` returning `ToolResult` (no UI callbacks) |

### Rollback Architecture

```
GemmaService.procesarMensaje(prompt)
  ├── useXmlDispatch == true  → dispatch loop (new)
  └── useXmlDispatch == false → _generarExplicacion() / _generarEjerciciosRefuerzo() (legacy)
```

Legacy methods preserved, not deleted. Default: `true`. Revert: set `false` in one place.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Action parser (pure Dart) | `findNextAction` on valid/invalid/malformed XML; `repairXml` recovery; `emitSafeBoundary` edge cases |
| Unit | Fallback dispatcher | Greeting regex, keyword→tool mappings, layer 4 generic output |
| Integration | Tool handler execution | Each handler with mock `ToolContext` returns valid `ToolResult` |
| Build | APK integrity | `flutter build apk --debug` must succeed |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. MethodChannel is standard Flutter IPC.

## Open Questions

None — all design decisions resolved in exploration gap analysis.
