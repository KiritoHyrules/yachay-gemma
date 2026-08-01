# gemma-model-download Specification

## Purpose

Descarga, verificación e instalación del modelo gated `gemma-4-E2B-it.litertlm` (2.59 GB) vía `FlutterGemma.installModel(...)` nativo de `flutter_gemma` 1.4.2, con OAuth PKCE de HuggingFace y token manual como respaldo. La verificación de integridad (tamaño/SHA256) es requisito previo a `createModel`. Nunca borra la DB sqflite ni realiza limpieza nuclear de archivos.

## Requirements

### Requirement: REQ-01 — Descarga del modelo con installModel nativo

`ModelDownloadService` MUST descargar el `.litertlm` mediante `FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm).fromNetwork(url, token).install()` cuando el modelo no está instalado. La operación MUST ser idempotente: si el modelo ya está instalado, no se re-descarga. El progreso MUST exponerse a la UI (porcentaje) y la descarga MAY usar el foreground service automático del plugin (>500 MB).

#### Scenario: Primera ejecución inicia la descarga

- GIVEN la app se lanza por primera vez sin modelo instalado
- WHEN `ModelDownloadService` verifica el modelo y no existe
- THEN la descarga inicia vía `installModel().fromNetwork(url, token)`
- AND el progreso (porcentaje) se reporta a la UI en tiempo real

#### Scenario: Modelo ya instalado — no re-descarga

- GIVEN el modelo `.litertlm` ya está instalado y verificado
- WHEN se intenta el flujo de descarga
- THEN la descarga se omite
- AND el flujo continúa directo a verificación y `createModel`

### Requirement: REQ-02 — Acceso gated (OAuth PKCE + token manual)

El acceso al modelo gated MUST autenticarse primero por OAuth 2.0 PKCE con redirect `com.aprendoplus.app://oauthredirect`; si el OAuth falla o no está disponible, el usuario MAY pegar un token HF manual. Si ambas vías fallan, la app MUST mostrar un error claro y entrar en modo degradado sin crash.

#### Scenario: OAuth PKCE exitoso

- GIVEN el usuario autoriza la app en el navegador HF
- WHEN el callback `com.aprendoplus.app://oauthredirect` devuelve el code
- THEN el code se intercambia por un token de acceso
- AND el token se usa en `fromNetwork(url, token)`

#### Scenario: Sin token — OAuth y token manual fallan

- GIVEN el OAuth PKCE falla (cancelado o error)
- AND el usuario no provee token manual
- WHEN se intenta instalar el modelo
- THEN la app MUST mostrar un error claro indicando que se requiere autorización HF
- AND la app entra en modo degradado sin IA sin crash

#### Scenario: 403 del servidor HF

- GIVEN el token es inválido o el acceso al repo gated no fue aceptado
- WHEN `installModel` responde 403
- THEN la app MUST mostrar un mensaje de error accionable (revisar token / aceptar licencia)
- AND no reintentar en bucle infinito

### Requirement: REQ-03 — Verificación de integridad previa a createModel

`ModelDownloadService` MUST verificar el archivo descargado (tamaño ≈ 2.59 GB y/o SHA256 esperado) antes de permitir `createModel`. Si la verificación falla, MUST borrar SOLO el archivo del modelo con nombre exacto y re-descargarlo.

#### Scenario: Checksum válido

- GIVEN la descarga completa con tamaño y SHA256 esperados
- WHEN se ejecuta la verificación
- THEN el modelo se acepta
- AND `createModel` procede

#### Scenario: Archivo corrupto — re-descarga

- GIVEN la descarga completa pero el SHA256 no coincide
- WHEN se ejecuta la verificación
- THEN el archivo corrupto se elimina (solo el archivo del modelo, nombre exacto)
- AND la descarga se reintenta una vez
- AND si falla de nuevo, la app entra en modo degradado con error claro

### Requirement: REQ-04 — Resiliencia de almacenamiento

Si el dispositivo no tiene espacio suficiente, la descarga MUST fallar con un error claro y la app MUST permanecer usable en modo degradado sin crash.

#### Scenario: Sin espacio en disco

- GIVEN el dispositivo tiene menos espacio libre que el tamaño del modelo
- WHEN se intenta la descarga
- THEN la descarga falla con error de almacenamiento
- AND la app muestra el error en el estado de modelo
- AND el modo degradado sin IA sigue operativo

### Requirement: REQ-05 — Re-descarga tras desinstalación

Si el sistema operativo desinstala la app o borra el modelo, la próxima ejecución MUST detectar la ausencia y re-descargar el `.litertlm` (comportamiento aceptado).

#### Scenario: Desinstalación y reinstalación

- GIVEN la app se reinstala o el modelo ya no existe en disco
- WHEN se inicia el bootstrap
- THEN el estado muestra `Sin modelo`
- AND el flujo de REQ-01 vuelve a descargar el modelo completo

### Requirement: REQ-06 — Seguridad de datos del estudiante

El flujo de descarga/verificación MUST NOT borrar ni modificar la DB sqflite del estudiante ni archivos no relacionados. La única limpieza permitida MUST ser el archivo del modelo con nombre exacto conocido.

#### Scenario: Limpieza acotada al modelo

- GIVEN falla la verificación de un archivo corrupto
- WHEN se ejecuta la limpieza
- THEN solo se elimina `gemma-4-E2B-it.litertlm` (o archivo equivalente conocido)
- AND la DB sqflite y otros archivos de documentos permanecen intactos
