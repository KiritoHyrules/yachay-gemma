# ai-streaming Specification

> NEW capability: token-level streaming bridge from native C++ to Dart via MethodChannel

## Purpose

Deliver generated tokens incrementally to the Flutter UI, with performance metrics and UI throttling, enabling responsive tutor interactions (N-01, N-04).

## Requirements

### Requirement: Streaming MethodChannel Bridge

The system MUST provide a `generateStream` MethodChannel method that delivers tokens one at a time from the native layer to Dart via an event sink.

#### Scenario: Streaming with event sink

- GIVEN the model is loaded
- WHEN `GemmaEngine.kt` receives a `generateStream` call with `prompt` and sampling params
- THEN the native layer MUST emit each token via `EventChannel` or `Result.success(token)` in a streaming loop
- AND the Dart side MUST receive tokens as they are generated (not after completion)

### Requirement: Streaming API Contract

`GemmaService` SHALL expose `sendWithStreaming(String prompt, {Function(String) onToken, Function(MessageStats) onComplete})` as the primary streaming entry point.

#### Scenario: Happy path streaming call

- GIVEN a user asks "explícame fracciones"
- WHEN `sendWithStreaming` is called with `onToken` and `onComplete` callbacks
- THEN `onToken` MUST be invoked for each generated token
- AND `onComplete` MUST be invoked once with a `MessageStats` object after generation finishes
- AND the final response text SHALL be the concatenation of all tokens

#### Scenario: Streaming fails gracefully

- GIVEN the model is not loaded
- WHEN `sendWithStreaming` is called
- THEN the system MUST fall back to the 4-layer fallback dispatcher
- AND `onComplete` MUST be invoked with a stats object where `tokenCount=0`

### Requirement: Token Throttling

The Dart streaming handler SHALL throttle UI updates to every 3 tokens to prevent jank on low-RAM devices.

#### Scenario: UI throttle at 3-token intervals

- GIVEN tokens arrive at full speed from native layer
- WHEN the 1st, 2nd tokens arrive
- THEN `onToken` MUST NOT be called
- WHEN the 3rd token arrives
- THEN `onToken` MUST be called with the accumulated 3-token batch
- AND subsequent batches MUST follow the same 3-token pattern

### Requirement: MessageStats Metrics

Every streaming completion MUST return a `MessageStats` object with: `timeToFirstToken` (seconds), `totalLatency` (seconds), `tokenCount` (int), `decodeSpeed` (tokens/sec after first token).

#### Scenario: Accurate performance metrics

- GIVEN a streaming generation of 150 tokens
- WHEN generation completes
- THEN `timeToFirstToken` MUST be < 3.0 on a 2GB RAM reference device
- AND `decodeSpeed` MUST be > 1.0 tokens/sec
- AND `totalLatency` SHALL equal elapsed wall-clock time
