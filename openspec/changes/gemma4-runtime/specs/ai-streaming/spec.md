# Delta for ai-streaming

> Cambio: migrar streaming a `flutter_gemma` 1.4.2 — `getResponseAsync()` (`Stream<String>`), `createChat` con `systemInstruction`, `maxOutputTokens` y `toolChoice`. Elimina el bridge MethodChannel legacy.

## REMOVED Requirements

### Requirement: Streaming MethodChannel Bridge

(Reason: el canal MethodChannel `generateStream`/`gemma_engine_stream` legacy se elimina; el plugin 1.4.2 entrega tokens por `Stream<String>` nativo)
(Migration: `getResponseAsync()` reemplaza `generateStream`; eliminar los tests de `streaming_test.dart` basados en el canal legacy)

## MODIFIED Requirements

### Requirement: REQ-01 — Streaming API Contract

`GemmaService` SHALL exponer streaming vía `getResponseAsync()` de `flutter_gemma` 1.4.2, que devuelve `Stream<String>` con los tokens generados. Se conserva un wrapper `sendWithStreaming(String prompt, {onToken, onComplete})` que consume el stream y emite `MessageStats` al completar. Un timeout de 30 s MUST cortar el stream con stats parciales.
(Previously: streaming vía `generateChatResponseAsync()` de 0.10.x con callbacks directos)

#### Scenario: Happy path streaming call

- GIVEN el estudiante pregunta "explícame fracciones"
- WHEN `sendWithStreaming` se llama con callbacks `onToken` y `onComplete`
- THEN `getResponseAsync()` emite tokens como `Stream<String>`
- AND `onToken` MUST invocarse por cada lote de tokens (con throttle de UI)
- AND `onComplete` MUST invocarse una vez con un `MessageStats` al finalizar
- AND el texto final SHALL ser la concatenación de todos los tokens

#### Scenario: Streaming fails gracefully (modo degradado)

- GIVEN el modelo no está cargado
- WHEN `sendWithStreaming` se llama
- THEN el sistema MUST caer al modo degradado sin IA (`FallbackDispatcher`)
- AND `onComplete` MUST invocarse con un stats donde `tokenCount=0`

#### Scenario: Timeout de 30 segundos

- GIVEN la generación no termina en 30 s
- WHEN el timeout dispara
- THEN el stream se corta
- AND `onComplete` recibe stats parciales sin crashear

## ADDED Requirements

### Requirement: REQ-02 — Configuración de sesión de chat 1.4.2

`createChat` MUST configurarse con: `systemInstruction` con el prompt Yachay (tutor socrático, español peruano), `maxOutputTokens` (>= 1024) acotando la longitud de respuesta, y `toolChoice` habilitando tool calling nativo.

#### Scenario: Prompt socrático en español peruano

- GIVEN la sesión se crea con `systemInstruction` del prompt Yachay
- WHEN el estudiante pide "¿cuánto es 3/4 + 1/2?"
- THEN la respuesta MUST guiar con preguntas (no dar la respuesta directa)
- AND el tono MUST ser español peruano cálido

#### Scenario: maxOutputTokens acota la respuesta

- GIVEN `maxOutputTokens` = 1024
- WHEN la generación alcanza el límite
- THEN el stream termina en el límite
- AND `tokenCount` del `MessageStats` no excede el máximo configurado

#### Scenario: toolChoice habilita function calling

- GIVEN `toolChoice` configurado y tools registradas
- WHEN el modelo decide invocar una tool
- THEN la respuesta contiene un `FunctionCallResponse` procesable por el dispatcher
