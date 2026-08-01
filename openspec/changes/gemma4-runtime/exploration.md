# Exploration: gemma4-runtime

> Cambio: migrar Aprendo+ a **Gemma 4 E2B IT** exclusivamente (formato `.litertlm`,
> runtime LiteRT-LM vía `flutter_gemma`). Gemma 3n queda FUERA (sin baseline ni
> fallback). Se adopta el patrón de bootstrap de `Proyecto referencia/gemma-vision`:
> verificar/descargar el modelo antes del chat, validar archivo, backend CPU por
> defecto, estado de modelo visible, bootstrap robusto.
>
> Contexto del proyecto: `openspec/config.yaml` contiene prosa stale (GGUF,
> MethodChannel, "no source code yet"). **El código ejecutable manda**: el runtime
> real hoy es `flutter_gemma ^0.10.0` (lock 0.10.6) con el modelo `.task` de Gemma 3n.

## Executive Summary

**Verdict: RECOMMENDED con alta confianza, PERO requiere un upgrade de
`flutter_gemma` 0.10.6 → 1.4.2** que rompe API. `ModelType.gemma4`,
`ModelFileType.litertlm` y `FlutterGemma.installModel(...).fromNetwork(url, token)`
SOLO existen en `flutter_gemma` 1.4.2 — **no existen en 0.10.6** (verificado en el
pub cache local). El entorno del proyecto (Flutter 3.44.8 / Dart 3.12.2) es
compatible con los requisitos de 1.4.2 (Flutter >=3.44.0, Dart >=3.12.0), así que el
upgrade es viable sin tocar el toolchain, pero implica reescribir la capa de
inferencia (`generateChatResponseAsync()` → `getResponseAsync()`, firma nueva de
`createChat`/`createSession`, `systemInstruction`, `maxOutputTokens`,
`activeBackend`, `toolChoice`).

El modelo objetivo `gemma-4-E2B-it.litertlm` (2.59 GB, Xet) existe en
`litert-community/gemma-4-E2B-it-litert-lm` (Apache-2.0 base, acceso gated → OAuth
de HuggingFace requerido). El cambio previo `flutter-gemma-migration` quedó
INCOMPLETO: el `model_download_service.dart` prometido en tasks/design **nunca se
creó**, y `action_parser.dart`/`grammar_builder.dart` que debían eliminarse siguen
existiendo y en uso. La referencia gemma-vision aporta el patrón completo
(descarga+OAuth+bootstrap+estado visible), pero tiene piezas PELIGROSAS que NO se
deben copiar: `dispose()` con `modelManager.deleteModel()` y la limpieza nuclear de
archivos que barrería la base de datos sqflite del estudiante.

Baseline de tests verificado hoy: **209 pasan, 4 fallan** (fallas conocidas de
Yachay: `1° Sec` no encontrado y `pumpAndSettle timed out`) en ~14 segundos.

## Current State (evidencia de archivos/líneas)

### `lib/modules/gemma/gemma_service.dart` (897 líneas)

| Aspecto | Estado | Evidencia |
|---|---|---|
| Modelo cargado | Gemma 3n `.task` hardcodeado | L63 `defaultFlutterGemmaModelFile = 'gemma-3n-E2B-it-int4.task'` |
| Backend | **GPU hardcodeado** | L218 `preferredBackend: PreferredBackend.gpu` |
| ModelType | `gemmaIt` (Gemma 3) | L219 `modelType: ModelType.gemmaIt` |
| Verificación previa | Parcial: `isModelInstalled` + `existsSync()` antes de `setModelPath` | L212-215 |
| Descarga del modelo | **NO existe** — espera instalación externa | `init()` no descarga; sin `installModel` |
| Validación de archivo | Solo existencia (>0 bytes implícito), **sin tamaño/checksum** | L212-215 |
| Tools | 13 registradas (6 Phase 5 + 7 Yachay) | L643-667 `_inicializarRegistry()` |
| Fallback | `fallback_responses.json` (assets) + `FallbackDispatcher` 4 capas | L697-715, `assets/data/fallback_responses.json` |
| Feature gates | `useFlutterGemma`, `useXmlDispatch`, `useYachayOrchestrator` (static, default true) | L125-138 |
| Legacy | Código MethodChannel `gemma_engine`/`gemma_engine_stream` + GGUF persisten como deuda de rollback | L502-591, L613-639 (`google_gemma-4-E2B-it-IQ2_M.gguf`) |
| `dispose()` | Seguro: solo `_model?.close()` — NO borra el modelo | L327-340 |
| Streaming | `generateChatResponseAsync()` (API 0.10.x) con throttle 3 tokens, timeout 30s | L353-431 |

### `lib/modules/yachay/screens/yachay_scaffold.dart` (226 líneas)

- Estado visible genérico: chip `'Gemma' | 'Offline' | 'Cargando...'` — L140. El
  usuario quiere estado de modelo visible (no "Offline" genérico).
- `_initGemma()` llama `cargarModelo()` **sin verificar/descargar el modelo antes**
  — L38-55.
- `_sendMessage()` espera hasta 30s al modelo con polling — L200-206.

### `lib/modules/gemma/tool_registry.dart` (177 líneas)

- `ToolSpec`/`ToolParam`/`ToolResult`/`ToolContext` + `toFlutterGemmaTools()` —
  limpio, tipo seguro, testeable (L107-177). **Se conserva tal cual**; la firma de
  `Tool` de flutter_gemma 1.4.2 es compatible (name/description/parameters).

### Dependencias (`pubspec.yaml` / `pubspec.lock`)

- `flutter_gemma: ^0.10.0` → lock resuelve **0.10.6** (pubspec.lock:176).
- El pub cache local tiene `flutter_gemma-0.10.0`, `-0.10.6` y **`-1.4.2`**.
- Aprendo+ NO tiene: `flutter_web_auth_2`, `flutter_downloader`, `http`,
  `crypto`, `shared_preferences`, `url_launcher`, `permission_handler` (las usa la
  referencia).

### Android (`android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle`)

- Permisos: solo `INTERNET` + `ACCESS_NETWORK_STATE` (Manifest L4-5).
- **NO hay `intent-filter` de deep link** → necesario para el callback OAuth
  (`com.aprendoplus.app://oauthredirect`) con `flutter_web_auth_2`.
- `compileSdk 36`, `minSdkVersion = flutter.minSdkVersion` (build.gradle L27, L41),
  `multiDexEnabled = true` (L45), release con `minifyEnabled` (L51-53).
- `android:hardwareAccelerated="true"` en la activity (Manifest L25).

### `lib/main.dart` (107 líneas)

- Home = `YachayScaffold` (L101-103) — **no hay pantalla de descarga/verificación
  del modelo previa al chat** (a diferencia de gemma-vision con `ModelDownloadPage`).

### Tests existentes (`test/`)

- `test/modules/gemma/flutter_gemma_service_test.dart` (378 líneas): gates,
  singleton, fallback sin modelo, legacy, `dispose()` seguro. **Mockea el canal
  `flutter_gemma`** (L53-59: `createModel` → false).
- `test/modules/gemma/streaming_test.dart`: `MessageStats` + streaming con canal
  `gemma_engine_stream` (legacy).
- `test/modules/gemma/tool_registry_test.dart`: 6 tools + handlers + idempotencia.
- `test/modules/gemma/action_parser_test.dart` (~50 tests XML) y
  `fallback_dispatcher_test.dart` (4 capas), `mobile_model_test.dart`,
  `oom_recovery_test.dart` (compat stub).
- `test/modules/yachay/yachay_integration_test.dart` + `yachay_ui_test.dart`:
  **4 fallas conocidas** ("1° Sec" no encontrado ×2, `pumpAndSettle timed out` ×2).

## El cambio previo: `openspec/changes/flutter-gemma-migration/`

`tasks.md` marca TODO como `[x]` pero la realidad del código desmiente varias tareas:

| Prometido | Estado real | Evidencia |
|---|---|---|
| 1.2: crear `model_download_service.dart` con OAuth download wrapper | ❌ **NO existe** — nunca se implementó | `lib/modules/gemma/` no contiene ese archivo |
| 1.2: agregar `flutter_web_auth_2` a pubspec | ❌ **NO está** | `pubspec.yaml` L10-19 |
| 2.3: eliminar `action_parser.dart` + `grammar_builder.dart` | ❌ **Siguen existiendo y en uso** | imports en `gemma_service.dart` L21-22; `buildGrammar()` L673 |
| 2.2: reescribir `gemma_service.dart` con FlutterGemmaPlugin | ✅ Implementado | L105-236 |
| 2.3: `tool_registry.dart` con `toFlutterGemmaTools()` | ✅ Implementado | L137-145 |
| 3.x: eliminar native (cpp/, GemmaEngine.kt, CMake) | ✅ Implementado | build.gradle sin externalNativeBuild |
| 4.x: tests + build | ✅ 209 pass / 4 fail, APK debug OK | verificado hoy |

El `design.md` prometió un "Model Download Flow" con `flutter_web_auth_2` PKCE,
verificación SHA256 y `setModelPath` (L35-43) — **nunca llegó al código**. Este
cambio `gemma4-runtime` retoma exactamente esa deuda, con la diferencia de que ya
no hay Gemma 3n como fallback: el download/verificación es **requisito**, no
opción.

Conclusión: el tasks.md del cambio previo NO es fuente confiable de verdad — el
código sí. Para la propuesta de este cambio, no reutilizar las tasks del anterior.

## Referencia gemma-vision — qué adaptar y qué NO copiar

### Adaptar tal cual (con cambios de identidad)

- **`huggingface_oauth.dart`** (120 líneas): flujo OAuth 2.0 + PKCE completo
  (code_verifier/challenge S256, generateAuthUrl, exchangeCodeForToken). Requiere
  `crypto` + `http` + `shared_preferences`. **Cambiar** `hfClientId` (hoy es el de
  tommasogiovannini, `constants.dart` L4) y `hfRedirectUri` (L5) por los de
  Aprendo+ (`com.aprendoplus.app://oauthredirect`).
- **`token_manager.dart`** (59 líneas): TokenStatus notStored/expired/valid +
  persistencia. Reusable tal cual.
- **`download_logic.dart`** (706 líneas): `checkIfModelExists()` (archivo > 0
  bytes, L49-79), `startDownload()` → `checkModelAccess()` (HEAD con Bearer,
  `download_manager.dart` L54-71) → OAuth → descarga, `monitorDownload()`
  (Timer 1s). **Adaptar**: quitar navegación automática a ChatPage, UI en español,
  y reemplazar el flujo por `installModel()` nativo de 1.4.2 si se prefiere.
- **`bootstrap_manager.dart`** (252 líneas): flags globales anti-deadlock
  (`_globalBootstrapping` + Completer + timeout 30s, L43-73), orden de init con
  checks de lifecycle. **Adaptar simplificado**: Aprendo+ no tiene TTS/OCR/speech;
  el bootstrap se reduce a: verificar modelo → (descargar) → `init(backend)`.
- **`gemma_vision_chat.dart`** L49: `PreferredBackend _backend =
  PreferredBackend.cpu;` — **CPU por defecto** ✅ (el usuario lo quiere).
- **`settings_page.dart`** (L461-547): selector CPU/GPU toggle — opcional, solo si
  se quiere exponer el backend al usuario.
- **`model_download_page.dart`**: UI con estados checkingAccess → authenticating →
  awaitingLicenseAcceptance → downloading → completed. Adaptar a español y a la
  navegación de Aprendo+.

### Cambiar / NO copiar

- **`gemma_service.dart` de la referencia** (168 líneas): `init(backend)` por
  parámetro es el patrón correcto, PERO:
  - ⚠️ **Trampa del selector backend por idempotencia de init**: L24
    `if (_initialised) return;` — cambiar de backend sin `dispose()` NO recrea el
    modelo. En la referencia, `_navigateToSettings` llama `BootstrapManager.reset()`
    + `_bootstrap()` (gemma_vision_chat.dart L321-327) pero `_initialised` del
    servicio no se resetea → el switch de backend es un **bug latente** de la
    referencia. En Aprendo+ hay que decidir: (a) backend fijo CPU por defecto sin
    selector (recomendado para hackathon), o (b) si hay selector, `dispose()` real
    del servicio antes de re-init con el nuevo backend.
  - ⚠️ **`dispose()` con `deleteModel()`** (referencia L161-167): borra el modelo
    instalado del dispositivo → obligaría a re-descargar 2.6 GB. **NO copiar**: el
    `dispose()` actual de Aprendo+ (solo `close()`) es correcto.
- **`download_manager.dart`** (321 líneas):
  - ❌ **`_cleanupModelFiles()`** (L259-285): borra CUALQUIER archivo del directorio
    de documentos cuyo nombre contenga `gemma`/`model` o tenga extensión
    .gguf/.bin/.safetensors/.pt/.pth. En Aprendo+ el directorio de documentos
    contiene la **DB sqflite sqlcipher del estudiante** — riesgo de pérdida de
    datos. **NO copiar**.
  - ❌ `cancelAndDeleteDownload()` (L172-222): misma limpieza nuclear. NO copiar.
  - Depende de `flutter_downloader` + `permission_handler` + aislados —
    complejidad innecesaria si se usa `installModel()` nativo de 1.4.2.
- **`constants.dart`**: los client_id/redirect_uri de la referencia son del autor
  (L4-5) — no usarlos para Aprendo+.

## Gemma 4 E2B `.litertlm` — disponibilidad y requisitos

### Hallazgo crítico: versión de flutter_gemma

| Capacidad | `flutter_gemma` 0.10.6 (actual) | `flutter_gemma` 1.4.2 (cache local) |
|---|---|---|
| `ModelType.gemma4` | ❌ NO existe (`general, gemmaIt, deepSeek, qwen, llama, hammer`) | ✅ Existe — "Gemma 4 E2B/E4B with native function calling tokens" |
| `ModelFileType.litertlm` | ❌ NO existe (solo `task`, `binary`) | ✅ Existe — ".litertlm files - LiteRT-LM SDK handles templates on Android" |
| `FlutterGemma.installModel(...).fromNetwork(url, token)` | ❌ NO existe | ✅ Existe (idempotente, `withProgress`, `withCancelToken`, `foreground` auto >500MB) |
| `PreferredBackend` | cpu/gpu | cpu/gpu/**npu** |
| Streaming | `generateChatResponseAsync()` → `Stream<ModelResponse>` | `getResponseAsync()` → `Stream<String>` (ROM pre API) |
| `createChat` | temperature/topK/topP/tools/supportsFunctionCalls | + `systemInstruction`, `toolChoice`, `maxOutputTokens`, `isThinking`, `modelType` |
| `activeBackend` (backend real tras fallback) | ❌ | ✅ getter en `InferenceModel` |

**Conclusión**: el upgrade 0.10.6 → 1.4.2 es obligatorio para Gemma 4. Es viable:
1.4.2 exige Dart `>=3.12.0` y Flutter `>=3.44.0`; el proyecto tiene Dart 3.12.2 /
Flutter 3.44.8 (verificado en pubspec de 1.4.2 L18-19 y en el entorno). El riesgo
es que rompe la capa de inferencia y los tests que mockean el canal `flutter_gemma`.

### Modelo

- **Repo**: `litert-community/gemma-4-E2B-it-litert-lm` (HuggingFace).
- **Archivo**: `gemma-4-E2B-it.litertlm` — **2.59 GB** (almacenado con Xet; la
  página del file dice "Size of remote file: 2.59 GB"). También existe
  `gemma-4-E2B-it_Google_Tensor_G5.litertlm` (optimizado Tensor G5, Pixel).
- **Licencia**: base Apache-2.0 (`google/gemma-4-E2B-it`), pero el acceso al repo
  litert-community es **gated** → requiere login HF + aceptación → flujo OAuth
  (o token HF pegado por el usuario).
- **API objetivo** (1.4.2):
  ```dart
  await FlutterGemma.installModel(
    modelType: ModelType.gemma4,
    fileType: ModelFileType.litertlm,
  ).fromNetwork(downloadUrl, token: hfToken).install();
  ```
- **Contexto mínimo**: `.litertlm` requiere `maxTokens >= 1024` en `createModel`
  (clamp automático, ver doc en `flutter_gemma_interface.dart` L49-52); el actual
  de Aprendo+ usa 8192 (gemma_service.dart L220) — correcto.
- **Fallback GPU→CPU**: documentado; el runtime hace fallback interno y
  `activeBackend` expone el backend final — útil para el estado visible en la UI.
- **Riesgo de RAM**: 2.59 GB en disco + memoria de runtime; LiteRT-LM memory-maps
  los embeddings (los mantiene en disco, solo carga fracciones). En teléfonos de
  2 GB RAM el backend CPU (XNNPack) es más predecible que GPU.

## Approaches

### 1. Upgrade a flutter_gemma 1.4.2 + `installModel()` nativo + CPU default + estado visible

Adoptar la API moderna: `ModelType.gemma4` + `ModelFileType.litertlm` +
`installModel().fromNetwork(url, token)`; backend CPU por defecto (opción GPU en
settings opcional); verificación de archivo (tamaño/checksum) antes de `createModel`;
estado de modelo visible en el chip; fallback solo como modo degradado sin IA
(no es un modelo Gemma alternativo). OAuth HF reutilizando el patrón PKCE de la
referencia con credenciales propias.

- Pros: única vía que soporta Gemma 4 `.litertlm`; descarga gestionada por el plugin
  (idempotente, progreso, cancelación, foreground service); menos dependencias
  nuevas; alineado con la decisión del usuario y con el patrón de la referencia.
- Cons: upgrade rompe API (reescritura de la capa de inferencia + tests); requiere
  verificación en dispositivo real; depende de OAuth HF (gating).
- Effort: **High** (upgrade + reescritura + download flow + UI estado + TDD).

### 2. Mantener flutter_gemma 0.10.6 y cargar el `.litertlm` como archivo externo

Seguir con el patrón actual (setModelPath + createModel con `ModelType.gemmaIt`)
apuntando al archivo `gemma-4-E2B-it.litertlm` sideloaded, sin `installModel`.

- Pros: mínimo cambio en gemma_service.dart.
- Cons: **inviable**: 0.10.6 no tiene `ModelType.gemma4` ni `litertlm`; el runtime
  MediaPipe de 0.10.x no puede interpretar `.litertlm` (es formato LiteRT-LM FFI);
  además la decisión del usuario exige Gemma 4 real, no un modelo cargado con tipo
  equivocado.
- Effort: N/A — descartado por viabilidad técnica.

### 3. Descarga con flutter_downloader (patrón gemma-vision completo)

Copiar download_page tal cual: flutter_downloader + isolate + permission_handler +
OAuth + DownloadStateManager.

- Pros: UI/estado de descarga ya probada en la referencia (pausa/reanuda/cancelar).
- Cons: 4+ dependencias nuevas; limpieza de archivos nuclear peligrosa (borraría la
  DB del estudiante); el plugin ya ofrece descarga nativa en 1.4.2; más superficie
  de mantenimiento. Solo se justifica si se quiere pausa/reanudación granular.
- Effort: **High** (mayor que la opción 1 por dependencias extra).

## Recommendation

**Opción 1**, con este desglose:

1. **Upgrade `flutter_gemma` a 1.4.2** (pin exacta `flutter_gemma: 1.4.2`) — PR
   separado si el diff excede el budget de 400 líneas (auto-chain).
2. **Reescritura de la capa de inferencia**: `ModelType.gemma4` +
   `ModelFileType.litertlm`, `createChat` con `systemInstruction` (prompt Yachay
   en español peruano), `maxOutputTokens` para acotar respuestas, streaming con
   `getResponseAsync()`.
3. **Model download/verification service** (`lib/modules/gemma/model_download_service.dart`
   — la deuda del cambio previo): `installModel().fromNetwork(url, token)` con
   OAuth PKCE propio (`com.aprendoplus.app`), verificación de archivo
   (tamaño ~2.59 GB y/o SHA256) antes de `createModel`, manejo de "app desinstalada
   → modelo borrado → re-descarga" (aceptado por el usuario).
4. **Backend CPU por defecto**, sin hardcodear GPU; selector GPU/NPU solo si sobra
   tiempo (si se incluye: `dispose()` real antes de re-init — evitar la trampa de
   idempotencia de la referencia).
5. **Estado de modelo visible** en el chip de `yachay_scaffold.dart` (no "Offline"
   genérico): `Sin modelo` → `Descargando X%` → `Verificando` → `Listo (CPU)` →
   `Error`, usando `activeBackend` cuando esté disponible.
6. **Bootstrap robusto** simplificado del patrón `BootstrapManager` (sin
   TTS/OCR): verificar antes del chat, timeout anti-deadlock, error recovery con
   mensaje claro.
7. **Fallback solo como modo degradado sin IA** (mantener `FallbackDispatcher` y
   `fallback_responses.json` como modo offline de la app, NO como modelo Gemma
   alternativo). Gemma 3n y legacy MethodChannel se eliminan o quedan fuera del
   camino principal (decidir en proposal: borrar `_cargarModeloLegacy` y los gates
   `useFlutterGemma`/`useXmlDispatch` o dejarlos como deuda).
8. **TDD** (el usuario lo pidió explícitamente; `openspec/config.yaml` tiene
   `strict_tdd: true`): seams sugeridos — (a) model download service (verifica →
   descarga → verifica → instala; fallos → degradado), (b) `GemmaService.init` con
   backend configurable, (c) estado visible (widget test del chip), (d) streaming
   con `getResponseAsync` mockeado.

## Risks

| Riesgo | Severidad | Likelihood | Mitigación |
|---|---|---|---|
| Upgrade flutter_gemma 0.10.6 → 1.4.2 rompe API (getResponseAsync, createChat, canal nativo, `Tool` signature) | **Alta** | Alta | Pin exacta; tests de contrato por seam; verificación en dispositivo real; PR separado para el upgrade |
| Modelo 2.59 GB gated en HF (OAuth/licencia) — sin token no hay IA | **Alta** | Alta | Flujo OAuth PKCE propio + opción de pegar token HF manualmente; documentar gating en la pantalla de descarga |
| RAM/disco en gama baja (2 GB mín.): 2.59 GB + runtime LiteRT-LM | **Alta** | Media | CPU default (XNNPack); verificar `maxTokens` (>=1024); pruebas en el WDY LX3 real |
| `_cleanupModelFiles()`/`cancelAndDeleteDownload()` de la referencia borraría la DB sqflite del estudiante | **Alta** | — (si se copia) | NO copiar la limpieza nuclear; borrar solo el archivo del modelo con nombre exacto conocido |
| `dispose()` con `deleteModel()` de la referencia fuerza re-descarga | **Media** | — (si se copia) | Mantener `dispose()` actual (solo `close()`); eliminar modelo solo con acción explícita del usuario |
| Trampa de idempotencia del selector backend (referencia: `if (_initialised) return`) | **Media** | Media | Si hay selector: `dispose()` real + re-init; si no, backend fijo CPU documentado |
| Xet storage de HF (URL de descarga especial) | **Media** | Baja | Usar URL `resolve/main/{file}?download=true` o la API de installModel; probar descarga real |
| minSdk/ABI: LiteRT-LM FFI puede exigir minSdk > actual o ABI arm64 | **Media** | Media | Verificar requisitos del plugin 1.4.2 (AndroidManifest/build.gradle); testear build APK |
| OAuth deep link: falta `intent-filter` para el callback | **Media** | Alta | Agregar intent-filter con scheme `com.aprendoplus.app` en AndroidManifest |
| Baseline de tests con 4 fallas conocidas (Yachay) — no asumir verde | **Baja** | Alta | Mantener el baseline documentado; no mezclar fixes de Yachay en este cambio |

## Ready for Proposal

**Yes.** Evidencia suficiente:

- El usuario ya decidió: Gemma 4 SOLO (no Gemma 3n baseline/fallback), patrón
  gemma-vision, CPU default, re-descarga tras desinstalación, fallback educativo
  solo como modo degradado, TDD obligatorio, preflight `interactive` +
  `auto-chain` + review budget 400 líneas.
- El cambio previo demostró que tasks.md no es confiable: el download service
  prometido no existe; este cambio lo retoma.
- La API correcta requiere upgrade a 1.4.2 (verificado en pub cache) — comunicar al
  usuario en la propuesta como decisión de impacto.

### Para la fase proposal

- Confirmar el upgrade `flutter_gemma` 1.4.2 (impacto de API) como decisión ADR.
- Definir si el token HF se obtiene por OAuth PKCE en la app o por pegado manual
  (menos fricción para hackathon).
- Decidir el destino de la deuda legacy: eliminar `_cargarModeloLegacy`, gates
  `useFlutterGemma`/`useXmlDispatch`, `action_parser.dart`, `grammar_builder.dart`
  y el GGUF (decisión de alcance).
- Elegir si el selector GPU/NPU entra en alcance o se fija CPU (recomendado: CPU
  fijo, GPU/NPU fuera de alcance).
- Plan de TDD con seams acordados y tests de contrato para el upgrade 1.4.2.
- Rollback: git (todo el cambio es reversible); el modelo es externo, no versionado.
