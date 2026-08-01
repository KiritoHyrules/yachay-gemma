# android-memory-load Specification

> NEW: MAP_POPULATE disabled, availMem-based RAM tier detection for model loading

## Purpose

Prevent native OOM kills when loading Gemma 4 GGUF models by disabling kernel page prefaulting (MAP_POPULATE) and selecting model quantizations based on available RAM (not total RAM), ensuring the app can load and infer on 4 GB devices with competing apps (SR-B02, SR-B07).

## Requirements

### Requirement: MAP_POPULATE Disabled

The vendored `llama-model.cpp` SHALL call `init_mappings(false, ...)` instead of `init_mappings(true, ...)`, disabling kernel pre-faulting of the entire model file at load time. The native engine in `gemma_engine.cpp` SHALL explicitly set `model_params.load_mode = LLAMA_LOAD_MODE_MMAP`.

#### Scenario: Model loads with demand paging on 4 GB device

- GIVEN a device with 4 GB total RAM and 1.5 GB consumed by other apps (2.5 GB available)
- WHEN `loadModelJni()` initializes the model via demand-paged mmap (MAP_POPULATE disabled)
- THEN the kernel MUST NOT pre-fault the entire GGUF file into physical memory
- AND model load SHALL complete successfully (no OOM)
- AND first inference forward pass SHALL fault in all active pages on demand

#### Scenario: MAP_POPULATE disabled does not affect correctness

- GIVEN MAP_POPULATE is disabled and the model is loaded
- WHEN inference runs on any prompt
- THEN output quality, token generation, and sampler behavior MUST be identical to MAP_POPULATE enabled
- AND the only observable difference SHALL be initial page-fault latency (<200ms)

### Requirement: availMem-Based RAM Tier Detection

`GemmaEngine.detectRamTier()` SHALL use `ActivityManager.MemoryInfo.availMem` instead of `totalMem` to determine the RAM tier. The tier threshold SHALL be reduced from 3584 MB to account for OS overhead.

#### Scenario: Device with 4 GB total but only 1.6 GB available selects low tier

- GIVEN `ActivityManager.getMemoryInfo()` reports `totalMem=4096 MB` and `availMem=1638 MB`
- WHEN `detectRamTier()` runs
- THEN `ramTier` MUST be set to `"iq2_xxs"` (not `"iq2_m"`)
- AND a warning MUST be logged noting the device could support IQ2_M if memory is freed

#### Scenario: Device with 6 GB total and 3.5 GB available selects high tier

- GIVEN `ActivityManager.getMemoryInfo()` reports `totalMem=6144 MB` and `availMem=3584 MB`
- WHEN `detectRamTier()` runs
- THEN `ramTier` MUST be set to `"iq2_m"`

#### Scenario: availMem returns 0 (edge case after boot)

- GIVEN `ActivityManager.getMemoryInfo()` reports `availMem=0`
- WHEN `detectRamTier()` runs
- THEN `ramTier` SHALL fall back to `"iq2_m"` with a warning log
- AND the fallback SHALL NOT cause OOM by selecting an inappropriate tier

#### Scenario: SecurityException on getMemoryInfo

- GIVEN `context.getSystemService()` succeeds but `getMemoryInfo()` throws `SecurityException`
- WHEN `detectRamTier()` runs
- THEN `ramTier` MUST default to `"iq2_m"` and log a warning

### Requirement: Explicit Model Loading Modes

`gemma_engine.cpp` SHALL explicitly set `model_params.load_mode = LLAMA_LOAD_MODE_MMAP` after `llama_model_default_params()`, documenting intent and making the MMAP dependency explicit.

#### Scenario: MMAP mode is set before model load

- GIVEN the JNI `loadModelJni()` is called
- WHEN model params are initialized
- THEN `load_mode` MUST be explicitly set to `LLAMA_LOAD_MODE_MMAP` before `llama_model_load_from_file()`
- AND the load_mode MUST NOT depend on default initialization behavior

### Requirement: RAM Tier Threshold Adjustment

The `RAM_THRESHOLD_MB` constant in `GemmaEngine.kt` SHALL be lowered from 3584 to account for using availMem (which is already net of OS consumption).

#### Scenario: Threshold calibrated for availMem

- GIVEN `detectRamTier()` uses `availMem`
- WHEN the threshold is compared
- THEN a 4 GB device with 2.8 GB availMem SHALL select `"iq2_m"`
- AND a 4 GB device with 1.2 GB availMem SHALL select `"iq2_xxs"`
