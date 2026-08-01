# ai-fallback Specification

> 4-layer deterministic fallback dispatch — extended with Yachay curriculum-aware keyword routing

## Purpose

Guarantee pedagogically sound responses at every failure point, independent of model availability (N-01, N-03, N-04). Extended for Yachay with curriculum keywords and Socratic persona in layer 4.

## Requirements

### Requirement: 4-Layer Fallback System

The fallback dispatcher SHALL evaluate 4 layers in order, short-circuiting at the first match. Layer 2 keyword mapping SHALL be extended with 4 Yachay-specific keyword patterns. Layer 3 tool execution SHALL include all 13 tools from the extended registry. Layer 4 generic responses SHALL reference Yachay persona ("Yachay está teniendo dificultades para responder. ¿Podrías intentar preguntar de otra forma?").

| Layer | Trigger | Response |
|-------|---------|----------|
| 1 | Trivial greeting regex match | Instant Spanish encouragement, no model |
| 2 | Keyword→tool mapping match | Execute tool with bundled data (incl. Yachay curriculum keywords) |
| 3 | Tool execution (deterministic) | Run handler locally with pre-authored content (13 tools) |
| 4 | No match | Generic Yachay encouragement in Peruvian Spanish |

#### Scenario: Greeting short-circuits all layers

- GIVEN user types "hola" or "buenos días"
- WHEN the fallback dispatcher evaluates layer 1
- THEN it MUST match the trivial greeting regex
- AND return "¡Hola! Soy Yachay, tu tutor de aritmética. ¿Qué querés aprender hoy?"
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
- THEN layer 4 MUST return "Yachay está teniendo dificultades para responder. ¿Podrías intentar preguntar de otra forma?"
- AND the message MUST reference available context chips: "Probá con 'Explicar', 'Practicar' o 'Mi progreso'"

### Requirement: Emergency Fallback at All Failure Points

Every error path in `GemmaService` (timeout, OOM, PlatformException, empty response, malformed XML) SHALL route through the 4-layer fallback instead of returning empty or generic placeholders.

#### Scenario: Inference timeout triggers fallback

- GIVEN `procesarMensaje("explícame fracciones")` is running
- WHEN the 30-second inference timeout fires
- THEN the system MUST catch `TimeoutException`
- AND route the original message through `FallbackDispatcher.dispatch("explícame fracciones")`
- AND return the layer 2 deterministic response for "fracciones" → `explicar_tema`

### Requirement: Yachay Keyword Routing

Layer 2 (keyword→tool mapping) SHALL be extended with curriculum-aware keywords. When model inference fails, Yachay-specific keywords MUST route to the appropriate tool with contextual parameters.

| Keyword pattern | Tool | Context |
|----------------|------|---------|
| `progreso` \| `camino` \| `cómo voy` | `obtener_plan_completo` | Returns full plan with mastery |
| `siguiente` \| `qué sigue` \| `y ahora` | `obtener_siguiente_tema` | Next unlocked topic |
| `perfil` \| `resumen` \| `qué sabes` | `generar_resumen_alumno` | Student summary paragraph |
| `fracciones` \| `suma` \| `multiplicación` | `explicar_tema` | Falls through to existing |

#### Scenario: Yachay keyword routes to curriculum tool

- GIVEN model is unavailable (fallback mode active)
- WHEN student types "¿cómo voy en mi progreso?"
- THEN layer 2 MUST match keyword "progreso" → `obtener_plan_completo`
- AND response MUST contain mastery percentages from SQLite
- AND response MUST include "Temas dominados: 3 de 45"
