# Tasks: Android Memory Management (OOM Prevention)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~250 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | All 4 phases — MAP_POPULATE + availMem + KV cache tiers + onTrimMemory + OOM watchdog | Single PR | `flutter test` | `flutter build apk --debug` | `git revert` — all changes contained in one commit |

## Phase 1: MAP_POPULATE + availMem (2 tasks)

- [x] 1.1 [CPP/VENDOR] Patch `llama-model.cpp:1529`: change `init_mappings(true, ...)` → `init_mappings(false, ...)`. Add `model_params.load_mode = LLAMA_LOAD_MODE_MMAP` at `gemma_engine.cpp:95` (explicit intent).
- [x] 1.2 [KT] Replace `memInfo.totalMem` with `memInfo.availMem` in `GemmaEngine.detectRamTier()` (line 250). Lower `RAM_THRESHOLD_MB` from 3584 to 2500. Add dual-check warning when totalMem >= 3584 but availMem < 2500. Guard availMem=0 edge case → default to iq2_m. Update docstring at line 240.

## Phase 2: KV Cache Tiers + onTrimMemory (2 tasks)

- [x] 2.1 [CPP/KT] Add `jstring jramTier` parameter to `loadModelJni` JNI signature. Update Kotlin `external fun loadModelJni(path: String, ramTier: String): Long` at line 371. In `gemma_engine.cpp`, parse ramTier string and conditionally set KV types: `"iq2_xxs"` or `"low"` → Q4_0, `"iq2_m"` or `"med"` → Q8_0, unknown → Q8_0 (safe default). Pass ramTier from `handleLoadModel()` line 133: `loadModelJni(path, ramTier)`. Update `detectRamTier()` for 3-tier output: low/med/high based on availMem thresholds.
- [x] 2.2 [KT] Add `ComponentCallbacks2` interface to `GemmaEngine` class declaration (line 34). Register with `context.registerComponentCallbacks(this)` in init/constructor (after line 33). Implement `onTrimMemory(level)`: TRIM_MEMORY_RUNNING_MODERATE → log + flush caches, TRIM_MEMORY_RUNNING_CRITICAL → log + reduce batch, TRIM_MEMORY_UI_HIDDEN → log only. Implement `onLowMemory()` → aggressive cache flush. Add `unregister()` method calling `context.unregisterComponentCallbacks(this)`. Wire `unregister()` into `handleUnloadModel()`.

## Phase 3: OOM Watchdog (1 task)

- [x] 3.1 [DB/KT/DART] Add `oom_checkpoint` table in `database_service.dart`: bump version 2→3, create in `_onCreate` and `_onUpgrade`. Table schema: id, session_id, user_message, system_prompt, timestamp, pending_tool, recovered, recovery_response. In `GemmaEngine.kt`, add `saveOomCheckpoint()` (INSERT with SQLite), `clearOomCheckpoint()` (DELETE or mark recovered=1), `recoverFromOom()` (query unrecovered rows). Call save before `generateJni()` in `handleGenerate()` (line 174) and `handleGenerateStream()` (line 333). Call clear after successful generation. In `gemma_service.dart`, add OOM recovery check at start of `cargarModelo()` (line 131): if unrecovered checkpoints exist, return recovery message string and clear them. Add recovery message template to fallback data. Add startup cleanup: `DELETE FROM oom_checkpoint WHERE recovered=1 AND timestamp < datetime('now', '-1 day')`.

## Phase 4: Integration Test (1 task)

- [x] 4.1 [TEST] Dart unit test for `_defaultModelPath()` with 3-tier RAM. Kotlin unit test for `detectRamTier()` with availMem at tier boundaries (1.0/2.0/3.5 GB). Dart unit test for OOM recovery: mock DB with unrecovered checkpoint → verify recovery message; empty checkpoints → normal load path. Run `flutter test`, verify all pass. Run `flutter build apk --debug`, verify compilation with JNI signature changes.

## Dependency Order

```
(1.1) MAP_POPULATE   ── independent (vendor patch)
(1.2) availMem fix   ── independent, prerequisite for (2.1)
(2.1) Q4_0 KV cache  ── depends on (1.2) for tier detection
(2.2) onTrimMemory   ── independent
(3.1) OOM watchdog   ── independent
(4.1) Tests          ── depends on all above
```

Changes (1.1), (2.2), and (3.1) can be implemented in parallel. (1.2) must complete before (2.1).
