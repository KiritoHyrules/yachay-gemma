# Delta for ai-fallback

> MODIFIED capability: replaces single-layer JSON fallback with 4-layer deterministic dispatch

## Purpose

Guarantee pedagogically sound responses at every failure point, independent of model availability (N-01, N-03, N-04).

## MODIFIED Requirements

### Requirement: 4-Layer Fallback System

The fallback dispatcher SHALL evaluate 4 layers in order, short-circuiting at the first match:
(Previously: single-layer `topicId → level → {explicacion, ejercicios}` JSON lookup)

| Layer | Trigger | Response |
|-------|---------|----------|
| 1 | Trivial greeting regex match | Instant Spanish encouragement, no model |
| 2 | Keyword→tool mapping match | Execute tool with bundled data |
| 3 | Tool execution (deterministic) | Run handler locally with pre-authored content |
| 4 | No match | Generic encouragement in Peruvian Spanish |

#### Scenario: Greeting short-circuits all layers

- GIVEN user types "hola" or "buenos días"
- WHEN the fallback dispatcher evaluates layer 1
- THEN it MUST match the trivial greeting regex
- AND return "¡Hola! Soy Aprendo+, tu tutor de matemática. ¿En qué tema necesitas ayuda hoy?"
- AND layers 2-4 MUST NOT be evaluated

#### Scenario: Keyword routes to tool

- GIVEN user types "quiero practicar ejercicios de álgebra" and model is unavailable
- WHEN layer 2 evaluates
- THEN keyword "ejercicios" MUST match → `generar_ejercicios` tool
- AND layer 3 MUST execute the tool with `{tema: "algebra", nivel: "1"}`
- AND response MUST contain bundled exercises from `fallback_responses.json`

#### Scenario: Unmatched query reaches layer 4

- GIVEN user types "no sé qué estudiar" with no keyword match
- WHEN layers 1-3 all fail
- THEN layer 4 MUST return a generic Peruvian-Spanish encouragement
- AND the response SHALL reference available lessons: "Podemos empezar con fracciones, ecuaciones o comprensión lectora. ¿Cuál prefieres?"

### Requirement: Emergency Fallback at All Failure Points

Every error path in `GemmaService` (timeout, OOM, PlatformException, empty response, malformed XML) SHALL route through the 4-layer fallback instead of returning empty or generic placeholders.

#### Scenario: Inference timeout triggers fallback

- GIVEN `procesarMensaje("explícame fracciones")` is running
- WHEN the 30-second inference timeout fires
- THEN the system MUST catch `TimeoutException`
- AND route the original message through `FallbackDispatcher.dispatch("explícame fracciones")`
- AND return the layer 2 deterministic response for "fracciones" → `explicar_tema`
