# gemma-model-status Specification

## Purpose

Expone el estado del modelo Gemma 4 de forma visible y no ambigua en `yachay_scaffold.dart`: Sin modelo → Descargando X% → Verificando → Listo (CPU) → Error. Reemplaza el chip genérico "Offline" y refleja el backend real vía `activeBackend`.

## Requirements

### Requirement: REQ-01 — Máquina de estados del chip

El chip de estado del modelo en `yachay_scaffold` MUST mostrar exactamente uno de estos estados: `Sin modelo`, `Descargando X%`, `Verificando`, `Listo (CPU)`, `Error`. Las transiciones MUST seguir el orden de bootstrap: verificar → descargar → verificar → listo, o bien pasar a `Error`.

#### Scenario: Transición completa en primera ejecución

- GIVEN la app arranca sin modelo instalado
- WHEN el bootstrap verifica y no encuentra el modelo
- THEN el chip muestra `Sin modelo`
- AND al iniciar la descarga muestra `Descargando X%` con progreso actualizado
- AND al terminar la descarga muestra `Verificando`
- AND al pasar la verificación muestra `Listo (CPU)`

#### Scenario: Sin modelo no muestra "Offline" genérico

- GIVEN el modelo no está instalado
- WHEN la UI renderiza el estado
- THEN el chip MUST mostrar `Sin modelo` (nunca el texto genérico "Offline")
- AND ofrecer la acción de descargar/autenticar

### Requirement: REQ-02 — Backend real vía activeBackend

Cuando el estado es `Listo`, el chip MUST reflejar el backend efectivo consultando `activeBackend` del `InferenceModel` (p. ej. `Listo (CPU)`), incluso si el runtime hizo fallback interno GPU→CPU.

#### Scenario: Fallback interno GPU→CPU

- GIVEN el runtime degrada el backend de GPU a CPU durante la inicialización
- WHEN el modelo queda listo
- THEN `activeBackend` devuelve `cpu`
- AND el chip muestra `Listo (CPU)`

### Requirement: REQ-03 — Estado de error con mensaje claro

Si fallan ambas vías de autenticación (OAuth PKCE y token manual) o la instalación, el estado MUST ser `Error` con un mensaje accionable en español que indique el paso a seguir; la app MUST NOT crashear.

#### Scenario: Fallan OAuth y token manual

- GIVEN el OAuth PKCE falla y no hay token manual válido
- WHEN se intenta la instalación
- THEN el chip muestra `Error`
- AND el mensaje explica que se requiere autorización de HuggingFace y cómo proveer el token

#### Scenario: 403 durante la descarga

- GIVEN el servidor HF responde 403 (token inválido o licencia no aceptada)
- WHEN la descarga falla
- THEN el estado pasa a `Error`
- AND el mensaje indica revisar el token / aceptar la licencia del repo gated

### Requirement: REQ-04 — Modo degradado consistente con el estado

Con estado `Sin modelo` o `Error`, la app MUST seguir funcionando en modo degradado sin IA (FallbackDispatcher) y el chip MUST reflejar el estado real; nunca mostrar `Listo` cuando el modelo no está operativo.

#### Scenario: Chat en modo degradado

- GIVEN el estado del modelo es `Sin modelo` (o `Error`)
- WHEN el estudiante envía un mensaje
- THEN la respuesta proviene del modo degradado sin IA
- AND la app no crashea
- AND el chip continúa mostrando el estado real del modelo
