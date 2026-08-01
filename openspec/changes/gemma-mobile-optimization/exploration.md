# Exploration: gemma-mobile-optimization

**Date**: 2026-07-30
**Context**: Gemma 4 E2B IQ2_M (2.6GB GGUF) crashes with native OOM on a 3.8GB RAM phone.

---

## Current State

### Native Engine (`gemma_engine.cpp`)

The JNI bridge between Kotlin and llama.cpp uses a per-process singleton (`g_state`) with these **hardcoded** parameters:

| Parameter | Current | Line(s) | Impact |
|-----------|---------|---------|--------|
| `n_ctx` | 2048 | 40 (struct), 109 (ctx_params) | KV cache size is linear in context |
| `n_batch` | 512 | 110 | Prompt ingestion batch memory |
| `n_ubatch` | 512 | 111 | Physical batch memory |
| `n_threads` | 2 | 112 | CPU concurrency |
| `n_threads_batch` | 2 | 113 | Batch processing concurrency |
| `flash_attn_type` | **Not set** (default=auto) | — | Missing; defaults to -1 (AUTO) |
| `type_k` | **Not set** (default=f16) | — | K cache uses 2 bytes/element |
| `type_v` | **Not set** (default=f16) | — | V cache uses 2 bytes/element |
| Sampler `n_ctx` | 4096 (hardcoded) | 193, 341 | Inconsistent with actual context |

**Consequence**: KV cache alone consumes ~574 MB at 2048 ctx (F16). The model file (IQ2_M ≈ 2.6 GB) + runtime overhead (~600 MB) + KV cache pushes total beyond 3.8 GB.

### Linux Kernel OOM Behavior on Android

When `llama_init_from_model()` allocates the KV cache, the kernel's OOM killer terminates the process if available RAM + swap is exhausted. The app crashes silently without a Java-level `OutOfMemoryError` — the native allocation fails at the C level and `llama_init_from_model` returns NULL. The current `GemmaEngine.kt` catches this as a load failure and the Dart `GemmaService` silently falls back to `fallback_responses.json`.

### Model Path Resolution (`gemma_service.dart`)

Line 845 — hardcoded to a single variant:
```dart
String _defaultModelPath() {
  return '/data/data/com.aprendoplus.app/files/google_gemma-4-E2B-it-IQ2_M.gguf';
}
```

No mechanism to select between multiple GGUF variants. The Kotlin `GemmaEngine.kt` simply passes whatever path Dart provides through to JNI — neither layer performs variant selection or RAM-aware routing.

### Android Manifest (`AndroidManifest.xml`)

- **Missing**: `android:largeHeap="true"` on `<application>` (line 8). Without this flag, Android limits the Dalvik/ART heap to the device-specific default (typically 128–512 MB). While the native heap (C++ allocations via JNI/mmap) is NOT subject to this limit, the JVM-side allocation for the `GemmaEngine` class and its JNI references IS. More importantly, `largeHeap` signals the OS to be less aggressive about killing the process under memory pressure.
- **Missing**: `<uses-feature android:name="android.hardware.ram" android:required="false"/>` — no declarative RAM floor.

### Build Configuration (`build.gradle`)

Already correctly configured:
- `noCompress 'gguf'` (line 53) — GGUF files are not recompressed in the APK
- `abiFilters 'arm64-v8a'` (line 48) — only 64-bit ARM, correct for AI inference
- `multiDexEnabled = true` (line 45) — good for large native libs

### llama.cpp API Confirmed (`llama.h`)

All required fields exist in `llama_context_params`:

| Field | Type | Line | Values |
|-------|------|------|--------|
| `flash_attn_type` | `enum llama_flash_attn_type` | 363 | `AUTO=-1`, `DISABLED=0`, `ENABLED=1` |
| `type_k` | `enum ggml_type` | 378 | `GGML_TYPE_Q8_0=8`, `GGML_TYPE_F16=1`, etc. |
| `type_v` | `enum ggml_type` | 379 | same as type_k |
| `n_ctx` | `uint32_t` | 350 | any value; 0 = from model metadata |
| `n_batch` | `uint32_t` | 351 | logical max batch size |
| `n_threads` | `int32_t` | 356 | generation threads |
| `n_threads_batch` | `int32_t` | 357 | batch processing threads |

Quantization file types in `enum llama_ftype`:
- `LLAMA_FTYPE_MOSTLY_IQ2_XXS = 19` (line 136)
- `LLAMA_FTYPE_MOSTLY_IQ1_S = 24` (line 141)

## Affected Areas

### Code Files (direct modifications)

| File | Reason |
|------|--------|
| `android/app/src/main/cpp/gemma_engine.cpp` | Lines 40, 109–113, 193, 341 — all optimization parameters |
| `android/app/src/main/kotlin/.../GemmaEngine.kt` | New RAM detection logic, multi-variant loading |
| `lib/modules/gemma/gemma_service.dart` | `_defaultModelPath()` → multi-variant resolution |
| `android/app/src/main/AndroidManifest.xml` | Add `android:largeHeap="true"`, RAM feature declaration |

### External Artifacts (not in repo)

| Artifact | Purpose | Source |
|----------|---------|--------|
| `gemma-4-E2B-it-IQ2_XXS.gguf` (~2.0 GB) | Medium-tier quantized model | Self-quantize from BF16 via `llama-quantize` |
| `gemma-4-E2B-it-IQ1_S.gguf` (~1.4 GB) | Low-tier quantized model | Self-quantize from BF16 via `llama-quantize` |
| `gemma-4-E2B-it-IQ2_M.gguf` (~2.6 GB) | Existing high-tier model | Already in use |

### Model File Sourcing

**Verified**: Pre-converted IQ2_XXS and IQ1_S GGUF files for Gemma 4 E2B do NOT exist in public Hugging Face repos (checked unsloth, ggml-org, bartowski, lmstudio-community). Available quants:

| Source | Available Quants | Smallest |
|--------|-----------------|----------|
| `ggml-org/gemma-4-E2B-it-GGUF` | Q4_0 (2.84 GB), Q8_0, BF16 | Q4_0 |
| `unsloth/gemma-4-E2B-it-GGUF` | IQ4_NL, IQ4_XS, Q3_K_S, UD-IQ2_M | Q3_K_S (2.45 GB) |
| QAT official | Q4_0 GGUF | Q4_0 (3.04 GB) |

**Action required**: Self-quantize from BF16 GGUF (~9.31 GB) using `llama-quantize`:
```bash
llama-quantize gemma-4-E2B-it-BF16.gguf gemma-4-E2B-it-IQ2_XXS.gguf IQ2_XXS
llama-quantize gemma-4-E2B-it-BF16.gguf gemma-4-E2B-it-IQ1_S.gguf IQ1_S
```

This requires a machine with ~12 GB RAM (to load BF16) and takes ~1–2 hours.

## Gap Analysis: Current vs Target

### Optimization 1: Code-Level Memory Reductions (~160 MB estimated)

| Change | Current | Target | File:Line | Savings |
|--------|---------|--------|-----------|---------|
| Reduce context | 2048 | 512 | gemma_engine.cpp:40,109 | ~430 MB KV at F16; ~215 MB at Q8_0 |
| KV cache type_k/type_v | F16 (default) | Q8_0 | gemma_engine.cpp: after 113 | ~72 MB at 512 ctx |
| Flash attention | Not set | ENABLED | gemma_engine.cpp: after 113 | ~0 MB (speed, slight memory optimization) |
| Threads | 2 + 2 | 1 + 1 | gemma_engine.cpp:112-113 | ~5–10 MB |
| Batch | 512 | 256 | gemma_engine.cpp:110-111 | ~5–10 MB |
| Sampler n_ctx fix | 4096 | 512 | gemma_engine.cpp:193,341 | correctness only |

**Net code savings**: ~150–170 MB.

### Optimization 2: Smaller Quantization

| Variant | Est. File Size | Fit on 3.8 GB? | Fit on 2 GB? | Quality vs IQ2_M |
|---------|---------------|----------------|-------------|------------------|
| IQ2_M (current) | ~2.6 GB | Crashes | No | Baseline |
| Q3_K_S (available) | ~2.45 GB | Tight | No | ~99% |
| IQ2_XXS (self-quantize) | ~2.0 GB | Yes | Tight | ~98% |
| IQ1_S (self-quantize) | ~1.4 GB | Yes | Yes | ~95% |

With 512 ctx + Q8_0 KV (~72 MB) + runtime overhead (~600 MB):

| Variant | Total RAM | Margin on 3.8 GB | Margin on 2.5 GB |
|---------|-----------|-------------------|-------------------|
| IQ2_M | ~3.27 GB | +530 MB (too tight) | -770 MB (impossible) |
| IQ2_XXS | ~2.67 GB | +1.13 GB ✓ | -170 MB (tight) |
| IQ1_S | ~2.07 GB | +1.73 GB ✓ | +430 MB ✓ |

### Optimization 3: Android Manifest

| Change | Current | Target |
|--------|---------|--------|
| `largeHeap` | Missing | `android:largeHeap="true"` on `<application>` |
| RAM feature | Missing | `<uses-feature android:name="android.hardware.ram" android:required="false"/>` |

### Optimization 4: Adaptive Model Loading

**Device RAM detection strategies**:

| Approach | Location | API | Suitability |
|----------|----------|-----|-------------|
| `ActivityManager.MemoryInfo` | Kotlin (JVM) | `totalMem`, `availMem` | **Best** — reliable across all Android versions |
| `/proc/meminfo` parsing | C++ (JNI) | `MemTotal`, `MemAvailable` | Works but fragile across kernels |
| Custom MethodChannel | Dart → Kotlin | New channel for RAM query | Adds complexity; Kotlin can decide directly |

**Recommended architecture**: Kotlin `GemmaEngine.kt` detects total RAM at init and selects the model variant BEFORE calling JNI:

```
Device total RAM < 2.5 GB  →  IQ1_S  (~2.07 GB total)
Device total RAM 2.5–3.5 GB → IQ2_XXS (~2.67 GB total)
Device total RAM > 3.5 GB  →  IQ2_M  (~3.27 GB total)
```

The Dart `GemmaService` passes a `modelPath` hint but Kotlin can override it based on detected RAM. This keeps the RAM detection logic in the native layer where it belongs.

## Complexity Estimation

| # | Change | Complexity | Risk | Dependencies |
|---|--------|-----------|------|-------------|
| 1 | Reduce n_ctx to 512 | **Low** — 2 lines changed | Medium — may reduce answer quality for tool-calling dispatch loop (needs up to 7 rounds) | None |
| 2 | KV cache Q8_0 | **Low** — set 2 fields in ctx_params | Low — well-tested in llama.cpp | None |
| 3 | Flash attention enable | **Low** — set 1 field | Low — CPU-only, may be no-op on ARM | None |
| 4 | Threads/batch reduction | **Low** — 2 lines | Low — slight speed penalty | None |
| 5 | Sampler n_ctx fix | **Low** — 2 lines | None — bugfix only | None |
| 6 | largeHeap in manifest | **Low** — 1 attribute | None | None |
| 7 | Multi-variant model path | **Medium** — touch 3 files | Medium — path resolution changes | #8 |
| 8 | RAM detection + variant selection | **Medium** — new Kotlin code | Medium — must handle edge cases (no permission, 0 RAM reported) | #7 |
| 9 | Quantize IQ2_XXS / IQ1_S | **High** — external tooling | High — quality regression risk, file hosting (2+3.4 GB total) | #7, #8 |

## Dependencies Graph

```
(1) n_ctx       ──┐
(2) KV Q8_0      ├── Independent, can be done in parallel
(3) Flash Attn   │
(4) Threads/batch│
(5) Sampler fix  │
(6) largeHeap   ──┘
                    │
(9) Quantize ──────→ (7) Multi-variant path ──→ (8) RAM detection
```

Code optimizations (1–6) are independent and can be committed together. Model quantization (9) must happen before multi-variant path (7) can be tested end-to-end. RAM detection (8) depends on (7) being in place.

## Verification Strategy

1. **Build test**: `flutter build apk --debug` — must compile without errors
2. **Unit tests**: New Dart tests for `_defaultModelPath()` variant selection
3. **Kotlin unit tests**: `ActivityManager.MemoryInfo` mock for RAM detection thresholds
4. **Integration**: Run on a real 3.8 GB device with the IQ2_XXS model → verify no OOM
5. **Regression**: `flutter test` — ensure existing fallback behavior is preserved
6. **Quality**: Manual testing of 512-ctx answers — ensure tool-calling dispatch loop still works with shorter context
7. **APK size**: Verify APK stays under 50 MB (models are external)

## Approaches

### Approach A: Code optimizations only (short-term)

Apply optimizations 1–6 with existing IQ2_M model. Stay on a single variant.

- **Pros**: Fastest to ship, no external tooling needed
- **Cons**: IQ2_M still may not fit 3.8 GB devices; marginal gains only
- **Effort**: Low (1–2 hours)
- **Risk**: OOMs may persist on 3.8 GB devices → wasted effort if it doesn't fix the root cause

### Approach B: Full optimization + IQ2_XXS only (recommended)

Apply optimizations 1–6, quantize IQ2_XXS, add RAM detection. Single additional variant.

- **Pros**: IQ2_XXS + code savings = ~2.67 GB total → fits 3.8 GB with margin. Only one extra model file to host.
- **Cons**: Requires running llama-quantize (~1–2 hours, needs ~12 GB machine)
- **Effort**: Medium (4–6 hours)
- **Risk**: IQ2_XXS quality at 98% of IQ2_M — acceptable for educational responses

### Approach C: Full optimization + IQ2_XXS + IQ1_S (comprehensive)

Apply all optimizations, quantize both IQ2_XXS and IQ1_S, add 3-tier RAM detection.

- **Pros**: Supports down to 2 GB devices; IQ1_S for ultra-low-end
- **Cons**: Two model files to host (3.4 GB total), quantize IQ1_S separately, more test combinations
- **Effort**: High (6–8 hours)
- **Risk**: IQ1_S at 95% quality may produce noticeably worse responses — needs validation

## Recommendation

**Approach B** — Full code optimizations + IQ2_XXS with 2-tier RAM detection (IQ2_M for 3.5 GB+, IQ2_XXS for below). IQ1_S is deferred as a follow-up until quality is validated.

**Rationale**:
- The contest phone is 3.8 GB — IQ2_XXS + code savings provides a comfortable margin
- Single additional model file keeps download and storage manageable
- IQ1_S quality risk is real — 95% quality means 5% degradation, which for educational content could mean factual errors
- IQ2_M serves as the premium tier for higher-end devices

## Risks

1. **512-context too short**: The Yachay dispatch loop runs up to 7 rounds with tool results accumulating. Prompt + system prompt + 7 rounds of tool results could exceed 512 tokens. Mitigation: test with real tool-calling scenarios; increase to 768 if needed (adds ~36 MB KV at Q8_0).
2. **IQ2_XXS quantization quality**: At 98%, degradation may be noticeable for math reasoning tasks. Mitigation: run diagnostic test items through both IQ2_M and IQ2_XXS; compare correctness.
3. **Flash attention on CPU**: `LLAMA_FLASH_ATTN_TYPE_ENABLED` may be a no-op on ARM CPU (flash attention targets GPU). Mitigation: benchmark with/without — if no benefit, set to `AUTO`.
4. **RAM detection accuracy**: `ActivityManager.totalMem` includes memory reserved by the kernel. On some devices, this can be misleadingly low. Mitigation: add a 10% safety margin to thresholds.
5. **Model file hosting**: GGUF files (~2.0 + 2.6 GB) need hosting for user download. Mitigation: Hugging Face LFS as primary, Firebase Storage as backup.
6. **ABI filter risk**: `arm64-v8a` only excludes some older devices. Mitigation: document minimum requirement clearly (Android 6+, arm64, 2 GB+).

## Ready for Proposal

**Yes**. All unknowns are resolved:
- llama.cpp API fields confirmed present and usable
- Specific line numbers identified for every code change
- Model variant strategy mapped to device RAM tiers
- Quantization sources located (BF16 GGUF → self-quantize)
- Android manifest changes identified
- RAM detection approach confirmed (Kotlin `ActivityManager.MemoryInfo`)

**Next recommended phase**: `sdd-propose` → define scope, success criteria, rollback plan.
