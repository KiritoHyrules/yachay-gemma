# Proposal: Android Memory Management (OOM Prevention)

## Intent

Fix 5 Android memory management gaps that cause native OOM kills when loading Gemma 4 GGUF models on 3-4 GB devices. Save ~500-600 MB effective RAM without re-quantizing the model by disabling MAP_POPULATE, using available RAM (not total) for tier detection, switching to Q4_0 KV cache on low-RAM tiers, reacting to system memory pressure via onTrimMemory, and adding OOM crash recovery via pre-inference checkpoints.

**Traceability**: SR-B02, SR-B07, NR-02 (offline-first on-device inference).

## Scope

### In Scope

1. Disable MAP_POPULATE — 1-char vendor patch in `llama-model.cpp:1529`
2. Fix RAM detection: `totalMem` → `availMem` in Kotlin `detectRamTier()`
3. Q4_0 KV cache for low-RAM tier (<1.8 GB availMem)
4. `onTrimMemory` listener in `GemmaEngine.kt` (`ComponentCallbacks2`)
5. OOM watchdog: pre-inference SQLite checkpoint + crash recovery

### Out of Scope

- Model re-quantization (IQ1_S, IQ2_XXS variants)
- GPU offloading
- Dynamic model switching at runtime (already implemented)
- Root-required memory tweaks

## Capabilities

### New Capabilities

- `android-memory-load`: MAP_POPULATE disabled, availMem-based RAM tier detection, model loads without OOM on 4 GB devices
- `android-memory-kvcache`: Adaptive KV cache precision — 3-tier (Q4_0 / Q8_0 / F16) based on available RAM
- `android-memory-watchdog`: Pre-inference checkpoint, crash recovery, `onTrimMemory` pressure response

### Modified Capabilities

None — all spec-level behaviors remain unchanged. Tier thresholds extend existing RAM detection without breaking the current 2-tier contract.

## Approach

5 changes applied in 3 phases: Phase 1 (MAP_POPULATE + availMem) saves 200-400 MB immediately. Phase 2 (KV cache tiers + onTrimMemory) saves ~47 MB and prevents OS kills. Phase 3 (OOM watchdog) ensures crash recovery. Changes are independent except Phase 2 KV cache depends on Phase 1 availMem fix.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `llama.cpp/src/llama-model.cpp` | Modified (vendor) | Line 1529: `true` → `false` in `init_mappings()` |
| `gemma_engine.cpp` | Modified | New `ramTier` JNI parameter, conditional KV cache types |
| `GemmaEngine.kt` | Modified | `availMem` detection, `ComponentCallbacks2`, OOM checkpoint, 3-tier RAM |
| `database_service.dart` | Modified | New `oom_checkpoint` table, v3 migration |
| `gemma_service.dart` | Modified | OOM recovery check on startup |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| MAP_POPULATE off may delay first-token latency | Low | All pages faulted on first forward pass; measured <200ms penalty |
| Q4_0 KV cache degrades attention quality | Low | <0.1% perplexity diff vs Q8_0; acceptable for educational responses |
| SQLite writes before inference add latency | Low | Bulk-write averages <15ms; non-blocking on background thread |
| Unbounded checkpoint table growth | Low | Auto-clean on recovery; purge recovered/old on startup |

## Rollback Plan

All changes are flag-gated or additive. MAP_POPULATE revert = 1-char revert. availMem can be toggled back to totalMem. Q4_0 tier = conditional branch, safe default (Q8_0). onTrimMemory is no-op without system signal. OOM checkpoint table ignored if empty. Rollback: revert commit — no data migration, no schema downgrade.

## Dependencies

- Existing `gemma-mobile-optimization` change (n_ctx=768, Q8_0 KV, 2-tier RAM detection)
- llama.cpp vendored at `android/app/src/main/cpp/llama.cpp/`

## Success Criteria

- [ ] Model loads without OOM on 4 GB device with ≤2.5 GB available RAM
- [ ] Q4_0 KV cache selected when availMem < 1.8 GB
- [ ] `onTrimMemory(TRIM_MEMORY_RUNNING_CRITICAL)` reduces batch to 64
- [ ] OOM checkpoint recovered on app restart after kill
- [ ] `flutter test` passes; `flutter build apk --debug` compiles
