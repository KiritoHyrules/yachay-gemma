# Tasks: MVP 4to Primaria — Reorientación Curricular

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~945 (additions + deletions) |
| 400-line budget risk | **High** (2.4×) |
| Chained PRs recommended | **Yes** |
| Delivery strategy | ask-on-risk |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | PR | Test | Runtime | Rollback |
|------|------|-----|------|---------|----------|
| 1 | Base + curriculum data (C1+C2, ~275L) | PR1 | `dart test test/core/data/` | `flutter run` → curriculum loads | Revert PR1 |
| 2 | Content + inference (C3+C4+C5, ~360L) | PR2 | `dart test test/core/utils/` | `flutter run` → chat with sampling | Revert PR2 |
| 3 | UI + build + rules (C6+C7+C8, ~310L) | PR3 | `flutter test test/modules/rules_engine/` | `flutter run` → chips/retry/tone | Revert PR3 |

**Parallelism**: C2+C3 share `learning_data.dart` (sequential). C4+C5 share `gemma_service.dart` (sequential). C6, C7, C8 are file-independent (parallel within PR3).

---

## Phase 1: Foundation (Models, Data, Infrastructure)

- [ ] **C1.1** [ARCH] Update `AGENTS.md`: "secondary"→"4to Primaria", add `lib/core/data/` + `rules_engine/` sections.
- [ ] **C1.2** [ARCH] Create `CHANGELOG.md` with MVP baseline entry (date, scope, 3 areas).
- [ ] **C1.3** [ARCH] Create `MVP_CONSTRAINTS.md`: maxTokens=256, offline-only, no BKT, no dashboard, arm64-v8a.
- [ ] **C1.4** [ARCH] Remove TeacherDashboard route from `lib/main.dart` and `yachay_scaffold.dart`.
- [ ] **C2.1** [DATA] Create `lib/core/data/learning_data.dart`: `TemaPrimaria` + `Curricula4toPrimaria` with 18+ topics (id, area, titulo, explicacion ≤90w, chips 3-4, prioridad).
- [ ] **C2.2** [DATA] Extend `assets/data/fallback_responses.json` with 4to primaria greeting/intent entries.
- [ ] **C5.1** [INFERENCE] Create `lib/core/utils/text_utils.dart`: `truncateAtSentence()` (zero RegExp, lastIndexOf: . > ! > ? > ; > ,) + `stripTopicPrefix()`.
- [ ] **C8.1** [ARCH] Create `lib/modules/rules_engine/tone_adapter.dart`: `ToneAdapter.adjust(pLearned, consecutiveFailures)` — 3 tone bands + failure override.
- [ ] **C8.2** [ARCH] Create `lib/modules/rules_engine/devils_advocate.dart`: `DevilsAdvocate.intervene(streaks)` — trick question or null.
- [ ] **C8.3** [ARCH] Create `lib/modules/diagnostico/session_analyzer.dart`: `SessionAnalyzer.analizar(entries, {n})` → fortalezas/debilidades/recomendaciones JSON.
- [ ] **C8.4** [DATA] Add `consecutiveFailures` field to `lib/core/models/topic_mastery.dart`.

## Phase 2: Core Implementation

- [ ] **C3.1** [DATA] Expand `learning_data.dart`: ≥6 CyT + expand Comunicación to ≥8 (total ≥24). Validate ≤90w each.
- [ ] **C3.2** [DATA] Refactor `lib/modules/yachay/curriculo_service.dart`: replace DAG with `Curricula4toPrimaria.temas`, remove asset load/fallback.
- [ ] **C3.3** [DATA] Remove `bloqueado` field from `obtener_plan_completo.dart`.
- [ ] **C3.4** [DATA] `obtener_siguiente_tema.dart`: flat iteration, first pLearned<0.80, completion if all mastered.
- [ ] **C4.1** [INFERENCE] Extend `gemma_inference_adapter.dart` `createChat()`: add temperature, topK, topP, repeatPenalty params.
- [ ] **C4.2** [INFERENCE] `gemma_service.dart`: wire sampling (t=0.4, k=64, p=0.85, rp=1.1) + force maxTokens=256.
- [ ] **C4.3** [INFERENCE] `gemma_service.dart`: replace 3 RegExp — greeting (startsWith chain), prefix strip (indexOf), keep meminfo RegExp.
- [ ] **C4.4** [INFERENCE] `fallback_dispatcher.dart`: L1 RegExp→`String.contains()`/`toLowerCase()`, remove regex key from JSON.
- [ ] **C4.5** [INFERENCE] `tool_handlers/{explicar_tema,generar_ejercicios,obtener_leccion}.dart`: RegExp→`indexOf('_')` inline.
- [ ] **C5.2** [INFERENCE] Integrate `truncateAtSentence()` into `sendWithStreaming()` onComplete in `gemma_service.dart`.
- [ ] **C8.5** [ARCH] `student_state.dart`: replace BKT with `pLearned=correct/max(attempts,1)`, threshold 0.80.
- [ ] **C8.6** [ARCH] `fallback_dispatcher.dart`: `setToolContext()` injection + L3 real mastery + L4 ToneAdapter integration.
- [ ] **C8.7** [ARCH] Wire `SessionAnalyzer` call at session-end in `diagnostico_service.dart`.

## Phase 3: UI & Wiring

- [ ] **C6.1** [UI] `chat_screen.dart`: `TextOverflow.ellipsis` + `maxLines:3` on `_MessageBubble`.
- [ ] **C6.2** [UI] `chat_screen.dart`: dynamic chips from `Curricula4toPrimaria.temas` via `_ContextChipRow`.
- [ ] **C6.3** [UI] `yachay_scaffold.dart`: error state with "Reintentar" button on model unavailable.
- [ ] **C8.8** [ARCH] `gemma_service.dart`: wire ToneAdapter pre-prompt + DevilsAdvocate per-turn into chat flow.

## Phase 4: Build & Release

- [ ] **C7.1** [BUILD] `android/app/build.gradle`: ABI splits `arm64-v8a` only.
- [ ] **C7.2** [BUILD] `android/app/build.gradle` + `key.properties`: release keystore config.
- [ ] **C7.3** [BUILD] `android/build.gradle`: unify Kotlin to 2.2.20.
- [ ] **C7.4** [BUILD] Verify `flutter build apk --debug` APK < 50MB.

## Phase 5: Testing & Cleanup

- [ ] **C5.3** [INFERENCE] `test/core/utils/text_utils_test.dart`: 7 edge cases for `truncateAtSentence()`.
- [ ] **C2.3** [DATA] `test/core/data/learning_data_test.dart`: ≥24 topics, 3 areas, ≤90w explicaciones, unique IDs.
- [ ] **C8.9** [ARCH] `test/modules/rules_engine/`: ToneAdapter (3 bands+failures) + DevilsAdvocate (streak≥3/null).
- [ ] **C8.10** [ARCH] `test/modules/diagnostico/session_analyzer_test.dart`: mixed, all-mastered, empty, no-exception.
- [ ] **C1.5** [ARCH] `flutter analyze` clean pass; remove stale 1° Secundaria references from comments.
