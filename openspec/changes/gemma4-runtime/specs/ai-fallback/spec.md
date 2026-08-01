# Delta for ai-fallback

> Cambio: reformulación como modo degradado SIN IA (`fallback_responses.json` + `FallbackDispatcher`). No es un modelo alternativo ni un respaldo de Gemma 3n.

## MODIFIED Requirements

### Requirement: REQ-01 — Sistema de fallback de 4 capas (modo degradado)

El `FallbackDispatcher` SHALL evaluar 4 capas en orden, cortocircuitando en la primera coincidencia. El fallback MUST tratarse como modo degradado sin IA: NUNCA como modelo Gemma alternativo ni como respaldo de Gemma 3n. La capa 2 MUST incluir los patrones de keywords Yachay; la capa 3 MUST ejecutar las 13 tools con contenido empaquetado; la capa 4 MUST usar la persona Yachay.

| Layer | Trigger | Response |
|-------|---------|----------|
| 1 | Saludo trivial (regex) | Aliento instantáneo en español, sin modelo |
| 2 | Keyword→tool match | Ejecutar tool con datos empaquetados (incl. keywords Yachay) |
| 3 | Ejecución de tool determinista | Handler local con contenido pre-redactado (13 tools) |
| 4 | Sin coincidencia | Aliento genérico Yachay en español peruano |

(Previously: mismo dispatcher de 4 capas, sin declarar explícitamente "modo degradado sin IA")

#### Scenario: Greeting short-circuits all layers

- GIVEN el usuario escribe "hola" o "buenos días"
- WHEN el dispatcher evalúa la capa 1
- THEN MUST coincidir con el regex de saludo
- AND devolver "¡Hola! Soy Yachay, tu tutor de aritmética. ¿Qué querés aprender hoy?"
- AND las capas 2-4 MUST NOT evaluarse

#### Scenario: Keyword routes to tool

- GIVEN el usuario escribe "quiero practicar ejercicios de álgebra" y no hay modelo
- WHEN la capa 2 evalúa
- THEN la keyword "ejercicios" MUST coincidir → tool `generar_ejercicios`
- AND la capa 3 MUST ejecutar la tool con `{tema: "algebra", nivel: "1"}`
- AND la respuesta MUST contener ejercicios empaquetados de `fallback_responses.json`

#### Scenario: Unmatched query reaches layer 4

- GIVEN el usuario escribe "no sé qué estudiar" sin coincidencia de keywords
- WHEN las capas 1-3 fallan
- THEN la capa 4 MUST devolver "Yachay está teniendo dificultades para responder. ¿Podrías intentar preguntar de otra forma?"
- AND el mensaje MUST referenciar los chips de contexto ("Probá con 'Explicar', 'Practicar' o 'Mi progreso'")

### Requirement: REQ-02 — Fallback de emergencia en todos los puntos de falla

Todo camino de error de `GemmaService` (timeout, OOM, PlatformException, respuesta vacía, descarga fallida, OAuth/403/sin espacio, verificación corrupta) MUST enrutar al modo degradado en lugar de devolver vacío o placeholder, y MUST NOT crashear. Si el error es de instalación del modelo, la app MUST además comunicarlo en el estado de modelo.
(Previously: solo timeout/OOM/PlatformException/XML malformado)

#### Scenario: Inference timeout triggers fallback

- GIVEN `procesarMensaje("explícame fracciones")` está corriendo
- WHEN el timeout de 30 s dispara
- THEN el sistema MUST capturar `TimeoutException`
- AND enrutar el mensaje original por `FallbackDispatcher.dispatch("explícame fracciones")`
- AND devolver la respuesta determinista de capa 2 para "fracciones" → `explicar_tema`

#### Scenario: Fallo de instalación del modelo entra en modo degradado

- GIVEN la instalación falla (sin token, 403 o archivo corrupto)
- WHEN se intenta inferencia
- THEN la app MUST responder desde el modo degradado sin crash
- AND el chip de estado MUST mostrar `Error`/`Sin modelo` con el mensaje correspondiente

## ADDED Requirements

### Requirement: REQ-03 — Activación del modo degradado

Cuando el modelo no puede instalarse o cargarse (sin token, 403, sin espacio, archivo corrupto, sin conectividad), la app MUST operar en modo degradado sin IA: `FallbackDispatcher` + `fallback_responses.json` cubren todas las consultas y las funciones de tutoría siguen utilizables, sin crash.

#### Scenario: Sin modelo, tutoría funcional

- GIVEN el modelo no está instalado (estado `Sin modelo` o `Error`)
- WHEN el estudiante interactúa con Yachay
- THEN todas las respuestas provienen de `FallbackDispatcher`
- AND las herramientas educativas (diagnóstico, ejercicios, progreso) siguen funcionando
- AND la app no crashea

#### Scenario: Recuperación tras re-descarga

- GIVEN la app está en modo degradado por falta de modelo
- WHEN la descarga del modelo completa y verifica correctamente
- THEN la app MUST salir del modo degradado
- AND el chip pasa a `Listo (CPU)`
- AND la inferencia usa Gemma 4 real
