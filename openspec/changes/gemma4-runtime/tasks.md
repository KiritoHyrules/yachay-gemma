# Tasks: gemma4-runtime — Gemma 4 E2B IT on-device (flutter_gemma 1.4.2)

> Contexto pipeline: delivery `auto-chain`, chain `feature-branch-chain`. Repo `master` SIN commits (todo untracked): PR1a crea la primera commit; el tracker acumula integración y mergea a main. Baseline `flutter test`: 209 pass / 4 fail conocidos (no asumir verde). Verificado en pub cache 1.4.2: `createModel`/`modelManager` sobreviven (interface L36/L67) → el pin compila sin reescribir el service; `getResponseAsync()`→`Stream<String>` (L478); `InferenceChat.generateChatResponseAsync()`→`Stream<ModelResponse>` (chat.dart L254) parsea `lastRawResponse`→`FunctionCallResponse`.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~2,300–2,700 total: PR1a ~450 · PR1b ~800 (deletion-heavy) · PR2 ~900 · PR3 ~450 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1a → PR1b → PR2 → PR3 (4 slices; PR1 sub-dividido por rewrite de 897 líneas — decisión delegada a sdd-tasks, design Open Q#3) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

> Nota: PR1b y PR2 exceden 400 aun divididos (rewrite 897 líneas / ~6 archivos nuevos + 3 suites). PR1b es deletion-heavy (legacy muerto + mocks de canal) → bajo load de review; PR2 son unidades atómicas → apply puede promover a PR2a/PR2b en la misma cadena si el diff real confirma; `size:exception` solo si el mantainer lo acepta.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| U1 | Pin 1.4.2 + seam `GemmaInferenceAdapter` + fake/tests | PR1a | `& "C:\flutter\bin\flutter.bat" test test/modules/gemma/gemma_inference_adapter_test.dart` | `flutter run -d AXLKCP4515402262` smoke: app lanza con pin | revert pubspec pin + delete adapter/fake/tests |
| U2 | Rewrite `GemmaService` 1.4.2 (cpu, dispatch 7 rondas, streaming, timeout 30s) + contract/dispatch tests | PR1b | `& "C:\flutter\bin\flutter.bat" test test/modules/gemma/gemma_142_contract_test.dart test/modules/gemma/dispatch_native_test.dart` | device smoke: degradado sin modelo (inferencia real post-PR2) | revert gemma_service.dart (PR1a intacto) |
| U3 | `ModelStatusController` + tests | PR2 | `& "C:\flutter\bin\flutter.bat" test test/modules/gemma/model_status_test.dart` | N/A (ValueNotifier puro, widget test directo) | delete model_status.dart + test |
| U4 | `ModelDownloadService` + installer seam + integridad + tests | PR2 | `& "C:\flutter\bin\flutter.bat" test test/modules/gemma/model_download_service_test.dart` | WDY LX3 manual: descarga real 2.59 GB | delete archivos nuevos + revert manifest/pubspec |
| U5 | OAuth PKCE + `TokenStore` + tests | PR2 | `& "C:\flutter\bin\flutter.bat" test test/modules/gemma/huggingface_oauth_test.dart test/modules/gemma/token_store_test.dart` | WDY LX3 manual: flujo OAuth completo | delete oauth/token_store + revert deps |
| U6 | Chip de estado + bootstrap `yachay_scaffold` | PR3 | `& "C:\flutter\bin\flutter.bat" test test/modules/yachay/yachay_chip_test.dart test/modules/yachay/yachay_degraded_test.dart` | WDY LX3: chip estados en vivo | revert scaffold |
| U7 | Legacy removal + reframe fallback | PR3 | grep=0 repo-wide (ver 4.6) + `flutter test` | N/A (deletion/docs) | git restore archivos borrados |

## Phase 1 — PR1a: upgrade API + seam de inferencia (base = feature/tracker branch)

- [x] 1.1 [AI] Pin: `pubspec.yaml` → `flutter_gemma: 1.4.2` (exacta) + `flutter pub get`. Aceptación: lock 1.4.2; `flutter analyze` sin errores nuevos (createModel legacy compila). Dep: —
- [x] 1.2 [AI] Crear `lib/modules/gemma/gemma_inference_adapter.dart`: abstract `GemmaInferenceAdapter` + impl real — `loadModel({maxTokens:8192})`→`getActiveModel(backend: cpu)`, `createChat({systemInstruction, maxOutputTokens, List<Tool> tools})`, `streamResponse()`→`session.getResponseAsync()`, `streamChatResponse()`→`chat.generateChatResponseAsync()`, `activeBackend`, `close()` (firmas design L175-183). Dep: 1.1.
- [x] 1.3 [AI] RED→GREEN: `test/modules/gemma/fakes/gemma_inference_adapter_fake.dart` + `test/modules/gemma/gemma_inference_adapter_test.dart` (compile-contract del seam: firmas, backend cpu, fake emite `Stream<String>`/`Stream<ModelResponse>`). Aceptación: `flutter test test/modules/gemma/gemma_inference_adapter_test.dart` verde. Dep: 1.2.
- [x] 1.4 [VERIFY] Aceptación PR1a: `flutter build apk --debug` OK; smoke device (app lanza con pin 1.4.2, GemmaService legacy intacto). Dep: 1.3.

## Phase 2 — PR1b: reescritura GemmaService (base = rama PR1a)

- [x] 2.1 [AI] RED: `test/modules/gemma/gemma_142_contract_test.dart` (fake adapter): `cargarModelo()`→loadModel(cpu)+`createChat`(systemInstruction, maxOutputTokens≥1024, toolChoice.auto, 13 tools); `sendWithStreaming` consume `Stream<String>`→onToken(throttle 3)+onComplete(`MessageStats`); timeout 30s inyectable corta con stats parciales; sin modelo→degradado tokenCount=0 (REQ-01/02 ai-streaming). Dep: 1.3. ✅ 5 tests verdes; `TestWidgetsFlutterBinding.ensureInitialized()` para cargar el asset de fallback real.
- [x] 2.2 [AI] RED: `test/modules/gemma/dispatch_native_test.dart`: ronda única resuelve (single tool); multi-tool ≤7 rondas; ronda 7 fuerza texto final; checkpoint persiste `student_mastery` (REQ-01/03/04 ai-tool-dispatcher). Dep: 2.1. ✅ 6 tests verdes; el fake gana `setChatResponseQueue`/`addedQueries`/`streamChatResponseCalls`; `setToolContext` inyecta el studentState duck-typed.
- [x] 2.3 [AI] GREEN: reescribir `gemma_service.dart` (897→~560): init `getActiveModel(maxTokens:8192, backend:cpu)` (enableSpeculativeDecoding: null), bucle nativo 7 rondas con `chat.generateChatResponseAsync()` (parsea `lastRawResponse`→`FunctionCallResponse`), `sendWithStreaming` con `session.getResponseAsync()`, timeout 30s inyectable, degradado en todo fallo, `dispose()` solo `close()`; ELIMINAR gates `useFlutterGemma`/`useXmlDispatch`, `_cargarModeloLegacy`, `_sendWithStreamingLegacy`, MethodChannel. Dep: 2.1, 2.2. ✅ Añadido `addQuery(Message)` al seam (el bucle necesita alimentar el chat); `streamResponse()` real lee de `chat.session` (la misma sesión que recibe el addQuery). `setToolContext()` preserva servicios a través de `_inicializarRegistry()`. `yachay_scaffold.dart` L43-44 y `main.dart` L17 sin referencias a gates/devMode.
- [x] 2.4 [AI] REFACTOR: borrar `test/modules/gemma/flutter_gemma_service_test.dart`, `streaming_test.dart`, `mobile_model_test.dart` (mocks de canal legacy); `oom_recovery_test.dart` conservado y verde. Group 6 de `action_parser_test.dart` (gates legacy + MethodChannel) eliminado — el archivo se borra completo en PR3 (4.4). Aceptación PR1b: 2.1/2.2 verdes ✅; grep `useXmlDispatch|useFlutterGemma|MethodChannel|gemma_engine` = 0 en `lib/` ✅ (excepción documentada: `core/keystore/keystore_service.dart` L4 usa `MethodChannel('keystore')` — subsistema de cifrado de DB, fuera del alcance gemma4-runtime); `flutter test` 195 pass / 2 fail (los 2 = fallas Yachay pre-existentes "1° Sec", ninguna nueva) ✅; `flutter build apk --debug` OK ✅. Dep: 2.3.

## Phase 3 — PR2: descarga/OAuth/estado (base = rama PR1b)

- [x] 3.1 [AI] RED: `test/modules/gemma/model_status_test.dart`: transiciones SinModelo→Descargando X%→Verificando→Listo(CPU)→Error; `ready()` con fallback GPU→CPU → "Listo (CPU)" (REQ-01/02 gemma-model-status). Dep: —
- [x] 3.2 [AI] GREEN: `lib/modules/gemma/model_status.dart`: enum `ModelStatus`, `ModelStatusInfo(status/progressPercent/errorMessage/backendLabel)`, `ModelStatusController extends ValueNotifier` (downloading/verifying/ready/error/reset). Dep: 3.1.
- [x] 3.3 [AI] RED: `test/modules/gemma/model_download_service_test.dart` (fake installer/verifier/tokens/status): REQ-01 primera ejecución descarga 0→100; idempotente (instalado→skip); REQ-02 403→error accionable sin bucle; REQ-03 corrupto→`deleteCorruptFile` nombre exacto + reintento 1→degradado; REQ-04 sin espacio→error sin crash; REQ-06 limpieza acotada (nunca DB). Dep: 3.2.
- [x] 3.4 [AI] GREEN: `lib/modules/gemma/model_installer.dart`: `ModelInstaller` real — `FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm).fromNetwork(url, token).install()` + onProgress; `ModelIntegrityVerifier` (size ≈2.59 GB siempre; SHA256 `fullCheck` post-descarga — si no publicado en HF, calcular en device y persistir; `deleteCorruptFile` nombre exacto); enum `ModelDownloadFailure`. URL: `litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true`. Dep: 3.3.
- [x] 3.5 [AI] GREEN: `lib/modules/gemma/model_download_service.dart`: `ensureModelReady()` verify→download→verify→re-download 1 vez; feed `ModelStatusController`; `ModelDownloadResult`. Dep: 3.2, 3.3, 3.4.
- [x] 3.6 [AI] RED: `test/modules/gemma/huggingface_oauth_test.dart` + `token_store_test.dart`: PKCE S256 verifier/challenge; auth URL redirect `com.aprendoplus.app://oauthredirect`; exchange code→token; persistencia; token manual; ambas fallan→null→Error+degradado (REQ-02 gemma-model-download). Dep: —
- [x] 3.7 [AI] GREEN: `lib/modules/gemma/huggingface_oauth.dart` (`HuggingFaceOAuth implements TokenProvider`: generateAuthUrl/exchangeCodeForToken) + `lib/modules/gemma/token_store.dart` (`TokenStore`: read/write/clear shared_preferences) + pubspec: `flutter_web_auth_2: ^4.1.0`, `http`, `crypto`, `shared_preferences`. Dep: 3.6.
- [x] 3.8 [UI] `AndroidManifest.xml`: intent-filter VIEW scheme `com.aprendoplus.app` host `oauthredirect` en MainActivity (launchMode singleTop ya presente). Dep: 3.7.
- [x] 3.9 [VERIFY] Aceptación PR2: tests 3.1/3.3/3.6 verdes; revisar build.gradle plugin 1.4.2 (minSdk/ABI FFI); `flutter build apk --debug` OK; WDY LX3: descarga real + OAuth manual. Dep: 3.8.

## Phase 4 — PR3: UI + legacy (base = rama PR2)

- [x] 4.1 [UI] RED: `test/modules/yachay/yachay_chip_test.dart` (widget): chip muestra exactamente los 5 estados, nunca "Offline"; "Listo (CPU)" con activeBackend=cpu (REQ-01/02 gemma-model-status). Dep: 3.2. ✅ 5 tests verdes; seam `setFallbackDataForTest` en GemmaService evita rootBundle real en widget tests (fake-async hostil al IO).
- [x] 4.2 [UI] RED: `test/modules/yachay/yachay_degraded_test.dart` (widget): sin modelo → `FallbackDispatcher` responde sin crash; chip refleja estado real (REQ-03/04 gemma-model-status). Dep: 4.1. ✅ 2 tests verdes; mock de path_provider (MissingPluginException) hace el bootstrap acotado sin IO real.
- [x] 4.3 [UI] GREEN: `yachay_scaffold.dart` — chip L134-140 → `ValueListenableBuilder<ModelStatusInfo>`; bootstrap previo (ensureModelReady antes de chat, timeout anti-deadlock); quitar texto "Offline". Dep: 4.1, 4.2, 3.5. ✅ `YachayScaffold(gemmaService:)` inyectable; `_bootstrapModel()` → `bootstrapModelReady(timeout: 30s)`; `cargarModelo` alimenta `statusController.ready(activeBackend)`.
- [x] 4.4 [AI] Borrar legacy: `lib/modules/gemma/action_parser.dart`, `lib/modules/gemma/grammar_builder.dart`, `test/modules/gemma/action_parser_test.dart`; `system_prompt.dart` sin XML (tools como objetos `Tool`). Dep: 2.3. ✅ 3 archivos borrados; prompt reescrito sin formato XML de acción (invocación nativa); `yachay_tools_test.dart` expectation `<action`→`isNot(contains('<action'))`; grep legacy = 0.
- [x] 4.5 [AI] Reframe: `fallback_dispatcher.dart` — doc contrato "modo degradado sin IA" (sin cambio de comportamiento; capa 2 ya incluye keywords Yachay). Dep: 4.4. ✅ solo doc: "degraded (no-AI) mode", backbone offline-first, chip refleja estado real durante el modo degradado.
- [x] 4.6 [VERIFY] Aceptación PR3: `flutter test` (209+4 + nuevos verdes); grep repo-wide `action_parser|grammar_builder|useFlutterGemma|useXmlDispatch|MethodChannel|gemma_engine|GGUF|_cargarModeloLegacy` = 0; `flutter build apk --debug` OK; WDY LX3: chip en vivo. Dep: 4.3, 4.4, 4.5. ✅ `flutter test` 197 pass / 2 fail (mismas 2 "1° Sec" pre-existentes; −32 tests legacy +7 nuevos = 134→197); analyze 0 errores; grep=0 (excepción keystore MethodChannel documentada); APK OK; ⏸️ chip en vivo: dispositivo `AXLKCP4515402262` offline → diferido (no bloqueante).

## Dependencias y orden de ejecución

- Intra-PR: 1.1→1.2→1.3→1.4 · 2.1→2.2→2.3→2.4 · 3.1→3.2→3.5, 3.3→3.4→3.5, 3.6→3.7→3.8→3.9 · 4.1→4.2→4.3, 4.4→4.5→4.6.
- Inter-PR (feature-branch-chain): PR1a base = tracker; PR1b base = rama PR1a; PR2 base = rama PR1b; PR3 base = rama PR2; solo el tracker mergea a main. PR2 requiere PR1b (adapter/rewrite); PR3 requiere PR2 (status controller).
- Batches de apply: batch 1 = Phase 1 · batch 2 = Phase 2 · batch 3 = Phase 3 · batch 4 = Phase 4. `flutter test` completo y `flutter build apk --debug` al cierre de cada PR.
