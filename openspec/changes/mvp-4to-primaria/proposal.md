# Proposal: MVP 4to Primaria — Reorientación Curricular

## Intent

Aprendo+ was built for 1° Secundaria (12-13 años) with IRT diagnostics, BKT mastery tracking, 45-topic JSON curriculum, teacher dashboard, and 1024-token inference. It now targets **4to Primaria (9-10 años)** in Peruvian public schools. The current codebase is over-engineered for this audience — complex algorithms, secondary-level content, teacher-facing features, and inference parameters tuned for longer responses. We need to simplify, reorient content, and optimize for a younger learner with shorter attention spans and lower reading levels.

## Scope

### In Scope
- **3 curriculum areas**: Comunicación, Matemática (priority); Ciencia y Tecnología (conditional on progress)
- **Static curriculum**: `learning_data.dart` replaces JSON DAG (`aritmetica_1.json`, M001-M003, L001-L002)
- **3-layer hybrid architecture**: Async Strategist (SessionAnalyzer) + Rules Engine (ToneAdapter, DevilsAdvocate) + Live Chat (Gemma)
- **Inference fixes**: Wire sampling params (`temperature=0.4, topK=64, topP=0.85, repeatPenalty=1.1`) to `createChat()`, force `maxTokens=256`
- **RegExp removal**: Replace all RegExp in hot paths with native String methods
- **Lightweight truncation**: `lastIndexOf('.')`/`'!'`/`'?'` — no RegExp
- **UI for kids**: Hybrid input (TextField + dynamic chips), overflow handling, error/retry states
- **ABI splits + signing**: Release-ready APK configuration
- **8 commits, 4-person team** (Luis, Alexander, Freddy, Jesús)

### Out of Scope
- Teacher Dashboard (frozen, Phase 2)
- IRT diagnostic complexity (simplify to primary-appropriate assessment)
- BKT engine (replaced by simple mastery tracking)
- 1° Secundaria content and JSON lesson catalog
- xAPI/SCORM export, Firebase sync, Cloud Run
- Mic input, media attachments, multi-student profiles

## Capabilities

### New Capabilities
- `rules-engine`: Pure Dart module (`rules_engine/`) — `ToneAdapter` adjusts tone via `StudentState.masteryMap`, `DevilsAdvocate` injects trick questions on streaks. Zero inference.
- `static-curriculum`: 4to primaria Comunicación + Matemática as static `learning_data.dart`. No JSON, no SQLite for curriculum.
- `session-analyzer`: Extends `diagnostico/` — async JSON summary per session ("qué falló", "qué reforzar"). Consumed by Rules Engine Layer 2.
- `dynamic-chips`: Context-aware quick-action chips that adapt labels based on conversation state and current topic.
- `text-truncation`: `truncateAtSentence()` using `lastIndexOf` on punctuation. No RegExp.

### Modified Capabilities
- `ai-sampling`: `maxTokens` changed 1024→256; params wired to `createChat()` (was defined but unused)
- `yachay-curriculum`: Replaced — 1° Secundaria `aritmetica_1.json` DAG → 4to Primaria static `learning_data.dart`
- `yachay-dashboard`: **Removed** from MVP. Frozen for Phase 2.
- `yachay-mastery`: Simplified — BKT (`P(L₀)`, `P(T)`, slip/guess) → simple `correct/total` ratio suitable for primary
- `ai-fallback`: Layer 1 regex table → native `String.contains()/startsWith()`. Keyword routing extended for 4to primaria topics.

## Approach

**Extend, don't rewrite.** Preserve working Gemma inference pipeline (`flutter_gemma 1.4.2`, `LiteRtLmEngine`), `StudentState` + `Provider`, and `FallbackDispatcher` 4-layer system. Strip secondary-level complexity and add primary-appropriate layers:

1. **Commits 2-3 (Jesús)**: Replace curriculum content — static Dart data, Spanish-language exercises for 9-10 year olds
2. **Commits 4-5 (Alexander)**: Inference hardening — sampling wiring, token cap, RegExp→String, truncation
3. **Commit 6 (Freddy)**: Kid-friendly UI — oversized touch targets, color-coded chips, error retry with bundled fallback
4. **Commit 8 (Luis)**: Rules engine — layering pre/post-chat hooks without touching Gemma inference hot path

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/modules/diagnostico/` | Modified | Simplify IRT for primary; add SessionAnalyzer |
| `lib/modules/aprendizaje/` | Modified | Replace secondary lessons with 4to primaria content |
| `lib/modules/gemma/gemma_service.dart` | Modified | Wire sampling, maxTokens=256, RegExp→String, truncation |
| `lib/modules/gemma/fallback_dispatcher.dart` | Modified | Layer 1 regex→native, extend keyword table |
| `lib/modules/gemma/tool_handlers/` | Modified | Remove RegExp in `explicar_tema`, `generar_ejercicios`, `obtener_leccion` |
| `lib/modules/yachay/` | Modified | Remove TeacherDashboard, simplify mastery, add chips to ChatScreen |
| `lib/modules/rules_engine/` | **New** | ToneAdapter, DevilsAdvocate, SessionAnalyzer consumer |
| `lib/core/learning_data.dart` | **New** | Static 4to primaria curriculum (Comunicación + Matemática) |
| `android/app/build.gradle` | Modified | ABI splits, signing config |
| `assets/data/fallback_responses.json` | Modified | Add 4to primaria fallback entries |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| maxTokens=256 may truncate tool-calling JSON | Medium | Test with worst-case tool chains. Truncate mid-sentence gracefully via `truncateAtSentence()`. |
| Static curriculum outgrows single file | Low | `learning_data.dart` sized for 4to primaria scope (~200 exercises). Split into `comunicacion_data.dart` + `matematica_data.dart` if needed. |
| RegExp removal breaks fallback greeting detection | Low | 12 trivial greetings. `String.contains()`/`toLowerCase()` coverage is identical. |
| ABI splits break CI or device compatibility | Low | Test on A32 (armeabi-v7a) only. Add arm64-v8a split post-MVP. |
| Rules engine adds latency before chat response | Low | Pre/post hooks run in <5ms — pure Dart, no I/O, no inference. |

## Rollback Plan

1. **Per-commit revert**: Each of the 8 commits is self-contained. Revert any single commit without cascading breakage.
2. **Full rollback**: Revert branch to pre-MVP state. `1° Secundaria` content and BKT/IRT logic remain in git history. Only static curriculum and rules engine are net-new files.
3. **Gemma inference safety**: Sampling params and maxTokens changes are additive — `SamplingConfig` defaults remain as fallback. If maxTokens=256 proves too restrictive, revert to 1024 without affecting other commits.

## Dependencies

- `flutter_gemma 1.4.2` + `gemma-4-E2B-it.litertlm` (2.59 GB) — already stable on A32
- Existing `StudentState.masteryMap` for Rules Engine consumption
- Minedu 4to Primaria curricular standards (DCN 2024) for content authoring

## Stakeholder Needs

Referenced from ISO 15288 traceability docs (6.4.2). ISO documents not found in current workspace — needs verification.

| Need | Description | This Change |
|------|-------------|-------------|
| N-01 | Evaluación diagnóstica | Simplified for 4to primaria, SessionAnalyzer added |
| N-03 | Entrega adaptativa de contenido | Hybrid: static curriculum + Gemma live chat |
| N-04 | Operación sin conexión | Preserved — all layers offline, no new network deps |
| N-08 | Privacidad de datos | Preserved — SQLCipher, local-only, no cloud |

## Success Criteria

- [ ] App launches on Galaxy A32 with 4to primaria curriculum loaded
- [ ] Gemma responds with maxTokens=256 and wired sampling params
- [ ] Fallback dispatcher works without any RegExp usage
- [ ] ChatScreen shows dynamic chips and handles overflow gracefully
- [ ] Rules Engine ToneAdapter modifies response tone based on mastery
- [ ] Static curriculum covers Comunicación + Matemática (4to primaria Minedu)
- [ ] Debug APK builds with ABI splits (armeabi-v7a)
