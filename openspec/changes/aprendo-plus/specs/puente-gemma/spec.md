# puente-gemma Specification

## Purpose

MethodChannel bridge between Flutter/Dart and native Kotlin layer for on-device Gemma 4 inference via llama.cpp. Provides AI-generated explanations and reinforcement exercises with pre-authored fallback when the model is unavailable.

## Requirements

### Requirement: Dart GemmaService Interface

The system MUST expose a Dart `GemmaService` class with three async methods: `cargarModelo()` → `Future<bool>`, `generarExplicacion(String tema, String nivel)` → `Future<String>`, `generarEjerciciosRefuerzo(String tema, String errorConcepto)` → `Future<List<Map>>`.

#### Scenario: Service returns fallback when model unavailable

- GIVEN `cargarModelo()` returned false (model failed to load)
- WHEN `generarExplicacion("fracciones", "Principiante")` is called
- THEN a pre-authored explanation for fractions is returned
- AND no MethodChannel call is attempted

#### Scenario: Service delegates to native when model loaded

- GIVEN `cargarModelo()` returned true
- WHEN `generarExplicacion("ecuaciones", "Intermedio")` is called
- THEN a MethodChannel invoke is sent to `generate`
- AND the native response is returned to the caller

### Requirement: Kotlin GemmaEngine via llama.cpp

`GemmaEngine.kt` SHALL load a Gemma 4 GGUF Q4_0 model file via llama.cpp native bindings when `loadModel` is invoked over the `gemma_engine` MethodChannel. It MUST report success/failure by return value.

#### Scenario: Model loads within RAM budget

- GIVEN the device has ≥1GB RAM available
- AND the GGUF model file is present at the configured path
- WHEN `loadModel` is called via MethodChannel
- THEN the model loads and returns `true`
- AND the engine is ready for `generate` calls

#### Scenario: Model fails due to insufficient RAM

- GIVEN the device has less than 1GB RAM available
- WHEN `loadModel` is called via MethodChannel
- THEN the engine returns `false`
- AND a diagnostic log entry records the failure reason

### Requirement: Fallback Responses

The Dart `GemmaService` MUST maintain a map of pre-authored explanations and exercises for all 5 lesson topics. When the model is unavailable, each method SHALL return a relevant pre-authored response.

#### Scenario: Offline fallback serves math explanation

- GIVEN the model is unavailable and the device is offline
- WHEN `generarExplicacion("porcentajes", "Avanzado")` is called
- THEN a pre-authored explanation about percentages is returned
- AND the response is grammatically correct and pedagogically sound

### Requirement: MethodChannel Contract

The MethodChannel `gemma_engine` SHALL support three methods: `loadModel` (Map→bool), `generate` (Map→String), and `unloadModel` (void→bool). All method calls SHALL return within 30 seconds or timeout with a fallback.

#### Scenario: Generate times out returns fallback

- GIVEN the model is loaded but a `generate` call exceeds 30 seconds
- WHEN the timeout fires
- THEN the Dart service catches the timeout
- AND returns the pre-authored fallback instead

### Requirement: System Prompt Configuration

All `generate` calls MUST prepend the system prompt: "Eres un tutor de matemáticas para secundaria en Perú. Explica conceptos de manera clara, usa ejemplos del contexto peruano y mantén un tono motivador sin calificaciones negativas."

#### Scenario: System prompt guides generation

- GIVEN the model is loaded and ready
- WHEN `generate` is called with a topic prompt
- THEN the system prompt is prepended to the model input
- AND the response avoids negative language
