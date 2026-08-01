# Delta for ai-sampling

## ADDED Requirements

### Requirement: SamplingConfig Wiring to createChat

The system MUST wire all `SamplingConfig` parameters to the `createChat()` inference session. `maxTokens` MUST be forced to 256, overriding `_resolveMaxTokens()`.

#### Scenario: createChat receives sampling params

- GIVEN `GemmaService` initializes a chat session
- WHEN `createChat()` is called via `GemmaInferenceAdapter`
- THEN the session config MUST include temperature=0.4, topK=64, topP=0.85, repeatPenalty=1.1
- AND maxTokens MUST be 256 regardless of default resolution

#### Scenario: SamplingConfig defaults as fallback

- GIVEN no explicit overrides passed to `createChat()`
- WHEN the inference session runs
- THEN `SamplingConfig` defaults MUST apply

## MODIFIED Requirements

### Requirement: Conservative Sampling Configuration

The system MUST use a fixed `SamplingConfig` wired through `createChat()`:

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| temperature | 0.4 | Low creativity for educational content |
| topK | 64 | Constrain token candidates |
| topP | 0.85 | Nucleus sampling threshold |
| repeatPenalty | 1.1 | Discourage repetition |
| maxTokens | 256 | Grade-appropriate short responses (4to Primaria) |

(Previously: maxTokens was 1024; params defined but NOT wired to createChat; spec described llama.cpp MethodChannel path.)

#### Scenario: Inference uses conservative parameters

- GIVEN the model is loaded and ready
- WHEN `createChat()` is called
- THEN session config MUST pass temperature=0.4, topK=64, topP=0.85, repeatPenalty=1.1
- AND maxTokens MUST be 256

#### Scenario: Caller-provided overrides take precedence

- GIVEN a caller passes explicit `temperature` via session config
- WHEN the inference runs
- THEN caller-provided value MUST override default
- AND unspecified params MUST fall back to `SamplingConfig` defaults

## REMOVED Requirements

### Requirement: SamplingConfig Pass-Through

(Reason: flutter_gemma uses direct `createChat()` API, not Dart→Kotlin→JNI MethodChannel path.)
(Migration: Replaced by ADDED "SamplingConfig Wiring to createChat" — same params, direct engine API.)

### Requirement: Sampler Chain (C++)

(Reason: flutter_gemma runtime replaces llama.cpp JNI architecture. No C++ sampler chain exists.)
(Migration: Sampling params now flow through `LiteRtLmEngine` session config — no JNI layer.)

### Requirement: System Prompt Pass-Through

(Reason: flutter_gemma handles system prompts natively via session config, not MethodChannel.)
(Migration: System prompts configured at `createChat()` — no delta needed.)

### Requirement: Yachay System Prompt Sampling

(Reason: Sampling now applies universally at `createChat()` level — no Yachay-only path.)
(Migration: Consolidated into MODIFIED "Conservative Sampling Configuration".)
