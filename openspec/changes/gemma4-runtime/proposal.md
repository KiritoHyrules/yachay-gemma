# Proposal: gemma4-runtime

## Intent

Migrar Aprendo+ a **Gemma 4 E2B IT real on-device** (`.litertlm`, LiteRT-LM) vía `flutter_gemma` 1.4.2: instalación/verificación del modelo antes del chat, estado de modelo visible (no "Offline" genérico), backend CPU fijo, OAuth PKCE de HuggingFace con token manual como respaldo. Cierra la deuda del cambio `flutter-gemma-migration` (download service prometido, nunca creado) y elimina el legacy MethodChannel/GGUF.

## Scope

### In Scope
- Upgrade `flutter_gemma` 0.10.6 → **1.4.2** (pin exacta; rompe API — PR aislado).
- `ModelDownloadService` nuevo: `installModel(...).fromNetwork(url, token)` idempotente + verificación de archivo (tamaño ~2.59 GB / SHA256) antes de `createModel`.
- OAuth PKCE HF propio (`com.aprendoplus.app://oauthredirect`) + token manual como respaldo.
- Estado de modelo visible en `yachay_scaffold.dart`: Sin modelo → Descargando X% → Verificando → Listo (CPU) → Error (`activeBackend`).
- Backend **CPU fijo** (default); sin hardcodear GPU.
- Eliminar legacy: MethodChannel/GGUF, gates `useFlutterGemma`/`useXmlDispatch`, `action_parser.dart`, `grammar_builder.dart`, `_cargarModeloLegacy`.
- Bootstrap robusto previo al chat (timeout anti-deadlock, error recovery claro).
- TDD: seams download service, init con backend, chip de estado, streaming `getResponseAsync`.

### Out of Scope
- Selector GPU/NPU (CPU fijo). Gemma 3n como baseline/fallback (FUERA).
- `FallbackDispatcher`/`fallback_responses.json`: se conservan solo como **modo degradado sin IA**, no modelo alternativo.
- NO copiar de la referencia: `dispose()` con `deleteModel()` ni limpieza nuclear de archivos (borrarían la DB sqflite del estudiante).
- Fix de las 4 fallas Yachay del baseline; cambios de DB/keystore.

## Capabilities

### New Capabilities
- `gemma-model-download`: descarga/verificación/instalación del `.litertlm` gated (installModel nativo + OAuth PKCE + token manual + progreso).
- `gemma-model-status`: estado de modelo visible (instalado/descargando/verificando/error/backend activo).

### Modified Capabilities
- `ai-streaming`: `generateChatResponseAsync()` (0.10.x) → `getResponseAsync()` (1.4.2, `Stream<String>`); `createChat` con `systemInstruction`, `maxOutputTokens`, `toolChoice`.
- `ai-tool-dispatcher`: XML dispatch + parser/grammar → tool calling nativo (`FunctionCallResponse`), 13 tools.
- `ai-fallback`: reformulada como modo degradado sin IA (no modelo alternativo).

## Approach

1. **Upgrade aislado**: `flutter_gemma: 1.4.2` + reescritura de inferencia + tests de contrato (PR propio si >400 líneas → auto-chain).
2. **Download/verificación**: `ModelDownloadService` con installModel nativo (idempotente, progreso, foreground auto) + OAuth PKCE + token manual; verificación antes de `createModel`.
3. **Bootstrap**: verificar → descargar si falta → `init(backend: cpu)`; estados expuestos al chip.
4. **Legacy removal**: borrar gates, parser, grammar, GGUF/MethodChannel.
5. **TDD** por work unit (tests con el código).

## Impact

- **Dependencias**: `flutter_gemma: 1.4.2` + `flutter_web_auth_2`, `http`, `crypto`, `shared_preferences` (token/OAuth). Sin `flutter_downloader`/`permission_handler` (installModel nativo).
- **Impacto usuario**: primera vez descarga 2.59 GB (gated); re-descarga tras desinstalar (aceptado); APK + superficie de arranque.
- **Decisiones ADR**: upgrade 1.4.2 (obligatorio: `ModelType.gemma4`/`litertlm`/`installModel` no existen en 0.10.6 — verificado en pub cache); OAuth PKCE + token manual (gating HF); eliminar legacy ahora (sin camino dual; deuda del cambio previo); CPU fijo (predecible en 2 GB RAM).

## Affected Areas

| Area | Impact | Descripción |
|------|--------|-------------|
| `pubspec.yaml` | Modified | `flutter_gemma: 1.4.2` + OAuth deps |
| `lib/modules/gemma/gemma_service.dart` | Rewritten | API 1.4.2, CPU, sin legacy/gates |
| `lib/modules/gemma/model_download_service.dart` | New | Descarga + verificación |
| `lib/modules/gemma/huggingface_oauth.dart` | New | OAuth PKCE propio |
| `lib/modules/gemma/action_parser.dart` / `grammar_builder.dart` | Removed | Reemplazados por function calling nativo |
| `lib/modules/yachay/screens/yachay_scaffold.dart` | Modified | Chip de estado + bootstrap previo |
| `android/app/src/main/AndroidManifest.xml` | Modified | `intent-filter` `com.aprendoplus.app://oauthredirect` |
| `test/modules/gemma/*` | Modified | Tests de contrato 1.4.2, download, chip |

## Risks

| Riesgo | Sev | Mitigación |
|---|---|---|
| Upgrade 1.4.2 rompe API y tests que mockean el canal | Alta | Pin exacta; tests de contrato; PR separado; verificación en dispositivo real |
| Modelo 2.59 GB gated — sin token no hay IA | Alta | OAuth PKCE + token manual; gating documentado en UI |
| RAM/disco en gama baja (2 GB) | Alta | CPU default (XNNPack); `maxTokens >= 1024`; pruebas en WDY LX3 |
| Copiar limpieza nuclear de la referencia borraría la DB del estudiante | Alta | NO copiar; borrar solo archivo de modelo con nombre exacto |
| minSdk/ABI LiteRT-LM FFI; deep link OAuth | Media | Verificar requisitos plugin 1.4.2; `intent-filter` en Manifest; testear APK |

## Rollback Plan

- Git: cada work unit es un commit/PR reversible; el modelo es externo (no versionado).
- El upgrade 1.4.2 va en PR propio: revertir restaura 0.10.6 y el camino actual.
- `dispose()` mantiene solo `close()` — no borra el modelo; re-descarga solo tras desinstalar (aceptado).
- Legacy eliminado recuperable desde git (sin rama de respaldo).

## Dependencies

- `flutter_gemma: 1.4.2` (pub.dev); `flutter_web_auth_2`, `http`, `crypto`, `shared_preferences`.
- Modelo: `litert-community/gemma-4-E2B-it-litert-lm` (gated, 2.59 GB, Xet).
- Requisitos cumplidos: Dart 3.12.2 / Flutter 3.44.8 (1.4.2 exige >=3.12.0 / >=3.44.0).

## Success Criteria

- [ ] `flutter test`: baseline 209 + nuevos tests de contrato 1.4.2 en verde; 4 fallas Yachay sin empeorar
- [ ] `flutter build apk --debug` OK con 1.4.2
- [ ] WDY LX3: descarga → verificación → `Listo (CPU)` → chat con Gemma 4 real
- [ ] Sin token: OAuth PKCE o token manual; error claro si ambos fallan
- [ ] Sin modelo: modo degradado educativo, nunca crash
- [ ] `action_parser.dart`, `grammar_builder.dart`, gates y GGUF/MethodChannel: grep = 0
- [ ] Reinstalación → re-descarga del modelo (aceptado)

## Size Estimate

**HIGH**: upgrade API + reescritura + download flow + UI estado + tests ≈ **900–1200 líneas** > 400 → **auto-chain** (PRs: 1 upgrade API, 2 download/OAuth, 3 UI estado + legacy removal). Non-goals: selector backend, Gemma 3n, pausa/reanudación granular, fix Yachay.
