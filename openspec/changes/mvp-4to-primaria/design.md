# Design: MVP 4to Primaria — Reorientación Curricular

## Technical Approach

Extend, don't rewrite. Preserve `flutter_gemma 1.4.2` pipeline, `StudentState` + Provider, and `FallbackDispatcher` 4-layer system. Strip secondary complexity; add primary-appropriate layers: rules engine pre/post hooks, static Dart curriculum, simplified ratio-based mastery, kid-friendly UI.

## Architecture Decisions

### ADR-1: Flat data over DAG

| Option | Tradeoff |
|--------|----------|
| JSON DAG (`aritmetica_1.json`, 45 nodes) | Prerequisite complexity, asset I/O risk — no pedagogical gain at primary level |
| **Static `Curricula4toPrimaria.temas` list** | Simple, zero I/O, 18+ flat topics always accessible |

**Rationale**: 4to primaria (9-10 años) doesn't need prerequisite chains. All topics unlocked. `CurriculoService.inicializar()` references static list — no asset loading, no fallback logic needed.

### ADR-2: Plain mastery over BKT

| Option | Tradeoff |
|--------|----------|
| BKT 4-parameter model (P(L₀), P(T), slip, guess) | IRT precision irrelevant for primary; complex, opaque |
| **`pLearned = correctAttempts / max(attempts, 1)`** | Simple, transparent, sufficient for target audience |

**Rationale**: Replace `BktEngine.updatePLearned()` call in `StudentState.actualizarMastery()` with direct ratio. Threshold: mastery at ≥ 0.80 (was BKT's 0.90). Add `consecutiveFailures` field to `TopicMastery` alongside existing `consecutiveCorrect` for Rules Engine streak detection.

### ADR-3: SamplingConfig wiring via adapter

| Option | Tradeoff |
|--------|----------|
| `model.createChat()` options (flutter_gemma) | API already supports `temperature`, `topK`, `topP`, `repeatPenalty` |
| **Extend `GemmaInferenceAdapter.createChat()`** | Single interface point; params flow through same call as `maxOutputTokens` |

**Rationale**: Add `temperature`, `topK`, `topP`, `repeatPenalty` as optional named params on `GemmaInferenceAdapter.createChat()`. `FlutterGemmaInferenceAdapter` forwards to `model.createChat()`. Hardcode `maxOutputTokens: 256` in `GemmaService.cargarModelo()` — override `_resolveMaxTokens()` ram-based resolution.

### ADR-4: FallbackDispatcher → StudentState via ToolContext

| Option | Tradeoff |
|--------|----------|
| Pass StudentState per `dispatch()` call | Thread-safe but redundant |
| **Inject via `setToolContext(ToolContext)` setter** | Already exists; dispatcher already holds `_ctx` |

**Rationale**: `FallbackDispatcher` already has `_ctx: ToolContext` built from `fallbackData` only. Add public `setToolContext()` method. At app init, caller injects real `StudentState` via `ctx.studentState`. Layer 3 handlers read `ctx.studentState.masteryMap`; Layer 2 uses real mastery instead of `nivel='1'`. "Never crashes" preserved — null-check `studentState`; degrade to defaults.

### ADR-5: RegExp removal — exact replacements

| File | Current RegExp | Replacement |
|------|---------------|-------------|
| `gemma_service.dart:682` | `RegExp(r'^(hola\|buenas\|...)').hasMatch(m)` | `m.startsWith('hola') \|\| m.startsWith('buenas') \|\| ...` (12 prefixes) |
| `gemma_service.dart:814,826` | `tema.replaceAll(RegExp(r'^[A-Z]\d+_'), '')` | `tema.contains('_') ? tema.substring(tema.indexOf('_') + 1) : tema` |
| `gemma_service.dart:217` | `RegExp(r'MemTotal:\s+(\d+)')` | **KEEP** — `/proc/meminfo` parsing, not a hot path |
| `fallback_dispatcher.dart:128` | `RegExp(pattern).hasMatch(lowered)` | Remove `regex` key from `fallback_responses.json`; use native `String.contains()` in JSON `keyword_intents` |
| `explicar_tema.dart:29` | `tema.replaceAll(RegExp(r'^[A-Z]\d+_'), '')` | Same `indexOf('_')` helper |
| `generar_ejercicios.dart:31` | Same | Same helper |
| `obtener_leccion.dart:52` | Same | Same helper |

All replacements behaviorally identical. Extract shared helper `stripTopicPrefix(String id)` into new `lib/core/text_utils.dart`.

## Sequence Diagrams

**Chat flow (happy path)**:
```
Student tap → YachayScaffold._sendMessage(text)
  → GemmaService.procesarMensaje(text)
    → cargarModelo: createChat(systemInstruction, maxOutputTokens: 256, temperature: 0.4, ...)
    → _esSaludo(text)? → YES: iniciar_conversacion tool → return greeting
    → NO: ToneAdapter.adjust(text, masteryMap[pLearned]) → system prompt prefix
    → DevilsAdvocate.check(streaks) → intervention or null
    → _dispatchPlainText(text) → LiteRtLmEngine stream
    → truncateAtSentence(response) → ChatMessage bubble display
```

**Degraded path**:
```
Gemma unavailable → FallbackDispatcher.dispatch(text)
  → L1: native String startsWith (zero RegExp) → greeting
  → L2: keyword via String.contains() → tool name
  → L3: tool handler with real StudentState.masteryMap (no hardcoded nivel='1')
  → L4: ToneAdapter-personalized encouragement
```

**Session end**:
```
Session ends → StudentState.masteryMap.values
  → SessionAnalyzer.analizar(entries, n: lastN)
    → fortalezas = ids where pLearned ≥ 0.80
    → debilidades = ids where pLearned < 0.40
    → recomendaciones per debilidad
    → return JSON {fortalezas, debilidades, recomendaciones}
  → Present via PerfilScreen "qué reforzar" section
```

## Module Design

### `rules_engine/` (new — Commit 8, Luis)
```
lib/modules/rules_engine/
  tone_adapter.dart       → ToneAdapter — zero inference, pure Dart
  devils_advocate.dart    → DevilsAdvocate — streak detection, zero I/O
```
- `ToneAdapter.adjust(double pLearned, int consecutiveFailures) → String`: returns tone prefix. Dependencies: NONE on `gemma_service.dart`.
- `DevilsAdvocate.intervene(int consecutiveCorrect, int consecutiveFailures) → String?`: returns trick question or analogy, or `null`. No model access.

### `learning_data.dart` (new — Commit 2, Jesús)
```dart
// lib/core/learning_data.dart
class TemaPrimaria {
  final String id;         // "com-01"
  final String area;       // "Comunicación" | "Matemática" | "Ciencia y Tecnología"
  final String titulo;     // Kid-friendly Spanish
  final String explicacion; // ≤90 words
  final List<String> chips; // 3-4 quick action labels
  final String prioridad;  // "alta" | "media" | "baja"
}
class Curricula4toPrimaria {
  static final List<TemaPrimaria> temas = [/* 18+ static entries */];
}
```
Chips map to topics directly — `ChatScreen._ContextChipRow` renders `TemaPrimaria.chips` per current area.

### `SessionAnalyzer` (new — Commit 8, Luis)
```dart
// lib/modules/diagnostico/session_analyzer.dart
class SessionAnalyzer {
  SessionSummary analizar(List<TopicMastery> entries, {int n = 5});
}
class SessionSummary {
  final List<String> fortalezas;       // topic IDs with pLearned ≥ 0.80
  final List<String> debilidades;      // topic IDs with pLearned < 0.40
  final List<String> recomendaciones;  // one suggestion per debilidad
  Map<String, dynamic> toJson();
}
```

## File Change Map

| C# | Who | File | Action |
|----|-----|------|--------|
| C2 | Jesús | `lib/core/learning_data.dart` | **Create** — 18+ static topics |
| C2 | Jesús | `assets/data/fallback_responses.json` | **Modify** — add 4to primaria entries |
| C3 | Jesús | `lib/modules/yachay/curriculo_service.dart` | **Modify** — flat list, no DAG traversal |
| C3 | Jesús | `lib/modules/yachay/tool_handlers/obtener_plan_completo.dart` | **Modify** — remove `bloqueado` field |
| C3 | Jesús | `lib/modules/yachay/tool_handlers/obtener_siguiente_tema.dart` | **Modify** — flat iteration, no prerequisites |
| C4 | Alexander | `lib/modules/gemma/gemma_inference_adapter.dart` | **Modify** — add sampling params to `createChat()` |
| C4 | Alexander | `lib/modules/gemma/gemma_service.dart` | **Modify** — RegExp→String, maxTokens=256, wire sampling |
| C5 | Alexander | `lib/core/text_utils.dart` | **Create** — `truncateAtSentence()`, `stripTopicPrefix()` |
| C5 | Alexander | `lib/modules/gemma/fallback_dispatcher.dart` | **Modify** — RegExp→native, `setToolContext()`, ToneAdapter in L4 |
| C5 | Alexander | `lib/modules/gemma/tool_handlers/explicar_tema.dart` | **Modify** — RegExp→`stripTopicPrefix()` |
| C5 | Alexander | `lib/modules/gemma/tool_handlers/generar_ejercicios.dart` | **Modify** — same |
| C5 | Alexander | `lib/modules/gemma/tool_handlers/obtener_leccion.dart` | **Modify** — same |
| C6 | Freddy | `lib/modules/yachay/screens/chat_screen.dart` | **Modify** — dynamic chips from curriculum |
| C6 | Freddy | `lib/modules/yachay/screens/yachay_scaffold.dart` | **Modify** — wire chips, error/retry states |
| C8 | Luis | `lib/modules/rules_engine/tone_adapter.dart` | **Create** |
| C8 | Luis | `lib/modules/rules_engine/devils_advocate.dart` | **Create** |
| C8 | Luis | `lib/modules/diagnostico/session_analyzer.dart` | **Create** |
| C8 | Luis | `lib/core/state/student_state.dart` | **Modify** — replace BKT with ratio mastery |
| C8 | Luis | `lib/core/models/topic_mastery.dart` | **Modify** — add `consecutiveFailures` |
| C8 | Luis | `lib/modules/yachay/screens/teacher_dashboard.dart` | **Remove** — freeze for Phase 2 |
| C8 | Luis | `android/app/build.gradle` | **Modify** — ABI splits, signing config |

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | ToneAdapter tone thresholds | Given mastery ranges → assert tone string |
| Unit | DevilsAdvocate streaks | Given streak ≥3 → assert intervention; <3 → null |
| Unit | SessionAnalyzer | Given TopicMastery list → assert correct fortalezas/debilidades |
| Unit | `truncateAtSentence()` | Per 7 spec scenarios (punctuation priority, unicode, empty) |
| Unit | BKT→ratio migration | Given correct/attempts → assert new pLearned matches spec |
| Unit | RegExp replacements | Assert behavioral identity for each replacement site |
| Integration | FallbackDispatcher + real StudentState | Inject state → L3 tool returns real mastery context |
| Widget | ChatScreen dynamic chips | Given curriculum → assert chips from `TemaPrimaria.chips` |
| Widget | Error/retry states | Model unavailable → assert fallback message + retry button |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No data migration required. `student_mastery` table adds `consecutive_failures INTEGER NOT NULL DEFAULT 0` (append-only, backward compatible). ABI splits are additive build config. Per-commit revert supported — 8 self-contained commits, each revertable without cascade.

## Open Questions

- [ ] Does `flutter_gemma 1.4.2`'s `model.createChat()` actually accept `temperature`/`topK`/`topP`/`repeatPenalty`? Verify against flutter_gemma source before C4.
- [ ] Is `randomSeed: 1` (currently passed) intentional or leftover? It forces deterministic output — confirm this is desired for educational use.
