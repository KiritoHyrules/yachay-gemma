# ai-sampling Specification

> Conservative sampling configuration for llama.cpp sampler chain — reused for Yachay Socratic persona

## Purpose

Configure llama.cpp sampler chain with conservative parameters for safe, predictable educational output (N-01, N-03). Reused as-is for Yachay system prompt.

## Requirements

### Requirement: Conservative Sampling Configuration

The system MUST use a fixed `SamplingConfig` with the following parameters for all inference calls:

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `temperature` | 0.4 | Low creativity for factual educational content |
| `topK` | 64 | Constrain token pool to reasonable candidates |
| `topP` | 0.85 | Nucleus sampling threshold (was none) |
| `repeat_penalty` | 1.1 | Discourage repetitive output |
| `maxTokens` | 1024 | Sufficient for tool-calling + follow-up explanations |

#### Scenario: Inference uses conservative parameters

- GIVEN the model is loaded and ready
- WHEN any generation request is made via `generate` MethodChannel
- THEN the C++ sampler chain MUST include `llama_sampler_init_temp(0.4)`, `llama_sampler_init_top_k(64)`, `llama_sampler_init_top_p(0.85)`, and `llama_sampler_init_penalties(n_ctx, 1.1, …)`
- AND maxTokens MUST default to 1024 if not overridden

#### Scenario: Backward-compatible parameter override

- GIVEN a caller passes explicit `temperature` or `maxTokens` via MethodChannel
- WHEN the inference runs
- THEN caller-provided values MUST override the defaults
- AND unspecified parameters MUST fall back to `SamplingConfig` defaults

### Requirement: SamplingConfig Pass-Through

The system SHALL pass `topK`, `topP`, and `repeatPenalty` through the MethodChannel from Dart to Kotlin to JNI C++.

#### Scenario: Dart-to-native parameter flow

- GIVEN `GemmaService` calls `_channel.invokeMethod('generate', args)`
- WHEN args include `topK: 64`, `topP: 0.85`, `repeatPenalty: 1.1`
- THEN `GemmaEngine.kt.handleGenerate()` MUST extract these arguments
- AND `generateJni()` JNI signature MUST accept them
- AND `gemma_engine.cpp` MUST add corresponding samplers to the chain

### Requirement: Sampler Chain (C++)

The llama.cpp sampler chain in `gemma_engine.cpp` SHALL be extended from 2 samplers (temp + dist) to 5 samplers: temp, top_k, top_p, penalties, dist — in that order per llama.cpp best practices.

#### Scenario: Complete sampler chain initialization

- GIVEN a generation request with `temperature=0.4`, `topK=64`, `topP=0.85`, `repeatPenalty=1.1`
- WHEN the sampler chain is built in `gemma_engine.cpp`
- THEN the chain MUST contain exactly: `init_temp(0.4)` → `init_top_k(64)` → `init_top_p(0.85)` → `init_penalties(n_ctx, 1.1, …)` → `init_dist(42)`
- AND `llama_sampler_free()` MUST be called after generation completes

### Requirement: System Prompt Pass-Through

The `systemPrompt` parameter sent via MethodChannel to `GemmaEngine.kt` SHALL accept the full Yachay system prompt (approximately 1800 tokens). The C++ `generateJni()` function SHALL prepend the system prompt as the first context message before conversation history. This replaces the previous tutor prompt while reusing the same channel structure.

#### Scenario: Yachay prompt flows through MethodChannel

- GIVEN `GemmaService` builds the Yachay system prompt with 13 tool descriptions
- WHEN `_channel.invokeMethod('generate', args)` is called with `systemPrompt: yachayPrompt`
- THEN `GemmaEngine.kt.handleGenerate()` MUST extract the full prompt
- AND `generateJni()` MUST use it as the initial context
- AND the sampler chain MUST be identical to non-Yachay mode

### Requirement: Yachay System Prompt Sampling

The existing `SamplingConfig` (temperature=0.4, topK=64, topP=0.85, repeatPenalty=1.1, maxTokens=1024) SHALL apply identically when the Yachay system prompt is active. No sampling parameter changes are required — the conservative configuration already suits educational Socratic dialogue.

#### Scenario: Sampling unchanged with Yachay prompt

- GIVEN the Yachay system prompt is loaded (13 tools, Socratic persona)
- WHEN `sendWithStreaming(mensaje, systemPrompt: yachayPrompt)` is called
- THEN the sampler chain MUST initialize with `temperature=0.4`, `topK=64`, `topP=0.85`
- AND the C++ chain order MUST remain: temp → top_k → top_p → penalties → dist
- AND no new sampler parameters SHALL be introduced
