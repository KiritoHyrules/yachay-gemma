# ai-tool-dispatcher Specification

> NEW capability: XML-based tool calling dispatch loop with 6 education-domain tools

## Purpose

Replace free-form text generation with structured, safe XML tool dispatch — the model selects and invokes education tools, with results fed back for multi-turn reasoning (N-01, N-03, N-04, N-08).

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

`procesarMensaje(String mensaje)` SHALL execute a dispatch loop with max 5 rounds: (1) detect greeting → speak, (2) run inference, (3) parse action → execute tool, (4) feed tool result to model, (5) repeat until speak action or max rounds.

#### Scenario: Single tool call resolves

- GIVEN student types "explícame fracciones"
- WHEN the dispatch loop runs
- THEN round 1 inference emits `<action name="explicar_tema">`
- AND the tool handler returns an explanation
- AND round 2 inference emits a speak response with the explanation
- AND the loop terminates at round 2

#### Scenario: Max rounds exhausted

- GIVEN the model keeps emitting tool actions without a speak
- WHEN 5 rounds complete
- THEN the system MUST force a speak using `detectForcedTool`
- AND return whatever accumulated response exists

### Requirement: Tool Registry

The system SHALL register 6 tools: `explicar_tema`, `generar_ejercicios`, `ejecutar_diagnostico`, `obtener_perfil`, `obtener_leccion`, `registrar_interaccion`. Each tool MUST have a `handler(args, ctx) → Future<ToolResult>`.

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

The dispatch loop SHALL be gated behind `useXmlDispatch` flag (default `true`). When `false`, the system SHALL revert to legacy `generarExplicacion`/`generarEjerciciosRefuerzo` methods.

#### Scenario: Feature gate disabled

- GIVEN `useXmlDispatch = false`
- WHEN `procesarMensaje("explícame fracciones")` is called
- THEN the system MUST route to legacy `generarExplicacion("fracciones")`
- AND no XML parsing or tool dispatch SHALL occur
