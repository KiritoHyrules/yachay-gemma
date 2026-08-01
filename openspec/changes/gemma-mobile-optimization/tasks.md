# Tasks: Gemma 4 Mobile Optimization

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~290 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | All 4 phases — native params, adaptive path, quantization script, integration tests | Single PR | `flutter test` | `flutter build apk --debug` | `git revert` — all changes contained in one commit |

## Phase 1: Native Engine Parameters

- [x] 1.1 [CPP] Set `n_ctx=768` in `GemmaState` struct (line 40) and `ctx_params.n_ctx` (line 109), replacing hardware 2048
- [x] 1.2 [CPP] Reduce `n_batch`/`n_ubatch` from 512 to 256 and `n_threads`/`n_threads_batch` from 2 to 1 (lines 110–113)
- [x] 1.3 [CPP] Add `type_k=GGML_TYPE_Q8_0`, `type_v=GGML_TYPE_Q8_0`, `flash_attn_type=LLAMA_FLASH_ATTN_TYPE_ENABLED` to `ctx_params` after line 113
- [x] 1.4 [CPP] Fix sampler `n_ctx` from hardcoded 4096 to 768 at `generateJni` (line 193) and `generateStreamJni` (line 341)

## Phase 2: RAM Detection + Adaptive Model Path

- [x] 2.1 [TEST] [RED] Write Dart unit test for `_defaultModelPath()`: mock MethodChannel `getRamTier` returning `"iq2_m"` → IQ2_M path; `"iq2_xxs"` + file exists → IQ2_XXS path; `"iq2_xxs"` + file missing → IQ2_M fallback with log
- [x] 2.2 [DART] [GREEN] Make `_defaultModelPath()` async — add `_getRamTier()` calling MethodChannel, resolve variant path via `_modelBaseDir()`, check `File.exists()` for IQ2_XXS, fallback to IQ2_M with `debugPrint`
- [x] 2.3 [KT] Implement `detectRamTier()` in `GemmaEngine.kt`: query `ActivityManager.MemoryInfo.totalMem`, 3.5 GB → `"iq2_m"`, <3.5 GB → `"iq2_xxs"`; catch `SecurityException` → log + default to `"iq2_m"`
- [x] 2.4 [KT] Add `"getRamTier"` MethodChannel handler in `onMethodCall`: return `ramTier` string; call `detectRamTier()` in `register()` before registering channel
- [x] 2.5 [KT] Override model path in `handleLoadModel()`: prepend variant segment to the path passed to `loadModelJni()` when call does not specify `modelPath` argument
- [x] 2.6 [MANIFEST] Add to `<application>`: `android:largeHeap="true"`, `android:hardwareAccelerated="false"`; add `<uses-feature android:name="android.hardware.ram" android:required="false"/>` after INTERNET permission

## Phase 3: Quantization Pipeline

- [x] 3.1 [SCRIPT] Create `scripts/quantize_model.py`: argparse `--input` (BF16 GGUF), `--output` (IQ2_XXS GGUF), `--quant` (default `IQ2_XXS`); validate input exists and is ≥8 GB heuristic; locate `llama-quantize` at vendored build path; fail with clear errors on missing input or binary
- [x] 3.2 [SCRIPT] Execute `llama-quantize <input> <output> IQ2_XXS` via `subprocess.run`; compute SHA256 of output file; print `sha256: <hex>` to stdout; exit 0 on success or non-zero with message

## Phase 4: Integration Testing

- [x] 4.1 [TEST] Kotlin unit tests for `detectRamTier()`: mock `MemoryInfo.totalMem` at 2 GB → `"iq2_xxs"`, 3 GB → `"iq2_xxs"`, 4 GB → `"iq2_m"`, 6 GB → `"iq2_m"`; zero-value → `"iq2_m"` default; SecurityException → `"iq2_m"` default
- [x] 4.2 [TEST] Run `flutter build apk --debug`; verify successful APK generation with native .so linking and no missing symbols from optimized params
- [x] 4.3 [TEST] E2E on 3.8 GB device: push IQ2_XXS model via adb; load model → verify no OOM; run Yachay 7-round dispatch prompt; verify coherent Spanish response within 30s
