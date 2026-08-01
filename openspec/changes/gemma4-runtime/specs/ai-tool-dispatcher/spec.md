# Delta for ai-tool-dispatcher

> Cambio: tool calling nativo (`FunctionCallResponse`) de `flutter_gemma` 1.4.2 reemplaza el dispatch XML + `action_parser.dart` + `grammar_builder.dart`. Las 13 tools se conservan.

## REMOVED Requirements

### Requirement: XML Action Format

(Reason: el modelo Gemma 4 con function calling nativo ya no emite XML; el formato `<action name=...>` es legacy)
(Migration: `FunctionCallResponse` del plugin entrega name + args tipados; eliminar instrucciones XML del prompt)

### Requirement: Action Parser

(Reason: `action_parser.dart` se elimina; el parseo lo hace el runtime nativo de 1.4.2)
(Migration: `findNextAction` y `repairXml` desaparecen; los tests de `action_parser_test.dart` se reemplazan por tests de contrato `FunctionCallResponse`)

### Requirement: Forced Tool Detection

(Reason: `detectForcedTool` era el rescate para XML malformado; ese modo de fallo ya no existe con dispatch nativo)
(Migration: `toolChoice` + tool por defecto del chat cubren la selección determinista)

## MODIFIED Requirements

### Requirement: REQ-01 — Dispatch Loop

`procesarMensaje(String mensaje)` SHALL ejecutar un bucle de dispatch nativo con máx. 7 rondas: (1) detectar saludo → hablar si es primera vez, (2) correr inferencia con `getResponseAsync()`, (3) si la respuesta es un `FunctionCallResponse`, ejecutar la tool con sus argumentos tipados, (4) retroalimentar el resultado al modelo, (5) repetir hasta respuesta final de texto o 7 rondas. El checkpoint tras cada tool SHALL persistir `student_mastery`. El gate `useXmlDispatch` MUST eliminarse; el dispatch nativo corre sin gates XML.
(Previously: bucle que parseaba `<action>` XML con `findNextAction` y `detectForcedTool` como rescate)

#### Scenario: Single tool call resolves

- GIVEN el estudiante escribe "explícame fracciones"
- WHEN el bucle de dispatch corre
- THEN ronda 1 devuelve `FunctionCallResponse(name: "explicar_tema", args: {...})`
- AND el handler de la tool devuelve una explicación
- AND ronda 2 devuelve texto final con la explicación
- AND el bucle termina en ronda 2

#### Scenario: Multi-tool orchestration

- GIVEN el estudiante escribe "¿cómo voy en aritmética?"
- WHEN el bucle corre
- THEN ronda 1 MAY emitir `FunctionCallResponse("consultar_estado")`
- AND ronda 2 MAY emitir `FunctionCallResponse("obtener_plan_completo")`
- AND ronda 3 SHALL producir una respuesta de texto que sintetice ambos resultados
- AND el bucle termina con respuesta de texto, hasta ronda 7

#### Scenario: Max rounds exhausted

- GIVEN el modelo sigue emitiendo `FunctionCallResponse` sin texto final
- WHEN se completan 7 rondas
- THEN el sistema MUST forzar una respuesta final con el resultado acumulado
- AND devolver el texto al usuario

### Requirement: REQ-02 — Tool Registry

El sistema SHALL registrar las 13 tools conservadas (6 originales + 7 Yachay), cada una con `handler(args, ctx) → Future<ToolResult>`, y exponerlas al plugin 1.4.2 vía `toFlutterGemmaTools()` compatible con la firma `Tool` (name/description/parameters).
(Previously: registry con `toFlutterGemmaTools()` para API 0.10.x)

#### Scenario: Tool handler execution

- GIVEN el modelo invoca `ejecutar_diagnostico` con `{materia: "matematica"}`
- WHEN el handler corre
- THEN MUST invocar `DiagnosticoService.ejecutarComoHerramienta("matematica", perfil)`
- AND devolver `{summary: "...", payload: DiagnosticResult}`

### Requirement: REQ-03 — Yachay Tool Set Expansion

El registry SHALL mantener las 7 tools Yachay además de las 6 originales (13 total):

| # | Tool | Domain | Returns |
|---|------|--------|---------|
| 1 | `evaluar_respuesta(tema, correcta)` | yachay-mastery | Updated P(L), mastery flag, feedback |
| 2 | `consultar_estado(tema)` | yachay-mastery | P(L), attempts, mastered flag |
| 3 | `obtener_siguiente_tema()` | yachay-curriculum | Next unlocked topic ID + title |
| 4 | `obtener_plan_completo()` | yachay-curriculum | All 45 subtopics with mastery status |
| 5 | `generar_nota_progreso(tema)` | yachay-camino | Personalized encouragement text |
| 6 | `generar_resumen_alumno()` | yachay-perfil | "Lo que Yachay sabe de vos" paragraph |
| 7 | `iniciar_conversacion()` | yachay-conversacion | Warm greeting presenting Yachay + learning options |

(Previously: expansión de 6 a 13 tools con dispatch XML)

#### Scenario: New tool executes via native dispatch

- GIVEN el modelo emite `FunctionCallResponse(name: "evaluar_respuesta", args: {tema: "arit_nn_01a", correcta: true})`
- WHEN el bucle nativo procesa el call
- THEN el handler MUST ejecutar el update BKT sobre `arit_nn_01a`
- AND el resultado se retroalimenta como contexto para la siguiente ronda
- AND `student_mastery` MUST persistirse

### Requirement: REQ-04 — Yachay System Prompt

El prompt Yachay MUST entregarse como `systemInstruction` de `createChat` (1.4.2) y codificar: (1) nunca dar respuestas directas — guiar con preguntas, (2) español peruano cálido con términos quechuas (Yachay, sumaq, allin), (3) celebrar hitos de dominio, (4) referenciar temas dominados desde `student_mastery`, (5) sugerir pasos con `obtener_siguiente_tema()`. Las descripciones de las 13 tools MUST pasarse como objetos `Tool` del plugin (no renderizadas en el prompt).
(Previously: prompt construido con `grammar_builder.dart` y descripciones XML en el texto)

#### Scenario: Socratic response to direct question

- GIVEN el `systemInstruction` Yachay está activo
- WHEN el estudiante pregunta "¿cuánto es 3/4 + 1/2?"
- THEN Yachay MUST NOT responder "5/4" directamente
- AND MUST responder con una pregunta guía ("¿Qué necesitas para sumar fracciones con distinto denominador?")

#### Scenario: Tool descriptions via Tool objects

- GIVEN 13 tools registradas en el registry
- WHEN `createChat` se configura
- THEN las 13 tools MUST pasarse como objetos `Tool` (name/description/parameters)
- AND los nombres de parámetros MUST usar español peruano (`tema`, `correcta`, `nivel`)
