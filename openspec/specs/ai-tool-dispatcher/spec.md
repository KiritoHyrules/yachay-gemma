# ai-tool-dispatcher Specification

> XML-based tool calling dispatch loop with 13 education-domain tools for Yachay Socratic tutor persona

## Purpose

Replace free-form text generation with structured, safe XML tool dispatch — the model selects and invokes education tools, with results fed back for multi-turn reasoning (N-01, N-03, N-04, N-08). Extended from 6 to 13 tools for yachay-orquestador.

## Requirements

### Requirement: XML Action Format

The model SHALL emit tool calls using this XML format:
```xml
<action name="tool_name">
<param>value</param>
</action>
```

#### Scenario: Model emits valid action

- GIVEN the system prompt instructs the model on tool format
- WHEN the model responds to "explícame fracciones"
- THEN the output MUST contain `<action name="explicar_tema">` with `<tema>` and `<nivel>` child elements
- AND MUST close with `</action>`

### Requirement: Action Parser

The system MUST implement `findNextAction(text, from)` that locates the first `<action name="...">` block and extracts its name and child-element arguments.

#### Scenario: Parse complete action

- GIVEN text containing `<action name="generar_ejercicios"><tema>fracciones</tema><nivel>2</nivel></action>`
- WHEN `findNextAction(text)` is called
- THEN it MUST return `{name: "generar_ejercicios", args: {tema: "fracciones", nivel: 2}, start, end}`
- AND `start`/`end` MUST mark exact byte offsets for extraction

#### Scenario: Incomplete action during streaming

- GIVEN a partial response ending with `<action name="explicar_te` (tag not closed)
- WHEN `findNextAction` is called
- THEN it MUST return `"incomplete"` (not null, not a ParsedAction)

### Requirement: Dispatch Loop

`procesarMensaje(String mensaje)` SHALL execute a dispatch loop with max 7 rounds: (1) detect greeting → speak if first-time user, (2) run inference, (3) parse action → execute tool, (4) feed tool result to model, (5) repeat until speak action or max rounds. A checkpoint after each tool execution SHALL persist `student_mastery` state to ensure no progress is lost on app termination.

#### Scenario: Single tool call resolves

- GIVEN student types "explícame fracciones"
- WHEN the dispatch loop runs
- THEN round 1 inference emits `<action name="explicar_tema">`
- AND the tool handler returns an explanation
- AND round 2 inference emits a speak response with the explanation
- AND the loop terminates at round 2

#### Scenario: Multi-tool orchestration

- GIVEN student types "¿cómo voy en aritmética?"
- WHEN the dispatch loop runs
- THEN round 1 inference MAY emit `<action name="consultar_estado">`
- AND round 2 inference MAY emit `<action name="obtener_plan_completo">`
- AND round 3 inference SHALL produce a speak response synthesizing both results
- AND the loop SHALL terminate when a speak action is emitted, up to round 7

#### Scenario: Max rounds exhausted

- GIVEN the model keeps emitting tool actions without a speak
- WHEN 7 rounds complete
- THEN the system MUST force a speak using `detectForcedTool`
- AND return the accumulated response

### Requirement: Tool Registry

The system SHALL register 13 tools: the original 6 (`explicar_tema`, `generar_ejercicios`, `ejecutar_diagnostico`, `obtener_perfil`, `obtener_leccion`, `registrar_interaccion`) plus 7 Yachay-specific tools (`evaluar_respuesta`, `consultar_estado`, `obtener_siguiente_tema`, `obtener_plan_completo`, `generar_nota_progreso`, `generar_resumen_alumno`, `registrar_recomendacion`). Each tool MUST have a `handler(args, ctx) → Future<ToolResult>`.

#### Scenario: Tool handler execution

- GIVEN the model calls `ejecutar_diagnostico` with `{materia: "matematica"}`
- WHEN the tool handler runs
- THEN it MUST invoke `DiagnosticoService.ejecutarComoHerramienta("matematica", perfil)`
- AND return `{summary: "...", payload: DiagnosticResult}`

### Requirement: Forced Tool Detection

`detectForcedTool(mensaje)` SHALL map user messages to tools via keyword matching when XML parsing fails — as a rescue path for malformed model output.

#### Scenario: Rescue after XML parse failure

- GIVEN the model emits malformed XML that `repairXml` cannot fix
- WHEN `detectForcedTool("necesito ejercicios de fracciones")` runs
- THEN it MUST match keyword "ejercicios" → `generar_ejercicios` tool
- AND the dispatch loop MUST execute that tool deterministically

### Requirement: Feature Gate

The dispatch loop SHALL be gated behind `useYachayOrchestrator` flag (default `true`). When `false`, the system SHALL route to the legacy three-screen flow (DiagnosticScreen → RutaScreen → LeccionScreen).

#### Scenario: Feature gate disabled

- GIVEN `useYachayOrchestrator = false`
- WHEN `procesarMensaje("explícame fracciones")` is called
- THEN the system MUST route to legacy `DiagnosticoScreen`
- AND no XML dispatch or Yachay tool calls SHALL occur

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
