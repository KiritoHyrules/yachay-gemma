# gemma-engine-plugin Specification

## Purpose

Defines the FlutterGemmaPlugin integration replacing the legacy MethodChannel/Kotlin/JNI/llama.cpp engine. Covers initialization, streaming inference, native tool calling, and fallback dispatch.

## Requirements

### Requirement: Plugin Initialization and Model Loading

The system MUST initialize FlutterGemmaPlugin via singleton and load a Gemma model into an InferenceChat session with configured sampling parameters.

#### Scenario: Model loaded and chat session created

- GIVEN flutter_gemma plugin is available
- WHEN createModel(backend, modelType, maxTokens) is called
- THEN InferenceModel instance is created
- AND createChat(temperature, topK, topP) produces an active InferenceChat

#### Scenario: Duplicate initialization is idempotent

- GIVEN model and chat are already initialized
- WHEN init() is called again
- THEN the call returns immediately without re-creating resources

### Requirement: Streaming Token Delivery

The system MUST deliver inference tokens via native Stream<ModelResponse> to an onToken callback, with per-call MessageStats on completion.

#### Scenario: Tokens stream via onToken callback

- GIVEN an active InferenceChat session
- WHEN sendWithStreaming(text, onToken, onComplete) is called
- THEN tokens arrive via generateChatResponseAsync() as TextResponse objects
- AND each TextResponse.token is forwarded to onToken
- AND onComplete receives MessageStats (TTFT, totalLatency, tokenCount)

#### Scenario: App-level timeout guard

- GIVEN streaming inference is in progress
- WHEN 30 seconds elapse without completion
- THEN the stream is terminated and onComplete receives partial stats

### Requirement: Native Tool Calling

The system SHALL expose the 13-tool registry as flutter_gemma Tool objects with supportsFunctionCalls enabled.

#### Scenario: Tool execution via FunctionCallResponse

- GIVEN an active chat with supportsFunctionCalls: true
- AND tool registry contains explicar_tema, generar_ejercicios, ejecutar_diagnostico, and 10 yachay tools
- WHEN an inference response yields a FunctionCallResponse
- THEN the matching tool handler executes with parsed parameters
- AND the result is fed back to the model as a follow-up message

### Requirement: Fallback to Emergency Dispatcher

The system MUST route inference requests to FallbackDispatcher when the model is not loaded or initialization fails.

#### Scenario: Model not loaded — fallback used

- GIVEN model initialization failed or was never called
- WHEN any inference method (procesarMensaje, generarExplicacion, sendWithStreaming) is invoked
- THEN FallbackDispatcher is consulted through its 4-layer pipeline
- AND the caller receives a non-empty response in Peruvian Spanish
- AND no exception propagates to the UI

### Requirement: Feature Gate for Rollback

The system SHALL provide a static boolean flag that routes to legacy MethodChannel engine when disabled.

#### Scenario: Gate routes to legacy path

- GIVEN useFlutterGemma is set to false
- WHEN any inference method is called
- THEN the call is dispatched to the preserved MethodChannel engine
- AND the caller receives responses indistinguishable from pre-migration behavior
