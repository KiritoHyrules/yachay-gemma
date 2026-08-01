# android-memory-kvcache Specification

> NEW: Adaptive KV cache precision with 3-tier RAM thresholding and system memory pressure response

## Purpose

Reduce KV cache memory footprint on low-RAM devices by selecting cache precision (Q4_0, Q8_0, or F16) based on available RAM, and react to Android system memory pressure signals to prevent OS-initiated process kills (SR-B02, NR-02).

## Requirements

### Requirement: 3-Tier Adaptive KV Cache

The native engine SHALL conditionally set `type_k` and `type_v` based on a `ramTier` string passed from Kotlin via JNI. Three tiers SHALL be defined: low (Q4_0), medium (Q8_0), and high (F16).

| Tier | availMem | KV Cache Type | Approx. KV Memory (768 ctx) |
|------|----------|---------------|-----------------------------|
| low | < 1.8 GB | Q4_0 | ~47 MB |
| medium | 1.8–3 GB | Q8_0 | ~94 MB |
| high | > 3 GB | F16 | ~187 MB |

#### Scenario: Low-RAM device selects Q4_0 KV cache

- GIVEN `availMem < 1800 MB` and `ramTier = "iq2_xxs"` or equivalent
- WHEN `loadModelJni(path, ramTier)` is called
- THEN `ctx_params.type_k` MUST be set to `GGML_TYPE_Q4_0`
- AND `ctx_params.type_v` MUST be set to `GGML_TYPE_Q4_0`
- AND model context initialization SHALL complete within the available memory budget

#### Scenario: Medium-RAM device selects Q8_0 KV cache

- GIVEN `availMem` between 1.8 GB and 3 GB
- WHEN `loadModelJni(path, ramTier)` is called
- THEN `ctx_params.type_k` MUST be set to `GGML_TYPE_Q8_0`
- AND `ctx_params.type_v` MUST be set to `GGML_TYPE_Q8_0`

#### Scenario: High-RAM device selects F16 KV cache

- GIVEN `availMem > 3 GB`
- WHEN `loadModelJni(path, ramTier)` is called
- THEN `ctx_params.type_k` MUST be set to `GGML_TYPE_F16`
- AND `ctx_params.type_v` MUST be set to `GGML_TYPE_F16`

#### Scenario: Unknown ramTier defaults to Q8_0

- GIVEN `ramTier` string is unrecognized or empty
- WHEN `loadModelJni` parses the tier
- THEN KV cache types MUST default to `GGML_TYPE_Q8_0` (current behavior)
- AND a warning SHALL be logged

### Requirement: JNI Signature Change for ramTier

`loadModelJni` SHALL accept a second parameter: `jstring jramTier`. The Kotlin `external fun` declaration, the C++ JNI function, and the Kotlin call site SHALL all be updated.

#### Scenario: Kotlin passes ramTier to JNI

- GIVEN `detectRamTier()` has determined the tier
- WHEN `handleLoadModel()` invokes `loadModelJni(path, ramTier)`
- THEN the ramTier string MUST be passed to the native layer
- AND the native layer SHALL parse the string to select KV cache types

### Requirement: onTrimMemory Pressure Response

`GemmaEngine` SHALL implement `ComponentCallbacks2` and register with the Android context. On `TRIM_MEMORY_RUNNING_CRITICAL`, the engine SHALL signal to the native layer to reduce batch size and flush caches.

#### Scenario: System signals critical memory pressure

- GIVEN the app is running with the model loaded
- WHEN Android calls `onTrimMemory(TRIM_MEMORY_RUNNING_CRITICAL)`
- THEN `n_batch` in the native context SHALL be reduced to 64 for subsequent decode calls
- AND current KV cache SHALL be preserved (no forced unload)

#### Scenario: System signals moderate memory pressure

- GIVEN the app is running with the model loaded
- WHEN Android calls `onTrimMemory(TRIM_MEMORY_RUNNING_MODERATE)`
- THEN non-critical cached token buffers SHALL be flushed
- AND the model MUST remain loaded and ready for inference

#### Scenario: App goes to background

- GIVEN the model is loaded
- WHEN Android calls `onTrimMemory(TRIM_MEMORY_UI_HIDDEN)`
- THEN the event SHALL be logged
- AND no forced model unload SHALL occur (student may return quickly)

#### Scenario: onLowMemory callback

- GIVEN the model is loaded
- WHEN Android calls `onLowMemory()`
- THEN all caches SHALL be flushed
- AND a warning SHALL be logged
- AND the model SHALL remain loaded

#### Scenario: ComponentCallbacks2 is unregistered on dispose

- GIVEN `GemmaEngine` has been registered as a `ComponentCallbacks2`
- WHEN the engine is disposed or unloaded
- THEN `context.unregisterComponentCallbacks(this)` MUST be called
- AND no memory leak from dangling callback registration SHALL occur
