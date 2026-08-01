# Exploration: AI Reengineering for Aprendo+

> **Change**: `ai-reengineering`
> **Date**: 2026-07-30
> **Reference**: LIKAS Disaster Companion (same Gemma 2026 competition)

## Executive Summary

Aprendo+'s current AI layer uses fully free-form text generation with no output constraints, a single-layer fallback (generic JSON lookups), and aggressive sampling parameters (temperature=0.7). The LIKAS reference project demonstrates a production-quality pattern: GBNF grammar-constrained generation → tool dispatch loop → deterministic handlers → layered fallback. This exploration maps every file, API, and data structure gap between the two systems and estimates complexity per change area.

---

## Gap Analysis

### Gap 1: GBNF Grammar Constraint (Sampling Layer)

#### Current State (Aprendo+)

`lib/modules/gemma/gemma_service.dart` calls the native `generate` MethodChannel method with:
- `prompt` (free-form text)
- `systemPrompt` (concatenated prefix)
- `maxTokens: 256` / `temperature: 0.7`

`android/app/src/main/cpp/gemma_engine.cpp:182–186` creates a sampler chain:
```cpp
auto sparams = llama_sampler_chain_default_params();
g_state.smpl = llama_sampler_chain_init(sparams);
llama_sampler_chain_add(g_state.smpl, llama_sampler_init_temp(temperature));
llama_sampler_chain_add(g_state.smpl, llama_sampler_init_dist(42));
```

There is NO grammar sampler in the chain. The model can emit arbitrary text — including hallucinations, off-topic content, malformed JSON, or inappropriate responses.

#### Target Pattern (LIKAS)

`Likas/src/services/aiGrammar.ts:76–91` builds a GBNF grammar dynamically from the tool registry. The grammar constrains the model to ONLY emit:
```json
{"action":"speak","text":"..."}
```
or
```json
{"action":"tool","name":"<registered_name>","args":{...}}
```

The grammar is passed as `grammar: grammarStr` to `ctx.completion()` via `llama.rn`.

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `lib/modules/gemma/gemma_service.dart` | New method `generarConGramatica(prompt, grammarGbnf)` that passes grammar string through MethodChannel |
| `android/app/src/main/kotlin/com/aprendoplus/app/GemmaEngine.kt` | New `handleGenerateWithGrammar(call, result)` that accepts `grammar` argument; new JNI `generateJniWithGrammar(ctx, prompt, maxTokens, temperature, grammarStr, grammarRoot)` |
| `android/app/src/main/cpp/gemma_engine.cpp` | New `generateJniWithGrammar` that initializes `llama_sampler_init_grammar(vocab, grammar_str, "root")` and adds it to the sampler chain BEFORE the temp/dist samplers |
| New file: `lib/modules/gemma/grammar_builder.dart` | Dart-side GBNF grammar construction (mirrors `aiGrammar.ts`); builds grammar per tool registry dynamically |
| New file: `lib/modules/gemma/tool_registry.dart` | Defines herramienta (tool) registry, tool schemas, and handler contracts for Aprendo+'s domain |
| `CMakeLists.txt` | No changes needed — `llama.h` already includes grammar API, and the vendored `llama.cpp` supports it. |

#### Estimated Complexity: **MEDIUM**

- Dart side is straightforward (build grammar string, pass through channel)
- Native JNI addition is ~50-70 lines of C++
- Risk: GBNF grammar validation — malformed grammar causes `llama_sampler_init_grammar` to return NULL, which must be handled gracefully
- **Dependency**: Gap 2 (Tool Registry must exist before grammar builder can reference it)

---

### Gap 2: Tool Dispatcher Pattern

#### Current State (Aprendo+)

`GemmaService` has two monolithic methods:
- `generarExplicacion()` — builds prompt, calls `generate`, parses plain text
- `generarEjerciciosRefuerzo()` — builds prompt with JSON format instructions, attempts `jsonDecode` on response

There is **no dispatch loop**, **no tool call parsing**, **no action/intent discrimination**. The model's output can be anything. There is zero runtime safety.

`assets/data/fallback_responses.json` is structured as `topicId → level → {explicacion, ejercicios}`. No keyword-based routing. No forced-action detection. No intermediate tool layer.

#### Target Pattern (LIKAS)

`Likas/src/services/aiAssistantService.ts:680–1004` implements a **dispatch loop**:

```
1. Detect trivial greetings → fast-path response (no model)
2. If model not loaded → keyword-based fallback (POI, evac, protocol)
3. Run completion with GBNF grammar constraint
4. Parse action: speak → stream text to user
5. Parse action: tool → execute handler → feed result back to model → repeat (max 3 tool calls)
6. At every failure point → deterministic fallback
```

`Likas/src/services/aiTools.ts:324–329` defines a typed `TOOL_REGISTRY` with schema, description, and async handler per tool.

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `lib/modules/gemma/gemma_service.dart` | **Major refactor**: Replace `generarExplicacion()`/`generarEjerciciosRefuerzo()` with a single `procesarMensaje()` dispatch loop. Implement action parsing (`ParsedAction` discriminator), streaming speak output, tool call execution, and the tool→result→model loop. |
| New file: `lib/modules/gemma/action_parser.dart` | JSON object extraction, `repairAssistantJson`, `parseAction`, `extractToolArgs` (mirrors LIKAS's `aiAssistantService.ts:429–643`) |
| New file: `lib/modules/gemma/tool_registry.dart` | `HerramientaRegistro` class with name, description, schema, and `Future<ToolResult> handler(Map<String, dynamic> args, ToolContext ctx)` |
| New file: `lib/modules/gemma/tool_handlers/` | Per-tool handler files: `run_diagnostic.dart`, `get_lesson.dart`, `generate_exercise.dart`, `get_student_profile.dart`, `get_explanation.dart` |
| `assets/data/fallback_responses.json` | Add keyword-to-tool mapping layer AND keep existing topic→level responses as fallback within tools |
| `lib/modules/gemma/fallback_dispatcher.dart` | New file: deterministic keyword router that mirrors LIKAS's `detectForcedTool` + `fallbackResponse` pattern, adapted for education domain |

#### Estimated Complexity: **HIGH**

- This is the single biggest change — it rewrites the entire GemmaService interaction model
- Requires ~400-600 lines of new Dart code across 4-5 files
- Requires implementing 4-5 tool handlers, each with their own dependency on existing services
- **Dependency**: Gap 1 (grammar must work for tool dispatch to be reliable)
- **Dependency**: Gap 5 (diagnostics must expose a tool interface)

---

### Gap 3: Conservative Sampling Parameters

#### Current State (Aprendo+)

```dart
'maxTokens': 256,
'temperature': 0.7,
```

Hardcoded in `gemma_service.dart` lines 97-103. `llama_sampler_init_temp(temperature)` and `llama_sampler_init_dist(42)` are the only samplers.

#### Target Pattern (LIKAS)

```typescript
const SAMPLING = {
  temperature: 0.4,
  top_p: 0.85,
  top_k: 40,
  repeat_penalty: 1.1,
  n_predict: 1024,
};
```

Plus `llama_sampler_init_penalties` for repeat penalty.

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `lib/modules/gemma/gemma_service.dart` | Replace hardcoded params with a `SamplingConfig` constant: temp=0.4, topP=0.85, topK=40. Increase maxTokens to 512-1024 (tool dispatch typically needs more tokens for JSON + follow-up speak). Add `repeatPenalty` to MethodChannel args. |
| `android/app/src/main/kotlin/com/aprendoplus/app/GemmaEngine.kt` | Pass `topP`, `topK`, `repeatPenalty` through MethodChannel call arguments |
| `android/app/src/main/cpp/gemma_engine.cpp` | Add `llama_sampler_init_top_p(topP)`, `llama_sampler_init_top_k(topK)`, `llama_sampler_init_penalties(n_ctx, repeat_penalty, ...)` to sampler chain |

#### Estimated Complexity: **LOW**

- ~30 lines changed across 3 files
- All llama.cpp APIs already available in vendored version
- No architectural risk — pure parameter tuning

---

### Gap 4: Layered Fallback System (4 Layers)

#### Current State (Aprendo+)

Single fallback layer: if model not loaded → `_cargarFallback()` → `_fallbackExplicacion(tema, nivel)` / `_fallbackEjercicios(tema, nivel)`.

Structure: `topicId → level → {explicacion, ejercicios}`. No keyword matching, no intent detection, no tool-level fallback.

#### Target Pattern (LIKAS)

4 layers:
1. **Trivial greeting gate**: Regex matches "hi/hello/kumusta" → instant response, no model needed
2. **Keyword router**: `disasterKeywords` + `detectForcedTool` → maps user phrasing to tool calls deterministically
3. **Deterministic tool execution**: Run tool handlers locally with bundled data — LLM is never called for protocol lookups, POI queries, or profile reads
4. **Generic defaults**: `fallbackResponse()` → context-aware but generic NDRRMC guidance

Additionally: every failure point in the dispatch loop falls back deterministically — not just "model not loaded."

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `lib/modules/gemma/fallback_dispatcher.dart` | New file: implements all 4 layers. Layer 1: regex greetings (hola/buenos días/gracias → instant Spanish response). Layer 2: keyword→tool mapping (fracciones/ecuaciones/porcentajes → `get_explanation`, ejercicio/practica → `generate_exercise`, diagnóstico/prueba → `run_diagnostic`). Layer 3: run tools with bundled lesson content and diagnostic items. Layer 4: generic encouragement message in Peruvian Spanish. |
| `assets/data/fallback_responses.json` | Extend with keyword→action mappings: add `trivial_greetings`, `keyword_intents`, `generic_responses` sections alongside existing `topicId→level` structure |
| `lib/modules/gemma/gemma_service.dart` | Replace `_fallbackExplicacion`/`_fallbackEjercicios` with a single `_dispatchFallback(userMessage, context)` that routes through the 4-layer system |
| `lib/modules/gemma/tool_registry.dart` | Ensure every tool handler works in fallback mode (no LLM dependency) — tools must read from bundled JSON/SQLite |

#### Estimated Complexity: **MEDIUM**

- ~200-300 lines of new Dart code
- Heavily dependent on Gap 2 (tool handlers must exist)
- The education domain has more diverse intents than LIKAS's disaster domain → more keyword patterns needed

---

### Gap 5: Diagnostics Module → Tool Interface

#### Current State (Aprendo+)

`lib/modules/diagnostico/diagnostico_service.dart` is a standalone class:
- Loaded via `DiagnosticoService.cargar()` (reads JSON from assets)
- Has `ejecutarDiagnostico(materia, onItem, onProgress)` — takes callbacks for UI interaction
- Returns `DiagnosticResult` with nivel, etiqueta, theta, precision
- NOT exposable as a tool-invokable function — requires UI callbacks (`onItem`)

#### Target Pattern (LIKAS)

Every tool has this signature:
```typescript
handler: (args: Record<string, any>, ctx: ToolContext) => Promise<ToolResult>
```

`ToolResult = { summary: string; payload?: unknown }`

Tools are self-contained; they receive args + context and return text + optional structured payload. The dispatch loop manages the conversation flow.

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `lib/modules/diagnostico/diagnostico_service.dart` | Add a static/singleton method `ejecutarComoHerramienta(materia, perfilEstudiante) → Future<ToolResult>` that: (1) loads item bank once, (2) runs IRT algorithm internally, (3) returns summary text + DiagnosticResult as payload. Remove the callback pattern for tool mode OR provide both interfaces. |
| `lib/modules/gemma/tool_handlers/run_diagnostic.dart` | New file: thin wrapper that calls `DiagnosticoService.ejecutarComoHerramienta()` and formats the result as `ToolResult` |
| `lib/core/state/student_state.dart` | May need to expose `StudentProfile` (mathLevel, readingLevel) to the ToolContext |

Other services that should become tools:

| Tool Name | Service | Current File | Status |
|-----------|---------|-------------|--------|
| `run_diagnostic` | `DiagnosticoService` | `lib/modules/diagnostico/diagnostico_service.dart` | Exists, needs tool wrapper |
| `get_lesson` | `LessonRepository` | `lib/core/database/repositories/lesson_repository.dart` | Exists, needs tool wrapper |
| `generate_exercise` | (new) | — | Needs new service or extends GemmaService |
| `get_student_profile` | `StudentRepository` | `lib/core/database/repositories/student_repository.dart` | Exists, needs tool wrapper |
| `get_explanation` | `GemmaService` (fallback) | `lib/modules/gemma/gemma_service.dart` | Exists in fallback, needs tool wrapper |
| `log_interaction` | `InteractionLog` | `lib/core/models/interaction_log.dart` | Model exists, needs tool handler |

#### Estimated Complexity: **MEDIUM**

- DiagnosticoService refactoring: ~50 lines
- Each tool handler: ~30-50 lines × 6 tools = ~200-300 lines
- Pattern is repetitive — once first tool is done, others are copy-paste-adapt
- **Dependency**: Gap 2 (ToolRegistry must accept Dart tool definitions matching the same interface)

---

### Gap 6: Test Infrastructure for Real TDD

#### Current State (Aprendo+)

```
test/
  widget_test.dart          — expect(true, isTrue)
  database_integration_test.dart — 6 tests, all expect(true, isTrue)
```

`openspec/config.yaml`:
```yaml
strict_tdd: false
test_command: ""
testing:
  runner: {available: false}
  layers:
    unit: {available: false}
    integration: {available: false}
    e2e: {available: false}
```

`pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

No `sqflite_common_ffi`, no `mockito`/`mocktail`, no test runner configured.

#### Target State

Real TDD requires:
1. `sqflite_common_ffi` for desktop database testing without Android emulator
2. Mocking framework for GemmaService, MethodChannel, and native calls
3. Test runner command in openspec config
4. Test coverage tooling
5. Golden file tests for grammar output

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `sqflite_common_ffi: ^2.3.4`, `mocktail: ^1.0.4`, `test: ^1.25.0` |
| `test/setup/test_config.dart` | New file: FFI initialization, mock setup helpers |
| `test/modules/gemma/action_parser_test.dart` | New: unit tests for JSON extraction, action parsing, tool arg extraction (mirrors `aiAssistantService` testables) |
| `test/modules/gemma/grammar_builder_test.dart` | New: unit tests verifying GBNF grammar strings compile, produce valid grammar for all tool combinations |
| `test/modules/gemma/tool_registry_test.dart` | New: unit tests for tool lookup, handler execution, error paths |
| `test/modules/gemma/fallback_dispatcher_test.dart` | New: keyword routing, greeting detection, 4-layer fallthrough |
| `test/modules/diagnostico/diagnostico_service_test.dart` | New: IRT math tests (theta convergence, item selection, level mapping) |
| `test/core/database/database_service_test.dart` | Replace skeleton with real FFI tests: migration, seed, encryption |
| `openspec/config.yaml` | Set `test_command: "flutter test"`, `strict_tdd: false`, `coverage_threshold: 60` |

#### Estimated Complexity: **MEDIUM**

- sqflite_common_ffi setup is well-documented, ~20 lines of boilerplate
- Gemini grammar tests can be pure Dart (no native dependency) — fastest to implement
- Diagnostic IRT tests are pure math — also fast
- Database tests need FFI setup + sqlcipher shared lib on test machines
- Total: ~300-500 lines of test code across ~6 files

---

### Gap 7: Database Schema Extension

#### Current State (Aprendo+)

4 tables (from `database_service.dart:48–108`):
1. `student_profile` — alias, diagnostic_date, math_level, reading_level, theta, nivel
2. `interaction_log` — lesson_id, exercise_id, response, is_correct, error_type, gemma_used
3. `lesson_content` — subject, title, difficulty_level, explanation_json, exercises_json
4. `generated_exercises` — lesson_id, enunciado, tipo, respuesta_correcta

No conversation history tracking. No tool call audit trail. No grammar caching.

#### Target State (for tool dispatcher)

Need at minimum:
1. **Tool call history**: When the model calls `run_diagnostic` or `get_explanation`, log the full request/response for debugging and fine-tuning data generation.
2. **Conversation turns**: Store the dispatch loop state so conversations survive app restarts.
3. **Grammar cache**: Pre-built GBNF grammar string(s) stored in SQLite so they don't need rebuilding on cold start.

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `lib/core/database/database_service.dart` | Add migration v2 with new tables: `tool_call_history`, `conversation_turns`, `grammar_cache` |
| `lib/core/models/conversacion.dart` | New model: `Conversacion` (id, student_id, materia, active_context, started_at, tool_calls) |
| `lib/core/models/tool_call.dart` | New model: `ToolCall` (conversation_id, tool_name, args, result_summary, duration_ms, timestamp) |
| `lib/core/models/grammar_cache.dart` | New model: `GrammarCache` (tool_registry_hash, grammar_gbnf, built_at) |

New SQL:
```sql
CREATE TABLE tool_call_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id TEXT NOT NULL,
  turn_number INTEGER NOT NULL,
  tool_name TEXT NOT NULL,
  args_json TEXT NOT NULL,
  result_json TEXT,
  duration_ms INTEGER,
  error TEXT,
  timestamp TEXT NOT NULL
);

CREATE TABLE conversation_turns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id TEXT NOT NULL,
  turn_number INTEGER NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('user', 'assistant', 'tool')),
  content TEXT NOT NULL,
  action TEXT, -- 'speak' or 'tool'
  tool_name TEXT,
  timestamp TEXT NOT NULL
);

CREATE TABLE grammar_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tool_registry_hash TEXT UNIQUE NOT NULL,
  grammar_gbnf TEXT NOT NULL,
  built_at TEXT NOT NULL
);
```

#### Estimated Complexity: **LOW**

- Schema migration is straightforward (~40 lines of SQL in _onUpgrade)
- New Dart models: ~30-50 lines each (pattern is already established in `interaction_log.dart`)
- No risk — schema additions are additive, not destructive
- **Dependency**: None (can be done independently)

---

### Gap 8: External Model Pipeline (Download, SHA256, Mirror, Sideload)

#### Current State (Aprendo+)

`gemma_service.dart:328–331`:
```dart
String _defaultModelPath() {
  return '/sdcard/google_gemma-4-E2B-it-IQ2_M.gguf';
}
```

Hardcoded single path. No download pipeline, no verification, no mirror URLs, no sideload support.

#### Target Pattern (LIKAS)

`Likas/src/services/assetManager.ts` manages:
- Model download with SHA256 verification
- Mirror URLs for fallback
- Sideload support (user provides file from local storage)
- Install status tracking

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `scripts/download_model.py` | Already exists per AGENTS.md. Add SHA256 verification step and mirror URL support. |
| New file: `lib/modules/gemma/model_manager.dart` | Dart-side model management: check if model exists, verify SHA256, accept sideloaded paths, report status |
| `android/app/src/main/kotlin/com/aprendoplus/app/GemmaEngine.kt` | Add SHA256 verification method to Kotlin bridge (Java has `java.security.MessageDigest`) |

#### Estimated Complexity: **MEDIUM**

- Python script update: ~30 lines
- Dart model_manager: ~150-200 lines
- Kotlin SHA256: ~20 lines
- **Dependency**: None (independent work), but blocked by competition rules on model distribution

---

### Gap 9: Fine-tuning Dataset Pipeline

#### Current State (Aprendo+)

No fine-tuning pipeline exists. The system prompt is hardcoded in `gemma_service.dart:30–32`:
```dart
static const String systemPrompt = 'Eres un tutor de matematicas para secundaria '
    'en Peru. Explica conceptos de manera clara, usa ejemplos del contexto peruano '
    'y mantén un tono motivador sin calificaciones negativas.';
```

No training data, no JSONL export, no benchmarking.

#### Target Pattern (LIKAS)

`datasets/likas_assistant_v4/train.jsonl` — 25+ conversation examples matching exactly:
- System prompt (rules + tools + output format)
- User messages (English, Filipino, Taglish)
- Assistant responses (`{"action":"tool",...}` or `{"action":"speak",...}`)
- Tool results (simulated)
- Final speak responses

Format: OpenAI-compatible JSONL for fine-tuning.

#### What Specifically Needs to Change

| File | Change |
|------|--------|
| `datasets/aprendo_assistant_v1/` | New directory with `train.jsonl`, `test.jsonl`, `stats.json` |
| `scripts/generate_dataset.py` | New script: exports tool_call_history + conversation_turns from SQLite to JSONL format |
| `scripts/validate_dataset.py` | New script: validates JSONL format, tool schema compliance, Spanish-only content |

Each dataset entry must mirror the exact runtime format:
```json
{
  "messages": [
    {"role": "system", "content": "<system prompt matching exactly what buildSystemPrompt produces>"},
    {"role": "user", "content": "<student question in Peruvian Spanish>"},
    {"role": "assistant", "content": "{\"action\":\"tool\",\"name\":\"get_explanation\",\"args\":{\"tema\":\"M001_fracciones\",\"nivel\":\"2\"}}"},
    {"role": "tool", "content": "<tool result summary>"},
    {"role": "assistant", "content": "{\"action\":\"speak\",\"text\":\"<pedagogically sound response>\"}"}
  ]
}
```

#### Estimated Complexity: **HIGH** (scope-dependent)

- If creating manual seed data (25-50 examples): MEDIUM (~1-2 days of content authoring)
- If aiming for 500+ examples from tool call history: MEDIUM (script is ~100 lines, but need real usage data)
- If full fine-tuning pipeline with QLoRA on Gemma 4: HIGH (requires GPU infra, evaluation harness, A/B testing)
- **Dependency**: Gap 7 (tool_call_history must be populated)

---

## Dependency Graph

```
Gap 7 (DB Schema) ──┐
                    ├──> Gap 9 (Fine-tuning) [independent, but feeds from Gap 7]
                    │
Gap 3 (Sampling)   ──┤ [independent, can be done first]
                    │
Gap 4 (Fallback)   ──┤ [can be done before Gap 2]
                    │
Gap 2 (Tool Registry) ──> Gap 1 (Grammar) ──> Gap 2 completes when Gap 1 is in place
                    │
Gap 5 (Diagnostics) ──> Gap 2 (tools need handler wrappers)
                    │
Gap 6 (Testing)    ──┤ [should be done alongside each gap, not after]
                    │
Gap 8 (Model DL)   ──┤ [independent]
```

**Recommended execution order:**
1. Gap 3 (Sampling) — lowest risk, immediate safety improvement
2. Gap 6 (Testing) — enable TDD before fragile changes
3. Gap 7 (DB Schema) — foundation for tool history
4. Gap 4 (Fallback) — improves offline experience regardless of LLM state
5. Gap 5 (Tool Interface for Diagnostics) — prepares existing services for Gap 2
6. Gap 2 (Tool Registry + Dispatcher) — the core rearchitecture
7. Gap 1 (GBNF Grammar) — depends on Gap 2 having a tool registry
8. Gap 8 (Model Pipeline) — independent, can be done anytime
9. Gap 9 (Fine-tuning) — depends on Gap 7 and operational data

---

## Summary Matrix

| Gap | Category | Complexity | Files Affected | Dependencies |
|-----|----------|------------|----------------|--------------|
| 1. GBNF Grammar | Native + Dart | MEDIUM | 5-6 files (2 new Dart, 1 .kt, 1 .cpp) | Gap 2 |
| 2. Tool Dispatcher | Dart (core) | HIGH | 6-8 files (5-6 new) | Gaps 1, 4, 5 |
| 3. Conservative Sampling | Native + Dart | LOW | 3 files | None |
| 4. Layered Fallback | Dart | MEDIUM | 2-3 files (1-2 new) | Gap 2 |
| 5. Diagnostics → Tool | Dart | MEDIUM | 8-9 files (6 new tool handlers) | Gap 2 |
| 6. Test Infrastructure | Config + Dart | MEDIUM | 8-9 files (7 new test files) | None |
| 7. DB Schema Extension | Dart + SQL | LOW | 4-5 files (3 new models) | None |
| 8. Model Pipeline | Dart + Kotlin + Python | MEDIUM | 3 files (1 new Dart) | None |
| 9. Fine-tuning Dataset | Content + Python | HIGH | 4-5 files (new directory) | Gap 7 |

**Total estimated new/changed files**: 40-50 files
**Total estimated new code**: 2,000-3,000 lines (Dart + C++ + Kotlin)
**Risk level**: MEDIUM-HIGH (tool dispatch is a core architectural change)

---

## Ready for Proposal

**YES** — All gaps are identified with concrete files, APIs, and complexity estimates. The dependency graph is clear. The orchestrator can proceed to `sdd-propose` with this exploration as input.

Key decision needed from stakeholders: **Scope for hackathon window (5-7h)**. Recommended MVP scope:
- Gaps 3, 4, 5, 2 (in that order) — sampling fix, fallback enrichment, tool interface, basic dispatch loop
- Gaps 1 and 7 as stretch goals (grammar + schema)
- Gaps 8 and 9 as post-hackathon
