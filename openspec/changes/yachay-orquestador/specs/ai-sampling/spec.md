# Delta for ai-sampling

> MODIFIED capability: sampling configuration reused as-is; system prompt replaced for Yachay persona. No sampler chain changes.

## ADDED Requirements

### Requirement: Yachay System Prompt Sampling

The existing `SamplingConfig` (temperature=0.4, topK=64, topP=0.85, repeatPenalty=1.1, maxTokens=1024) SHALL apply identically when the Yachay system prompt is active. No sampling parameter changes are required — the conservative configuration already suits educational Socratic dialogue.

#### Scenario: Sampling unchanged with Yachay prompt

- GIVEN the Yachay system prompt is loaded (13 tools, Socratic persona)
- WHEN `sendWithStreaming(mensaje, systemPrompt: yachayPrompt)` is called
- THEN the sampler chain MUST initialize with `temperature=0.4`, `topK=64`, `topP=0.85`
- AND the C++ chain order MUST remain: temp → top_k → top_p → penalties → dist
- AND no new sampler parameters SHALL be introduced

## MODIFIED Requirements

### Requirement: System Prompt Pass-Through

The `systemPrompt` parameter sent via MethodChannel to `GemmaEngine.kt` SHALL accept the full Yachay system prompt (approximately 1800 tokens). The C++ `generateJni()` function SHALL prepend the system prompt as the first context message before conversation history. This replaces the previous tutor prompt while reusing the same channel structure.
(Previously: system prompt was the Peruvian math tutor prompt, approximately 1200 tokens)

#### Scenario: Yachay prompt flows through MethodChannel

- GIVEN `GemmaService` builds the Yachay system prompt with 13 tool descriptions
- WHEN `_channel.invokeMethod('generate', args)` is called with `systemPrompt: yachayPrompt`
- THEN `GemmaEngine.kt.handleGenerate()` MUST extract the full prompt
- AND `generateJni()` MUST use it as the initial context
- AND the sampler chain MUST be identical to non-Yachay mode
