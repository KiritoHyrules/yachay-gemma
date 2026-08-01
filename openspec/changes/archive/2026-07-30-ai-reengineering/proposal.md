# Proposal: AI Reengineering — XML Tool Dispatcher + Streaming

## Intent

Replace Aprendo+'s free-form text generation (`GemmaService`, temp=0.7, no output constraints, single JSON fallback) with a hybrid architecture drawn from 3 Gemma 2026 competitors: XML tool calling (gemma-chat), GBNF grammar constraints + layered fallback (LIKAS), and streaming metrics (gemma-vision). The current AI layer lacks output safety, dispatch logic, and graceful degradation — all 3 reference projects demonstrate production-quality patterns that can be adapted while preserving our llama.cpp + GGUF native stack.

**Stakeholder needs**: N-01 (explicaciones comprensibles), N-03 (diagnóstico sin estigma), N-04 (offline-first).  
**System requirements**: SR-B02 (Gemma on-device para explicaciones + detección de errores + ejercicios), SR-B07 (inferencia completamente offline, compatible con 2GB RAM).

## Scope

### In Scope (Hackathon MVP: 5-7h)

| Gap | Deliverable | Est. |
|-----|-------------|------|
| **3. Conservative Sampling** | temp=0.4, topK=40, topP=0.85, repeat_penalty=1.1, maxTokens=1024 | LOW |
| **4. Layered Fallback (4 layers)** | Greeting gate → keyword router → deterministic tool execution → generic fallback | MED |
| **5. Tool Interface for Diagnostics** | `run_diagnostic`, `get_lesson`, `generate_exercise`, `get_student_profile`, `get_explanation` tool wrappers | MED |
| **2. XML Tool Dispatcher** | `procesarMensaje()` dispatch loop, `ParsedAction` discriminator, `<action>` XML parser, 5-round agent loop, `detectForcedTool` rescue path | HIGH |
| **Streaming API** | `procesarMensaje(onToken, onComplete)` with `MessageStats` metrics, UI throttling every 3 tokens | MED |

### Out of Scope

- GBNF grammar constraints (Gap 1) — XML parsing is reliable enough for MVP; grammar is post-hackathon
- Database schema extension (Gap 7) — stretch goal only if time permits
- Model download pipeline + SHA256 (Gap 8) — post-hackathon
- Fine-tuning dataset (Gap 9) — post-hackathon
- Test infrastructure (Gap 6) — skeleton tests remain; real TDD deferred

## Capabilities

### New Capabilities
- `ai-tool-dispatcher`: XML-based tool calling with dispatch loop, action parsing, and 4-layer fallback
- `ai-grammar-constraint`: GBNF grammar builder for output safety (stretch goal)
- `ai-streaming`: Token-level streaming API with metrics and UI throttling

### Modified Capabilities
- `gemma-inference`: Sampling parameters, max tokens, sampler chain — changed but behavior is backward-compatible
- `diagnostic-engine`: Refactored to expose tool-invokable interface alongside existing UI-callback API

## Approach

**Keep llama.cpp + GGUF** — no framework migration. Add 3 layers on top:

1. **Sampling layer** (cpp): Conservative params in `gemma_engine.cpp` sampler chain — immediate safety win
2. **Dispatch layer** (Dart): `GemmaService.procesarMensaje()` replaces monolithic `generarExplicacion()`/`generarEjerciciosRefuerzo()`. XML `<action>` blocks parsed into `speak | tool` discriminators. Tool results fed back to model (max 5 rounds)
3. **Streaming layer** (Dart→Kotlin): New MethodChannel method `generateStream` passes tokens to Dart callback, throttled to UI at 3-token intervals

**Execution order**: Sampling → Fallback → Tool Interface → Streaming → Dispatcher

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/modules/gemma/gemma_service.dart` | Modified | Replaced with dispatch loop + streaming API |
| `lib/modules/gemma/action_parser.dart` | New | XML action parser, tool arg extraction |
| `lib/modules/gemma/tool_registry.dart` | New | Education-domain tool registry (6 tools) |
| `lib/modules/gemma/tool_handlers/` | New | Per-tool handler files |
| `lib/modules/gemma/fallback_dispatcher.dart` | New | 4-layer deterministic fallback |
| `android/.../cpp/gemma_engine.cpp` | Modified | Conservative sampling chain |
| `lib/modules/diagnostico/diagnostico_service.dart` | Modified | Tool-invokable interface |
| `assets/data/fallback_responses.json` | Modified | Keyword→action mappings |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Dispatcher breaks free-form tutoring (Gap 2 = HIGH) | High | Feature-gate behind config flag; fallback dispatcher works independently |
| XML parsing unreliable on 2B quantized model | Medium | `repairXml()` recovery; `detectForcedTool` skips parsing entirely |
| Streaming blocks UI thread on 2GB devices | Low | 3-token throttle; `isolate` compute if needed |

## Rollback Plan

`GemmaService` preserves original `generarExplicacion()`/`generarEjerciciosRefuerzo()` as private methods. The new `procesarMensaje()` is gated by `useXmlDispatch` flag (default `true`). Revert to old behavior: change flag to `false` — no code deletion needed.

## Dependencies

- Sampling (Gap 3) must complete before dispatcher (Gap 2) — dispatcher reuses new params
- Tool interface (Gap 5) must complete before dispatcher — handlers must exist
- Fallback (Gap 4) depends on tool handlers from Gap 5

## Success Criteria

- [ ] `procesarMensaje("explícame fracciones")` returns tool-dispatched explanation (not free-form text)
- [ ] Model emits valid `<action>` XML in ≥70% of test prompts
- [ ] Fallback dispatcher returns pedagogically sound response when model fails
- [ ] Streaming delivers first token in <3s on reference device (2GB RAM)
- [ ] `flutter build apk --debug` succeeds with all changes
