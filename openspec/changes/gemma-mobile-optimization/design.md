# Design: Gemma 4 Mobile Optimization

## Technical Approach

Shrink Gemma 4 E2B's runtime memory from ~3.77 GB to ~2.71 GB on 3.8 GB devices via nine C++ parameter changes + Q8_0 KV cache quantization + IQ2_XXS model variant selection + Android manifest hardening. Two-tier RAM detection in Kotlin selects IQ2_M (≥3.5 GB) or IQ2_XXS (<3.5 GB). Quantization pipeline via llama-quantize wrappers.

## Memory Budget

```
BEFORE (IQ2_M, 2048 ctx, F16 KV)       AFTER (IQ2_XXS, 768 ctx, Q8_0 KV)
────────────────────────────────────    ────────────────────────────────────
Model weights:     2.60 GB  ████████    Model weights:     2.00 GB  ██████
KV cache (K+V):    0.57 GB  ██          KV cache (K+V):    0.11 GB  ▌
Runtime buffers:   0.50 GB  ██          Runtime buffers:   0.50 GB  ██
Backend overhead:  0.10 GB  ▌           Backend overhead:  0.10 GB  ▌
────────────────────────────────────    ────────────────────────────────────
TOTAL:             3.77 GB ⚠️ OOM       TOTAL:             2.71 GB ✓ 1.09 GB margin

KV math: layers=30, kv_heads=8, head_dim=256
  2048 * 8 * 256 * 2(K+V) * 2B(F16)  = 16.8 MB * 30 layers = 504 MB + ~70 MB overhead = 574 MB
  768  * 8 * 256 * 2(K+V) * 1B(Q8_0) = 3.15 MB * 30 layers = 94.5 MB + ~13.5 MB overhead = 108 MB
```

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| n_ctx size | 768 | 512, 1024 | 512 risks overflow in 7-round dispatch loop; 768 adds 36 MB KV vs 512 with safety margin. 1024 costs 54 MB more for marginal gain |
| KV cache type | Q8_0 | Q4_0, Q5_1, F16 | Q4_0 at 4-bit halves memory again (~54 MB) but degrades attention quality. Q8_0 is lossless-like for KV; llama.cpp tests show negligible perplexity impact |
| RAM tiers | 2-tier (IQ2_M / IQ2_XXS) | 3-tier (+IQ1_S) | IQ1_S quality (95%) risks factual errors for educational content. Deferred until validated |
| RAM API | ActivityManager.MemoryInfo.totalMem | /proc/meminfo | totalMem is stable Android API since API 1; /proc/meminfo varies across kernels/ROMs |
| Flash attention | ENABLED (1) | AUTO (-1), DISABLED (0) | Explicit opt-in ensures llama.cpp uses it if available; AUTO may silently disable. No-op on ARM CPU — safe fallback |
| largeHeap | true | Rely on OS defaults | Signals OS to allocate larger JVM heap for JNI reference arrays. Zero cost, safety benefit |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `android/app/src/main/cpp/gemma_engine.cpp` | Modify | 6 parameter changes + 3 new fields. Lines 40, 109-113, 193, 341 |
| `android/app/src/main/kotlin/.../GemmaEngine.kt` | Modify | New `detectRamTier()`, `getRamTier` MethodChannel handler, variant path override in `handleLoadModel` |
| `lib/modules/gemma/gemma_service.dart` | Modify | `_defaultModelPath()`: async resolution via Kotlin tier; IQ2_XXS fallback to IQ2_M |
| `android/app/src/main/AndroidManifest.xml` | Modify | `largeHeap="true"` on `<application>`, `<uses-feature android:name="android.hardware.ram">` |
| `scripts/quantize_model.py` | Create | BF16→IQ2_XXS pipeline: argparse, input validation, llama-quantize exec, SHA256 output |

## gemma_engine.cpp Changes (line-by-line)

```diff
- Line 40:  int n_ctx = 2048;
+ Line 40:  int n_ctx = 768;

- Line 110: ctx_params.n_batch  = 512;
+ Line 110: ctx_params.n_batch  = 256;

- Line 111: ctx_params.n_ubatch = 512;
+ Line 111: ctx_params.n_ubatch = 256;

- Line 112: ctx_params.n_threads       = 2;
+ Line 112: ctx_params.n_threads       = 1;

- Line 113: ctx_params.n_threads_batch = 2;
+ Line 113: ctx_params.n_threads_batch = 1;
+ Line 114: ctx_params.type_k          = GGML_TYPE_Q8_0;
+ Line 115: ctx_params.type_v          = GGML_TYPE_Q8_0;
+ Line 116: ctx_params.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED;

- Line 193: 4096, repeat_penalty, ...
+ Line 196: 768, repeat_penalty, ...

- Line 341: 4096, repeat_penalty, ...
+ Line 344: 768, repeat_penalty, ...
```

Sampler chain preserved: temp → topK → topP → penalties → dist (5 samplers). Only `n_ctx` parameter changes.

## KV Cache Compression

llama.h API (verified lines 363, 378-379):
```c
enum llama_flash_attn_type flash_attn_type; // line 363 — AUTO=-1, DISABLED=0, ENABLED=1
enum ggml_type type_k;                     // line 378 — Q8_0=8 halves K cache vs F16=1
enum ggml_type type_v;                     // line 379 — Q8_0=8 halves V cache vs F16=1
```

GGML type enum (ggml.h lines 391-398): `GGML_TYPE_F16=1`, `GGML_TYPE_Q4_0=2`, `GGML_TYPE_Q8_0=8`.

## RAM Detection (Kotlin)

```kotlin
// In GemmaEngine.register():
private var ramTier: String = "iq2_m" // default safe

private fun detectRamTier() {
    val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    val memInfo = ActivityManager.MemoryInfo()
    actManager.getMemoryInfo(memInfo)
    val totalMemMB = memInfo.totalMem / (1024 * 1024)
    ramTier = if (totalMemMB >= 3584) "iq2_m" else "iq2_xxs" // 3.5 GB threshold
    Log.i(TAG, "RAM: ${totalMemMB}MB → tier: $ramTier")
}
```

Threshold: 3.5 GB. Error handling: catch SecurityException, log warning, default to "iq2_m".

## Adaptive Model Path (Dart)

```dart
String _modelBaseDir() => '/data/data/com.aprendoplus.app/files';

Future<String> _defaultModelPath() async {
  final tier = await _getRamTier(); // MethodChannel "getRamTier" → Kotlin
  if (tier == 'iq2_xxs') {
    final path = '${_modelBaseDir()}/gemma-4-E2B-it-IQ2_XXS.gguf';
    if (await File(path).exists()) return path;
    debugPrint('GemmaService: IQ2_XXS not found → IQ2_M fallback');
  }
  return '${_modelBaseDir()}/google_gemma-4-E2B-it-IQ2_M.gguf';
}
```

`_getRamTier()` calls MethodChannel "getRamTier" (cached on first call). Dev mode (`devMode=true`) uses server URL, skipping file paths.

## Android Manifest Changes

```diff
- Line 8:   android:label="Aprendo+"
+ Line 8:   android:label="Aprendo+"
+           android:largeHeap="true"
+           android:hardwareAccelerated="false"

+ <!-- After INTERNET permission -->
+ <uses-feature android:name="android.hardware.ram" android:required="false"/>
```

`hardwareAccelerated="false"` frees GPU memory for native inference; Flutter uses Skia software rendering. `largeHeap` signals OS to increase ART heap limit.

## Quantization Pipeline

`scripts/quantize_model.py`: argparse CLI — `--input`, `--output`, `--quant` (default: IQ2_XXS).
1. Validate BF16 input exists and is >= 8 GB (heuristic)
2. Locate `llama-quantize` at `android/app/src/main/cpp/llama.cpp/build/bin/llama-quantize`
3. Execute: `llama-quantize <input> <output> IQ2_XXS`
4. SHA256 hash output for distribution integrity
5. Exit 0 on success, non-zero with message on failure

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit (Dart) | `_defaultModelPath()` variant resolution | Mock MethodChannel: IQ2_M tier, IQ2_XXS tier, file-missing fallback |
| Unit (Kotlin) | `detectRamTier()` thresholds | Mock `ActivityManager.MemoryInfo` with 2/3/4/6 GB values |
| Integration | Build succeeds | `flutter build apk --debug` |
| E2E | 7-round dispatch on real 3.8 GB device | IQ2_XXS model, Yachay prompt, verify no OOM |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. The quantization script is offline developer tooling.

## Migration / Rollout

No migration required. All changes are additive: `_defaultModelPath()` falls back to IQ2_M when IQ2_XXS absent. `largeHeap` has no behavioral impact on its own. Rollback: revert commit.
