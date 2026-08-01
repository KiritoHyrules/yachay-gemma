# Exploration: Yachay Orquestador

## Executive Summary

The current Aprendo+ is a traditional multi-screen learning app with a diagnostic test → learning path → lesson flow. Gemma is a "help" feature buried behind a `?` button. The Yachay vision inverts this entirely: Gemma becomes the orchestrator of a single-screen, chat-first experience where the model decides what to do next using a Socratic/Mastery Learning approach. 

This is not an incremental change — it is a **re-foundation**. The existing dispatch loop, tool registry, and action parser are directly reusable, but the UI, navigation, student model, and curriculum must be rebuilt. The LIKAS reference project provides the closest architectural match and offers proven patterns for the dispatch loop we already partially implemented.

---

## Current State

### 1. UI (`lib/main.dart`, `lib/modules/diagnostico/`, `lib/modules/aprendizaje/`)

**Three screens, linear flow:**

| Screen | File | Purpose |
|--------|------|---------|
| `DiagnosticoScreen` | `diagnostico_screen.dart` (453 lines) | Adaptive IRT-based diagnostic, one item at a time with 4 option buttons, progress bar. Shows result screen with level badge, then navigates to RutaScreen. |
| `RutaScreen` | `ruta_screen.dart` (349 lines) | Ordered lesson list (5 lessons) with lock/unlock logic, difficulty stars, completion status, level badge card. |
| `LeccionScreen` | `leccion_screen.dart` (1000 lines) | Scrollable lesson with video placeholder, collapsible explanation steps, interactive exercises, reinforcement card, "?" help button → GemmaService. |

**Navigation**: `Navigator.pushReplacement` from Diagnostic → Ruta. `Navigator.push` from Ruta → Leccion. No bottom nav, no drawer, no tab bar. The app is a one-way tunnel: diagnose → list → lesson → back.

**Gemma integration**: Only visible as a `?` button (`IconButton` with `Icons.help_outline`) on the LeccionScreen app bar. Tapping it calls `gemmaService.generarExplicacion()` or `generarEjerciciosRefuerzo()` through a modal bottom sheet.

**Theme**: Material 3, `ColorSchemeSeed = Color(0xFF1565C0)`, Spanish locale only.

**What would need to change**: Everything. The three-screen structure must collapse into a single chat screen. The diagnostic must become a conversation-initiated tool, not a forced entry point. The lesson list must disappear — Gemma decides what to show next.

### 2. Dispatcher (`lib/modules/gemma/`)

**Core dispatch loop** (`gemma_service.dart:407-524`):

```
procesarMensaje(userMessage) → dispatch loop (max 5 rounds):
  1. Build tool-calling prompt with systemPrompt + tool list + grammar
  2. Stream inference via MethodChannel → llama.cpp
  3. Parse output with findNextAction(action_parser.dart):
     - No action tag → speak (plain text reply)
     - Tool action → execute via ToolRegistry → feed result back → loop
     - Incomplete XML → repairXml → retry
     - Parse failure → detectForcedTool rescue
  4. On round 5 exhaustion → force speak → fallback
```

**Feature gate**: `useXmlDispatch = true` (default). When `false`, routes to legacy `generarExplicacion()` / `generarEjerciciosRefuerzo()`.

**Tool Registry** (6 tools):
| Tool | Handler | What it does |
|------|---------|--------------|
| `explicar_tema` | `explicarTemaHandler` | Looks up pre-authored explanation from fallback JSON |
| `generar_ejercicios` | `generarEjerciciosHandler` | Returns exercises from fallback JSON |
| `ejecutar_diagnostico` | `ejecutarDiagnosticoHandler` | Runs IRT diagnostic (delegates to DiagnosticoService or fallback) |
| `obtener_perfil` | `obtenerPerfilHandler` | Reads StudentProfile from StudentState |
| `obtener_leccion` | `obtenerLeccionHandler` | Looks up lesson by ID from database |
| `registrar_interaccion` | `registrarInteraccionHandler` | Records interaction event (correct/incorrect) |

**Fallback system** (`fallback_dispatcher.dart`): 4-layer deterministic dispatch:
1. Trivial greeting regex → instant encouragement
2. Keyword → tool mapping → route to tool
3. Tool execution (local JSON content)
4. No match → random generic encouragement

**What can be reused**:
- **Dispatch loop structure** — The core `for (round)` loop with action parsing, tool execution, and result feeding is solid and mirrors LIKAS's pattern. **REUSE.**
- **Action parser** (`action_parser.dart`) — Ported directly from gemma-chat. XML parsing, repair, forced-tool detection. **REUSE AS-IS.**
- **Tool registry** (`tool_registry.dart`) — Clean interface with ToolSpec, ToolParam, ToolResult, ToolContext. **REUSE, extend.**
- **System prompt builder** (`system_prompt.dart`) — Needs rewriting for Yachay's Socratic tutor persona but the structure (XML format rules, tool list rendering) is portable. **ADAPT.**
- **Fallback dispatcher** — 4-layer pattern is proven. **REUSE, extend with new tools.**
- **Sampling config** — Temperature=0.4, topK=64, topP=0.85, maxTokens=1024. **REUSE.**

**What must be rebuilt**:
- **Tool set** — Current tools are CRUD lookups. Yachay needs: `evaluar_respuesta` (check if answer is correct, return feedback), `siguiente_paso` (what to do next — explain, ask, exercise, advance), `consultar_curriculo` (traverse knowledge graph), `actualizar_mastery` (update per-topic mastery), `generar_ejercicio` (on-the-fly exercise generation).
- **System prompt** — Must encode Socratic method rules, mastery learning thresholds, Peruvian curriculum knowledge, student mental model access.
- **Streaming** — Already implemented (`sendWithStreaming`). **REUSE.**

### 3. Curriculum (`assets/data/lessons.json`, `assets/diagnostic/`)

**Current content**:
- **5 lessons** (`lessons.json` + individual `lesson_M001.json` through `lesson_L002.json`): Fractions, Linear Equations, Percentages (math); Comprehension, Inferences (reading).
- **50 diagnostic items**: 25 math (`items_matematica.json`, areas: aritmética, fracciones, porcentajes, geometría, ecuaciones) + 25 reading (`items_lectura.json`, areas: comprensión_literal, vocabulario, inferencias).
- Each item has IRT 2PL parameters (`dificultad`, `discriminacion`) and `gradoEquivalente` (6-10).
- Math items already cover aritmética topics: sumas, multiplicación, divisores, MCD, MCM, fracciones, porcentajes, ecuaciones. 5 of 25 items tagged `"area": "aritmetica"`, 5 tagged `"area": "fracciones"`, 4 `"area": "porcentajes"`.

**Gap analysis for Yachay**:
- **No knowledge graph.** Lessons are flat, ordered list with simple prerequisites. No concept adjacency graph, no prerequisite DAG, no competency mapping to `gradoEquivalente`.
- **No aritmética curriculum.** The 25 math diagnostic items touch aritmética tangentially but there's no structured sequence covering: Números Naturales (1°), Operaciones Fundamentales (1°), Divisibilidad (2°), MCD y MCM (2°), Fracciones (2°-3°), Números Decimales (3°), Razones y Proporciones (4°), Regla de Tres (4°), Porcentajes (4°-5°), Números Enteros (1°-2°), Potenciación (3°-4°), Radicación (4°-5°), etc.
- **Sparse content**: Each lesson has 1 exercise. No progressive exercises (1° through 5° difficulty).
- **No generative capability**: Exercises are pre-authored. The vision requires Gemma to generate exercises on-the-fly using the knowledge graph as context.

**What a proper aritmética knowledge graph would look like**:

```json
{
  "curriculo": {
    "asignatura": "Aritmética",
    "grados": ["1°", "2°", "3°", "4°", "5°"],
    "competencias": [
      {
        "id": "arit_nn_01",
        "titulo": "Números Naturales",
        "grado": "1°",
        "descripcion": "Lectura, escritura, orden y representación de números naturales hasta 6 cifras",
        "prerrequisitos": [],
        "subtemas": [
          {"id": "arit_nn_01a", "titulo": "Valor posicional", "dificultad": 1},
          {"id": "arit_nn_01b", "titulo": "Comparación y orden", "dificultad": 1},
          {"id": "arit_nn_01c", "titulo": "Recta numérica", "dificultad": 1}
        ]
      },
      {
        "id": "arit_of_02",
        "titulo": "Operaciones Fundamentales",
        "grado": "1°",
        "prerrequisitos": ["arit_nn_01"],
        "subtemas": [
          {"id": "arit_of_02a", "titulo": "Adición y sustracción", "dificultad": 1},
          {"id": "arit_of_02b", "titulo": "Multiplicación", "dificultad": 1},
          {"id": "arit_of_02c", "titulo": "División exacta e inexacta", "dificultad": 2}
        ]
      }
      // ... ~15-20 competencies covering 1°-5°
    ]
  }
}
```

**Estimated effort**: Building the knowledge graph is the single largest content task. ~50 competencies × 3 subtopics × 3 difficulty levels × example + exercise = ~450 content items. This can be AI-assisted (generate structure, human review).

### 4. Student Model (`lib/core/state/student_state.dart`, `lib/core/models/`)

**What's tracked today**:
- `StudentProfile`: alias, mathLevel (1-5), readingLevel (1-5), diagnosticDate, totalTimeMin, currentLesson.
- `DiagnosticResult`: nivel, etiqueta, theta, precision, itemsAdministrados.
- `StudentState`: completedLessons (list of strings), overallProgress (completed/total), totalInteractionCount, correctInteractionCount, accuracyRate.
- `InteractionLog`: per-exercise audit record (lessonId, exerciseId, isCorrect, errorType, timeSpentSec, gemmaUsed).

**What Yachay needs** — a live-updating mastery model:

```dart
class TopicMastery {
  final String topicId;       // e.g. "arit_nn_01"
  final double mastery;       // 0.0–1.0 (IRT-based estimate)
  final int attempts;         // total interactions on this topic
  final int correctAttempts;
  final int consecutiveCorrect; // for mastery learning threshold
  final DateTime lastInteraction;
  final List<String> commonErrors; // detected error patterns
}

class StudentMentalModel {
  final Map<String, TopicMastery> topics; // keyed by topic ID
  final int currentGrade;      // derived from diagnostic
  final String currentTopic;   // what Yachay is teaching now
  final LearningState state;   // exploring, explaining, practicing, evaluating, advancing
  final List<String> readyTopics; // topics where mastery >= 0.90
  final List<String> nextTopics;  // unlocked topics ready to start
}
```

**Key differences**:
- **Per-topic granularity** instead of coarse 1-5 levels.
- **Mastery threshold** (90%) drives advancement — classic Mastery Learning.
- **Consecutive correct** tracking — must demonstrate sustained mastery, not just lucky.
- **Error pattern detection** — specific misconceptions to target (e.g., "confunde MCD con MCM", "error en división de fracciones").
- **Gemma-queryable** — the model can call `obtener_estado_estudiante` and receive the full mental model as context.

**What can be reused**:
- `StudentProfile` structure — extend with mental model.
- `InteractionLog` — already captures `errorType`, which is the foundation for misconception tracking.
- Database schema — encrypted SQLite via SQLCipher is already in place.

### 5. Reference: LIKAS (`aiAssistantService.ts`)

**Architecture matches Yachay's target**:

| Pattern | LIKAS | Aprendo+ (current) | Yachay (target) |
|---------|-------|--------------------|----|
| Dispatch loop | Async generator, max 3 turns | `for (round)` loop, max 5 turns | Same pattern, 5-7 turns |
| Action format | JSON `{"action":"tool"/"speak"}` | XML `<action name="...">` | XML (already working) |
| Grammar constraint | GBNF for valid JSON | Stub (returns "") | Deferred per ADR |
| System prompt | Profile inlined + tool list | Persona + tool list + rules | Extended with Socratic rules |
| Streaming | Character-level from JSON `text` field | Token-level via MethodChannel | Token-level (reuse) |
| Fallback | Rule-based keyword responder | 4-layer deterministic | Reuse 4-layer, extend |
| Tool context | Profile + disaster context | FallbackData only | Full StudentMentalModel |
| Chat template | System prompt in first user message | System prompt in generate args | Same (llama.cpp handles it) |

**Key learnings from LIKAS**:
1. **`detectForcedTool` rescue is essential.** Models sometimes narrate tools instead of calling them. The keyword-based rescue in `action_parser.dart:211` and `aiAssistantService.ts:557` is proven.
2. **Grammar constraints work** — LIKAS uses GBNF to enforce valid JSON output. Aprendo+ deferred GBNF but the skeleton is in place. For Yachay, GBNF becomes more important because the tool call format must be reliable for a 5-7 round dispatch loop.
3. **Battery guard** — LIKAS checks battery before inference (`BATTERY_FLOOR = 0.15`). Relevant for Aprendo+ on low-end Peruvian devices.
4. **Small context window management** — LIKAS keeps conversation history to last 8 messages. Yachay needs similar trimming since llama.cpp has limited context (4096 tokens like LIKAS).
5. **Tool result injection pattern** — Tool results are injected as `user` turns (Gemma has no `tool` role). Already handled in our dispatch.

### 6. Reference: gemma-chat (`tools.ts`)

**Direct ancestor of our implementation**:
- `findNextAction()` → ported to `action_parser.dart:34`
- `parseActionBody()` → ported to `action_parser.dart:83`
- `emitSafeBoundary()` → ported to `action_parser.dart:188`
- `chatSystemPrompt()` → ported to `system_prompt.dart:18`
- `ToolSpec`, `ToolParam` → ported to `tool_registry.dart`

**What gemma-chat does that we don't yet**:
- `cleanFileContent()` — handles markdown fence removal for `<content>` tags. Relevant if Gemma generates exercise text inside XML.
- `renderToolHelp()` — formats tool list with examples. Already in our `SystemPrompt.build()`.
- Mode separation (`chat` vs `code`) — not needed for Yachay (single educational mode).

### 7. Reference: gemma-vision (`gemma_vision_chat.dart`)

**Closest UI reference for Yachay**:
- **Single-screen, no navigation.** Everything is in one scaffold: messages list (expandable), prompt bar (fixed bottom), view toggle buttons.
- **Message bubbles** in a scrollable list with auto-scroll.
- **Loading screen** during bootstrap, then transitions to chat.
- **Keyboard shortcuts** for accessibility (F2 = voice toggle, etc.)
- **Quick action buttons** — equivalent to Yachay's context chips ("Explícame fracciones", "Quiero practicar", "¿Cómo voy?").

**What Yachay should adopt**:
- **Bootstrap screen** → replaces forced diagnostic flow. Show "Yachay está preparando tu lección..." while model loads.
- **Prompt bar at bottom** → text input + send button. Fixed, never scrolls.
- **Message list** → user messages right-aligned, Yachay messages left-aligned with avatar.
- **Context chips** → 3-4 quick action buttons above the prompt bar. "Explicar", "Practicar", "Mi progreso", "Cambiar tema".
- **Streaming tokens** → show Yachay typing in real-time (already works via `sendWithStreaming`).

---

## Gap Analysis

### What Exists → What's Needed

| Domain | Exists | Needed for Yachay | Gap |
|--------|--------|--------------------|-----|
| **UI** | 3 screens (diagnostic → ruta → leccion) | 1 screen (chat + context chips) | Full UI rebuild |
| **Navigation** | Push-based, one-way flow | None (single screen) | Remove all navigation |
| **Entry point** | Forced diagnostic | Yachay greets, asks what they want to learn | Replace entry point |
| **Gemma dispatch** | XML dispatch loop, 5 rounds, 6 tools | Extended loop, 8-10 tools, Socratic rules | Extend tools, rewrite system prompt |
| **Action parser** | XML parsing, repair, rescue | Same XML parsing | REUSE AS-IS |
| **Tool registry** | ToolSpec/Context/Result pattern | Same pattern, more tools | REUSE, extend |
| **Fallback** | 4-layer deterministic | Same layers, richer responses | Extend with curriculum responses |
| **System prompt** | Peruvian math tutor, XML format | Socratic tutor persona, mastery rules, curriculum context | Full rewrite |
| **Curriculum** | 5 flat lessons + 50 IRT items | ~50 aritmética competencies, ~150 subtopics, ~450 exercises | Build from scratch |
| **Student model** | Profile (1-5 levels), completion list | Per-topic mastery (0.0-1.0), misconceptions, error patterns | Full redesign |
| **Streaming** | 3-token throttle, MethodChannel | Same streaming | REUSE |
| **Database** | SQLCipher encrypted SQLite | Same, with new tables for topic mastery | Extend schema |
| **Keystore** | Android Keystore bridge | Same | REUSE |
| **Grammar** | Stub (GBNF placeholder) | GBNF for XML action format | Implement deferred ADR item |

### Reusability Assessment

| Component | Reuse % | Action |
|-----------|---------|--------|
| `action_parser.dart` | 100% | Keep as-is (ported from gemma-chat, identical to production code) |
| `tool_registry.dart` | 100% | Keep as-is, register new Yachay tools |
| `fallback_dispatcher.dart` | 80% | Keep 4-layer pattern, extend with new keywords and curriculum responses |
| `gemma_service.dart` (dispatch loop) | 70% | Keep loop structure, rewrite `_buildToolPrompt()`, extend `_inicializarRegistry()` |
| `gemma_service.dart` (streaming) | 100% | Keep `sendWithStreaming` and `_buildSamplingArgs` |
| `system_prompt.dart` | 30% | Keep XML format rules, rewrite persona and tool descriptions |
| `grammar_builder.dart` | 10% | Skeleton exists; needs full GBNF implementation |
| `student_state.dart` | 40% | Keep `StudentState` pattern, add `StudentMentalModel`, `TopicMastery` |
| `student_profile.dart` | 60% | Keep base fields, add mental model reference |
| `diagnostico_screen.dart` | 0% | Delete — becomes a tool call |
| `ruta_screen.dart` | 0% | Delete — Gemma decides what's next |
| `leccion_screen.dart` | 0% | Delete — becomes chat messages with exercise widgets |
| `exercise_widgets.dart` | 60% | Reuse widget components in chat bubbles |
| `leccion_service.dart` | 20% | Keep lesson parsing, replace with knowledge graph |
| `diagnostico_service.dart` | 50% | Keep IRT engine, make it tool-callable from chat |
| `lessons.json` + lesson files | 10% | Reference for structure; content replaced by knowledge graph |
| `items_matematica.json` | 80% | Keep IRT-calibrated items, re-tag for aritmética knowledge graph |
| `items_lectura.json` | 0% | Out of scope for Yachay (aritmética only) |

---

## Architectural Decisions

### AD-1: Chat UI Framework
**Decision**: Build a custom chat UI using Flutter's built-in widgets (`ListView.builder` with message bubbles), not a third-party chat package.

**Rationale**: 
- We need full control over message rendering (exercise widgets, explanation cards, mastery badges inline).
- Third-party chat packages (flutter_chat_ui, chatview) are designed for text-only messaging apps.
- gemma-vision proves this approach works for AI chat interfaces.
- 333 lines for a production-grade chat page is achievable.

### AD-2: Single Provider vs. Multi-Provider
**Decision**: Keep `MultiProvider` with `StudentState` as the primary ChangeNotifier. Add `ChatState` for UI-only chat concerns (messages list, input state, loading). GemmaService remains a plain Provider (not ChangeNotifier).

**Rationale**: The current architecture is sound. Adding a `ChatState` for scroll position, input focus, and message rendering avoids overloading `StudentState` with UI concerns.

### AD-3: Knowledge Graph Format
**Decision**: JSON file (`assets/data/curriculo_aritmetica.json`) with competency nodes, prerequisite edges, and per-topic exercises. Loaded on app start, cached in memory. Gemma receives the relevant subgraph in its system prompt context.

**Rationale**:
- JSON is parseable by both Dart (app) and Python (build scripts for content generation).
- No need for a graph database — the graph has ~200 nodes, traversable in-memory.
- Keeping it as an asset file allows offline operation and version control.

### AD-4: Per-Topic Mastery Algorithm
**Decision**: Use a simplified Bayesian Knowledge Tracing (BKT) model per topic. Four parameters: `p(L0)` (prior knowledge), `p(T)` (probability of learning), `p(G)` (guess), `p(S)` (slip). Update after each interaction. Mastery threshold = 0.90.

**Rationale**:
- BKT is simpler than IRT for continuous tracking and works well with binary (correct/incorrect) observations.
- The current IRT 2PL model is designed for one-shot diagnostic tests, not continuous tracking.
- BKT parameters are well-studied in educational data mining literature.
- Falls back gracefully: p(L0) starts at 0.0, accumulates evidence with each interaction.

### AD-5: Socratic Method Implementation
**Decision**: Encode Socratic rules in the system prompt, not in code. The system prompt instructs Gemma to:
1. NEVER give direct answers. Guide with questions.
2. When student answers correctly, ask a probing follow-up question.
3. When student struggles, break the problem into smaller steps.
4. Only reveal the answer after 3 failed attempts with scaffolding.
5. Use mastery data to decide when to advance.

**Rationale**:
- The model is smart enough to follow behavioral rules if they're explicit.
- Encoding rules in code creates a parallel system that fights the model.
- LIKAS proves this approach: behavioral rules in system prompt, tool calls for data.

### AD-6: Conversation Memory
**Decision**: Keep last 8 message pairs in context (16 total turns). Store full history in SQLite. When student returns, inject a summary of last session as context.

**Rationale**:
- Context window is limited (4096 tokens like LIKAS). System prompt (~1500 tokens) + tool list (~500 tokens) + knowledge graph context (~500 tokens) leaves ~1500 tokens for conversation.
- 8 message pairs at ~150 tokens/pair = 1200 tokens. Fits within budget.
- LIKAS uses 8 messages. Proven safe.
- Session summaries are critical for continuity across app restarts.

---

## Risk Assessment

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| **Model quality on low-end devices** — Gemma 4 E2B on 2GB RAM may produce incoherent or slow responses | High | Medium | Keep 4-layer fallback dispatcher; design UI to look good even with pre-authored responses |
| **Socratic method fidelity** — Model may ignore Socratic rules and give direct answers | Medium | Medium | System prompt engineering + post-processing filter; detect direct answers and append "¿Por qué crees que es así?" |
| **Knowledge graph content creation** — Building a complete aritmética curriculum is a large content task | High | High | AI-assisted content generation (generate structure, exercises, explanations; human review); start with 2 grades and expand |
| **Mastery model accuracy** — BKT with sparse data may misclassify student readiness | Medium | Medium | Start with conservative threshold (90%); add teacher override later; log all mastery transitions for debugging |
| **Context window overflow** — System prompt + knowledge graph + conversation may exceed 4096 tokens | Medium | High | Token counting in prompt builder; trim knowledge graph context to only the active topic subtree |
| **GBNF grammar complexity** — Valid XML grammar for 10+ tools is non-trivial to construct and maintain | Low | Medium | Start without GBNF (proven to work with XML parsing + rescue); add GBNF as optimization later |
| **APK size increase** — Knowledge graph JSON + new assets may increase APK size | Low | Low | Text assets compress well; current APK is well under 50MB target |
| **User confusion** — Students accustomed to menu-driven apps may not understand chat-first interface | Medium | Low | Context chips ("Explícame", "Practicar", "Mi progreso") provide familiar entry points; onboarding message from Yachay |

---

## Estimated Complexity

| Component | Complexity | Estimated Effort | Justification |
|-----------|-----------|-----------------|---------------|
| Chat UI (single screen) | **Medium** | 3-5 days | One new screen with message list, prompt bar, context chips. 300-500 lines. |
| Extended dispatch loop | **Low** | 1-2 days | Existing loop works. Add 4-5 new tools, extend system prompt. |
| Socratic system prompt | **Medium** | 2-3 days | Requires prompt engineering iteration and testing. |
| Per-topic mastery model | **Medium** | 3-4 days | New model (`TopicMastery`, `StudentMentalModel`), DB migration, BKT algorithm. |
| Knowledge graph (content) | **High** | 5-7 days | ~50 competencies × subtopics × exercises. Content generation + review. |
| Knowledge graph (infrastructure) | **Medium** | 2-3 days | JSON parser, in-memory graph, query/traversal methods. |
| Tool set expansion | **Medium** | 3-4 days | 5 new tools: evaluar, siguiente_paso, consultar_curriculo, actualizar_mastery, generar_ejercicio. |
| Remove old UI | **Low** | 1 day | Delete screens, simplify main.dart to single ChatScreen. |
| GBNF grammar | **High** | 3-5 days | Complex XML grammar construction. Deferrable. |
| Testing & hardening | **Medium** | 3-4 days | Test with real students, tune prompts, fix edge cases. |
| **Total estimated** | | **26-38 days** | ~5-8 weeks with one developer. |

---

## Ready for Proposal

**Yes.** The exploration is comprehensive. Key decisions are identified. Reuse versus rebuild is clearly mapped. The next phase should produce a proposal defining scope, approach, and phased delivery plan.

**Recommended phased delivery**:
1. **Phase 1: Chat foundation** — Single-screen chat UI + dispatch loop extension + Socratic prompt (2 weeks).
2. **Phase 2: Student model** — Per-topic mastery + mental model + tool integration (1.5 weeks).
3. **Phase 3: Knowledge graph** — Content creation + query infrastructure + curriculum tools (2 weeks).
4. **Phase 4: Polish** — Context chips, session summaries, exercise widgets in chat, hardening (1.5 weeks).
