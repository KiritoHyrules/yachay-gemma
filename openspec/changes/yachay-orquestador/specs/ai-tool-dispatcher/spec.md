# Delta for ai-tool-dispatcher

> MODIFIED capability: tool set extended to 13 tools, system prompt rewritten for Yachay Socratic persona, dispatch loop strengthened for educational orchestration

## ADDED Requirements

### Requirement: Yachay Tool Set Expansion

The tool registry SHALL register 7 new Yachay-specific tools in addition to the existing 6 tools:

| # | Tool | Domain | Returns |
|---|------|--------|---------|
| 1 | `evaluar_respuesta(tema, correcta)` | yachay-mastery | Updated P(L), mastery flag, feedback |
| 2 | `consultar_estado(tema)` | yachay-mastery | P(L), attempts, mastered flag |
| 3 | `obtener_siguiente_tema()` | yachay-curriculum | Next unlocked topic ID + title |
| 4 | `obtener_plan_completo()` | yachay-curriculum | All 45 subtopics with mastery status |
| 5 | `generar_nota_progreso(tema)` | yachay-camino | Personalized encouragement text |
| 6 | `generar_resumen_alumno()` | yachay-perfil | "Lo que Yachay sabe de vos" paragraph |
| 7 | `registrar_recomendacion(texto)` | yachay-dashboard | Stores teacher insight in DB |

#### Scenario: New tool executes via dispatch loop

- GIVEN the model emits `<action name="evaluar_respuesta"><tema>arit_nn_01a</tema><correcta>true</correcta></action>`
- WHEN the dispatch loop parses this action
- THEN `evaluar_respuesta` handler MUST invoke BKT update on `arit_nn_01a`
- AND the tool result MUST be fed back as context for the next inference round
- AND `student_mastery` MUST be persisted

### Requirement: Yachay System Prompt

The system prompt SHALL be rewritten from "Peruvian math tutor" to "Yachay — Socratic AI tutor." The prompt MUST encode: (1) NEVER give direct answers — guide with questions, (2) use warm Peruvian Spanish with Quechua-influenced terms (Yachay, sumaq, allin), (3) celebrate mastery milestones enthusiastically, (4) reference student's mastered topics by name from `student_mastery` context, (5) suggest next steps based on `obtener_siguiente_tema()`.

#### Scenario: Socratic response to direct question

- GIVEN the Yachay system prompt is active
- WHEN student asks "¿cuánto es 3/4 + 1/2?"
- THEN Yachay MUST NOT answer "5/4" directly
- AND MUST respond with a guiding question like "¿Qué necesitas para sumar fracciones con distinto denominador?"

#### Scenario: System prompt renders tool descriptions

- GIVEN 13 tools are registered in the tool registry
- WHEN `SystemPrompt.build()` generates the Yachay prompt
- THEN all 13 tool descriptions MUST appear in the prompt
- AND each MUST use Peruvian Spanish parameter names (`tema`, `correcta`, `nivel`)

## MODIFIED Requirements

### Requirement: Dispatch Loop

`procesarMensaje(String mensaje)` SHALL execute a dispatch loop with max 7 rounds: (1) detect greeting → speak if first-time user, (2) run inference, (3) parse action → execute tool, (4) feed tool result to model, (5) repeat until speak action or max rounds. A checkpoint after each tool execution SHALL persist `student_mastery` state to ensure no progress is lost on app termination.
(Previously: max 5 rounds, no tool-result persistence checkpoint)

#### Scenario: Multi-tool orchestration

- GIVEN student types "¿cómo voy en aritmética?"
- WHEN the dispatch loop runs
- THEN round 1 inference MAY emit `<action name="consultar_estado">`
- AND round 2 inference MAY emit `<action name="obtener_plan_completo">`
- AND round 3 inference SHALL produce a speak response synthesizing both results
- AND the loop SHALL terminate when a speak action is emitted, up to round 7

#### Scenario: Max rounds exhausted (unchanged behavior)

- GIVEN the model keeps emitting tool actions without a speak
- WHEN 7 rounds complete
- THEN the system MUST force a speak using `detectForcedTool`
- AND return the accumulated response

### Requirement: Feature Gate

The dispatch loop SHALL be gated behind `useYachayOrchestrator` flag (default `true`). When `false`, the system SHALL route to the legacy three-screen flow (DiagnosticScreen → RutaScreen → LeccionScreen).
(Previously: gated behind `useXmlDispatch` flag routing to legacy `generarExplicacion`/`generarEjerciciosRefuerzo`)
