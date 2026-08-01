# gemma-mobile-model Specification

> NEW: Adaptive model path resolution with RAM-aware variant selection

## Purpose

Select the optimal GGUF model variant for the device's available RAM at load time, ensuring 3.8 GB devices use IQ2_XXS (~2.0 GB) and higher-end devices use IQ2_M (~2.6 GB). Falls back to IQ2_M when the optimized variant is absent (SR-B07, NR-02).

## Requirements

### Requirement: RAM Detection

The Kotlin `GemmaEngine.kt` SHALL detect available device RAM via `ActivityManager.MemoryInfo.totalMem` before JNI model load. The detected value MUST be compared against a 3.5 GB threshold with 10% safety margin (effective: 3.15 GB).

#### Scenario: Device RAM accurately detected

- GIVEN `GemmaEngine.handleLoadModel()` is invoked
- WHEN the engine queries `ActivityManager.MemoryInfo`
- THEN `totalMem` SHALL be read and logged
- AND the value SHALL be used to select between IQ2_M and IQ2_XXS variants

#### Scenario: Zero RAM reported edge case

- GIVEN `ActivityManager.MemoryInfo` returns 0 or throws
- WHEN the engine cannot determine RAM
- THEN the system SHALL default to IQ2_M variant
- AND SHALL log a warning: "Unable to detect device RAM, defaulting to IQ2_M"

### Requirement: 2-Tier Model Selection

The model selection SHALL use 2 tiers: IQ2_M for devices with ≥3.5 GB total RAM, IQ2_XXS for devices below that threshold.

| Available RAM | Variant | Est. Total |
|---------------|---------|------------|
| ≥ 3.5 GB | IQ2_M | ~3.27 GB |
| < 3.5 GB | IQ2_XXS | ~2.67 GB |

#### Scenario: High-RAM device selects IQ2_M

- GIVEN device has 4 GB total RAM
- WHEN model variant is selected
- THEN the engine MUST select IQ2_M variant
- AND pass the IQ2_M file path to JNI `loadModel()`

#### Scenario: Low-RAM device selects IQ2_XXS

- GIVEN device has 3 GB total RAM
- WHEN model variant is selected
- THEN the engine MUST select IQ2_XXS variant
- AND inference SHALL complete without OOM

### Requirement: Variant-Aware Default Model Path

Dart `GemmaService._defaultModelPath()` SHALL resolve to the variant path passed by Kotlin via MethodChannel. If the selected variant file is absent, it MUST fall back to IQ2_M.

#### Scenario: Path resolved to selected variant

- GIVEN Kotlin selected IQ2_XXS and the file exists at the expected path
- WHEN `_defaultModelPath()` is called
- THEN it MUST return `/data/data/.../gemma-4-E2B-it-IQ2_XXS.gguf`

#### Scenario: Missing variant falls back to IQ2_M

- GIVEN Kotlin selected IQ2_XXS but the GGUF file does not exist
- WHEN `_defaultModelPath()` checks the filesystem
- THEN it MUST return the IQ2_M path
- AND SHALL log "IQ2_XXS model not found, falling back to IQ2_M"
