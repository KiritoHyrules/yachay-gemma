# Delta for ai-fallback

> MODIFIED capability: 4-layer fallback extended with Yachay curriculum-aware keyword routing

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: 4-Layer Fallback System

The fallback dispatcher SHALL evaluate 4 layers in order, short-circuiting at the first match. Layer 2 keyword mapping SHALL be extended with 4 Yachay-specific keyword patterns. Layer 4 generic responses SHALL reference Yachay persona ("Yachay está teniendo dificultades para responder. ¿Podrías intentar preguntar de otra forma?"). Layer 3 tool execution SHALL include all 13 tools from the extended registry.
(Previously: layer 2 had 5 keyword patterns, layer 4 generic encouragement without Yachay persona, layer 3 had 6 tools)

#### Scenario: Greeting short-circuits (unchanged)

- GIVEN user types "hola" or "buenos días"
- WHEN the fallback dispatcher evaluates layer 1
- THEN it MUST match the trivial greeting regex
- AND return "¡Hola! Soy Yachay, tu tutor de aritmética. ¿Qué querés aprender hoy?"
- AND layers 2-4 MUST NOT be evaluated

#### Scenario: Yachay persona in layer 4

- GIVEN user types an unrecognized query with no keyword match
- WHEN layers 1-3 all fail
- THEN layer 4 MUST return "Yachay está teniendo dificultades para responder. ¿Podrías intentar preguntar de otra forma?"
- AND the message MUST reference available context chips: "Probá con 'Explicar', 'Practicar' o 'Mi progreso'"
