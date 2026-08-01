# Proposal: Gemma 4 Mobile Optimization

## Intent

Gemma 4 E2B IQ2_M (2.6 GB GGUF) OOMs on 3.8 GB phones — the Gemma Competition 2026 target. The native engine crashes silently; the app falls back to pre-authored JSON (ai-fallback layer 4). This change applies aggressive optimization (Nintendo Switch Principle) to fit IQ2_XXS (~2.0 GB) at 768-token context on 3.8 GB devices, preserving live AI inference as the primary path. Gemma 4 remains the engine — no model downgrade.

**Traceability**: SR-B02, SR-B07, NR-02 (offline-first on-device inference).

## Scope

### In Scope

- 9 parameter changes in `gemma_engine.cpp`: n_ctx→768, type_k/v→Q8_0, flash_attn→ENABLED, threads→1, batch→256, sampler n_ctx fix (4096→768)
- RAM detection in `GemmaEngine.kt` via `ActivityManager.MemoryInfo` — 2-tier: IQ2_M (≥3.5 GB), IQ2_XXS (<3.5 GB)
- `gemma_service.dart`: `_defaultModelPath()` → variant-aware resolution with IQ2_M fallback
- `AndroidManifest.xml`: `largeHeap="true"` + RAM feature declaration
- `scripts/quantize_model.py`: developer pre-build pipeline (BF16→IQ2_XXS via llama-quantize)
- TDD tests for Dart path resolution, Kotlin RAM thresholds, build verification

### Out of Scope

- IQ1_S quantization (deferred — reactive only if IQ2_XXS OOMs post-optimization)
- Dynamic model switching at runtime (Phase 2)
- GPU offloading
- 3-tier RAM detection

## Capabilities

### New Capabilities

- `gemma-mobile-engine`: optimized native context parameters, RAM-aware model variant selection, largeHeap signaling, quantization pipeline

### Modified Capabilities

None — all spec-level behaviors (ai-fallback, ai-streaming, ai-sampling config) remain unchanged.

## Approach

**Phase 1 — Native engine** (`gemma_engine.cpp`): KV cache 574→108 MB via n_ctx=768 + Q8_0 KV types + flash_attn. Threads 2→1, batch 512→256. Fix sampler n_ctx mismatch.

**Phase 2 — Android + Dart**: Kotlin detects `totalMem` at init, selects variant before JNI. Dart `_defaultModelPath()` resolves multi-variant with IQ2_M default. `largeHeap` signals OS to ease memory pressure.

**Phase 3 — Quantization**: `scripts/quantize_model.py` wraps llama-quantize. Dev runs once on 12 GB+ machine, uploads ~2.0 GB GGUF to HF LFS.

**Phase 4 — Integration**: Real 3.8 GB device, IQ2_XXS, 7-round Yachay dispatch under 768 ctx.

## Memory Budget (768 ctx, Q8_0 KV ~108 MB)

| Variant | Model | +Runtime | +KV | Total | Margin on 3.8 GB |
|---------|-------|----------|-----|-------|-------------------|
| IQ2_XXS | 2.00 GB | 0.60 GB | 0.11 GB | 2.71 GB | +1.09 GB ✓ |
| IQ2_M (current) | 2.60 GB | 0.60 GB | 0.57 GB | 3.77 GB | +0.03 GB ⚠️ |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `gemma_engine.cpp` | Modified | 9 params: n_ctx, type_k/v, flash_attn, threads, batch, sampler n_ctx |
| `GemmaEngine.kt` | Modified | RAM detection + 2-tier variant selection in `handleLoadModel` |
| `gemma_service.dart` | Modified | `_defaultModelPath()` multi-variant, `cargarModelo()` passes hint |
| `AndroidManifest.xml` | Modified | `largeHeap`, RAM `<uses-feature>` |
| `scripts/quantize_model.py` | New | BF16→IQ2_XXS pipeline |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| 768 ctx overflows 7-round dispatch | Medium | Test with Yachay tool-calling scenarios; increase to 1024 if needed (+36 MB) |
| IQ2_XXS 98% quality degrades math reasoning | Low | Validate with diagnostic items against IQ2_M baseline |
| RAM detection reports inaccurate `totalMem` | Low | Add 10% safety margin to thresholds |
| Flash attention no-op on ARM CPU | Low | Benchmark; fall back to AUTO if no benefit |

## Rollback Plan

All changes are additive or flag-gated. `_defaultModelPath()` returns IQ2_M path when optimized model absent. `gemma_engine.cpp` defaults safe (n_ctx=2048, F16 KV, 2 threads). `largeHeap` has zero behavioral change on its own. Revert by rolling back commit — no data migration, no DB schema changes.

## Dependencies

- `llama-quantize` binary (from llama.cpp build, developer machine)
- BF16 GGUF base: `ggml-org/gemma-4-E2B-it-GGUF` (~9.31 GB, one-time download)
- HF LFS for hosting output IQ2_XXS GGUF (~2.0 GB)

## Success Criteria

- [ ] IQ2_XXS model loads and infers on real 3.8 GB device without OOM
- [ ] 7-round Yachay dispatch loop completes under 768 ctx
- [ ] `flutter test` passes (new + existing)
- [ ] `flutter build apk --debug` compiles
- [ ] APK ≤ 50 MB (models external)
- [ ] IQ2_M path used when optimized model not found (backward compat)
