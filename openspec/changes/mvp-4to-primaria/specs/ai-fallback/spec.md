# Delta for ai-fallback

## ADDED Requirements

### Requirement: Progress-Aware Layer 3 Tool Execution

The system MUST pass real `ToolContext` with `StudentState.masteryMap` to `_layer3ExecuteTool()` instead of hardcoded `nivel='1'`. Tool responses MUST reflect the student's actual progress.

#### Scenario: Tool execution uses real mastery data

- GIVEN student has pLearned=0.75 on topic "mat-02" with 8 attempts
- WHEN `_layer3ExecuteTool()` runs `explicar_tema("mat-02")`
- THEN the explanation MUST be scoped to `nivel` derived from real mastery
- AND the response MUST NOT use hardcoded `nivel='1'`

### Requirement: ToneAdapter Integration in Fallback

The system MUST apply `ToneAdapter` output to all fallback response messages. Fallback responses SHALL vary tone based on `StudentState.masteryMap` for the current topic.

#### Scenario: Fallback greeting uses encouraging tone for low mastery

- GIVEN student has pLearned=0.20 on current topic
- WHEN fallback dispatches a layer-4 generic response
- THEN the response MUST use ToneAdapter's encouraging tone
- AND "¡Vas muy bien!" or similar encouragement MUST be included

## MODIFIED Requirements

### Requirement: 4-Layer Fallback System

The fallback dispatcher SHALL evaluate 4 layers in order, short-circuiting at first match. Layer 1 keywords SHALL use native `String.contains()`/`toLowerCase()` — zero `RegExp`. Layer 3 tool execution SHALL use `StudentState.masteryMap` context (not hardcoded `nivel='1'`). Layer 4 SHALL apply `ToneAdapter` for personalized tone.

| Layer | Trigger | Response |
|-------|---------|----------|
| 1 | Greeting keyword (native String match) | Instant Spanish encouragement |
| 2 | Keyword→tool mapping | Execute tool with real student context |
| 3 | Tool execution (deterministic) | Run handler with progress-aware data |
| 4 | No match | ToneAdapter-personalized encouragement |

(Previously: Layer 1 used RegExp, Layer 3 hardcoded `nivel='1'`, Layer 4 static message — no ToneAdapter.)

#### Scenario: Greeting short-circuits via native String match

- GIVEN user types "hola" or "buenos días"
- WHEN layer 1 evaluates
- THEN it MUST match via `String.contains()`/`toLowerCase()` — NO RegExp
- AND return "¡Hola! Soy Yachay, tu tutor. ¿Qué querés aprender hoy?"
- AND layers 2-4 MUST NOT be evaluated

#### Scenario: Keyword routes to tool with real student data

- GIVEN user types "quiero practicar ejercicios" and model is unavailable
- AND StudentState.masteryMap has pLearned=0.60 for current topic
- WHEN layer 2 evaluates
- THEN keyword "ejercicios" MUST match → `generar_ejercicios`
- AND layer 3 MUST execute with real student mastery context
- AND response MUST NOT use hardcoded `nivel='1'`

#### Scenario: Unmatched query reaches layer 4 with ToneAdapter

- GIVEN user types "no sé qué estudiar" with no keyword match
- AND current topic pLearned=0.25
- WHEN layers 1-3 all fail
- THEN layer 4 MUST return tone-adapted encouragement from ToneAdapter
- AND the message MUST be encouraging (not neutral/challenging)

### Requirement: Yachay Keyword Routing

Layer 2 keyword mapping SHALL include 4to Primaria curriculum topics. When model inference fails, keywords MUST route to the appropriate tool with real student context.

| Keyword | Tool | Context |
|---------|------|---------|
| `progreso` \| `camino` \| `cómo voy` | `obtener_plan_completo` | Full plan with mastery |
| `siguiente` \| `qué sigue` \| `y ahora` | `obtener_siguiente_tema` | Next unmastered topic |
| `perfil` \| `resumen` \| `qué sabes` | `generar_resumen_alumno` | Student summary |
| `fracciones` \| `suma` \| `multiplicación` | `explicar_tema` | Topic explanation |

(Previously: same keywords, but tools referenced 1° Secundaria DAG with 45 subtopics.)

#### Scenario: Yachay keyword routes to curriculum tool

- GIVEN model is unavailable (fallback mode active)
- WHEN student types "¿cómo voy en mi progreso?"
- THEN layer 2 MUST match keyword "progreso" → `obtener_plan_completo`
- AND response MUST contain mastery from 4to Primaria flat curriculum
- AND reference "Temas dominados: N de 18" format

### Requirement: Emergency Fallback at All Failure Points

Every error path in `GemmaService` (timeout, OOM, PlatformException, empty response) SHALL route through the 4-layer fallback. Fallback MUST use ToneAdapter for response tone.

(Previously: same requirement — no behavioral change in routing logic. Updated to reflect ToneAdapter integration.)

#### Scenario: Inference timeout triggers fallback

- GIVEN `procesarMensaje("explícame fracciones")` is running
- WHEN the inference timeout fires
- THEN the system MUST catch the timeout
- AND route through `FallbackDispatcher.dispatch("explícame fracciones")`
- AND return layer 2 deterministic response with real student context
