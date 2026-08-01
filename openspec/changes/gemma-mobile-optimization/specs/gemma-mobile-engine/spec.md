# gemma-mobile-engine Specification

> NEW: Optimized native context parameters for low-RAM Android devices

## Purpose

Reduce Gemma 4 E2B memory footprint from ~3.77 GB to ~2.71 GB on 3.8 GB target devices, preventing native OOM kills and preserving live AI inference as the primary path (SR-B02, SR-B07).

## Requirements

### Requirement: Context Window Reduction

The native engine SHALL configure `n_ctx=768` in `llama_context_params`. The existing hardcoded `n_ctx=2048` MUST be replaced.

| Parameter | Current | New |
|-----------|---------|-----|
| `n_ctx` | 2048 | 768 |

#### Scenario: Model loads with reduced context window

- GIVEN a device with 3.8 GB total RAM
- WHEN `llama_init_from_model()` initializes with `n_ctx=768`
- THEN the KV cache allocation MUST NOT exceed 108 MB (Q8_0 at 768 ctx)
- AND model loading SHALL complete without native OOM

### Requirement: KV Cache Quantization

The native engine SHALL set `type_k=GGML_TYPE_Q8_0` and `type_v=GGML_TYPE_Q8_0` in `llama_context_params`, replacing the default F16.

| Parameter | Current | New |
|-----------|---------|-----|
| `type_k` | F16 (default) | Q8_0 |
| `type_v` | F16 (default) | Q8_0 |

#### Scenario: KV cache uses half memory

- GIVEN `n_ctx=768` and Q8_0 KV cache type
- WHEN the context is fully populated with 768 tokens
- THEN KV cache memory usage SHALL be ≤108 MB
- AND the cache was 574 MB at 2048 ctx F16 (previously)

### Requirement: Flash Attention

The native engine SHALL set `flash_attn_type=LLAMA_FLASH_ATTN_TYPE_ENABLED` in `llama_context_params`.

#### Scenario: Flash attention enabled at init

- GIVEN the llama.cpp build supports flash attention
- WHEN `llama_init_from_model()` is called
- THEN `flash_attn_type` MUST be explicitly set to ENABLED (1)
- AND on ARM CPU this MAY be a no-op; inference SHALL still complete

### Requirement: Thread and Batch Reduction

Threads SHALL be reduced from 2 to 1 for both `n_threads` and `n_threads_batch`. Batch size SHALL be reduced from 512 to 256.

| Parameter | Current | New |
|-----------|---------|-----|
| `n_threads` | 2 | 1 |
| `n_threads_batch` | 2 | 1 |
| `n_batch` | 512 | 256 |
| `n_ubatch` | 512 | 256 |

#### Scenario: Single-threaded inference saves memory

- GIVEN the optimized engine configuration
- WHEN a prompt is submitted for generation
- THEN only 1 thread SHALL be used for inference
- AND batch processing SHALL use max 256 tokens per physical batch
- AND memory pressure from thread stacks and batch buffers SHALL be reduced

### Requirement: Sampler Context Fix

The sampler's hardcoded `n_ctx=4096` in `gemma_engine.cpp` (lines 193, 341) SHALL be corrected to `n_ctx=768`, matching the actual context size.

#### Scenario: Sampler context matches model context

- GIVEN the model is loaded with `n_ctx=768`
- WHEN `gpt_sampler_init()` is called
- THEN its `n_ctx` parameter MUST be 768 (not 4096)
- AND sampling operations SHALL use the correct context size
