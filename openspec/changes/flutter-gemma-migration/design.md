# Design: flutter-gemma-migration

## Technical Approach

Replace MethodChannel/Kotlin/JNI/llama.cpp engine (~5000 vendored C++ files) with Google's `flutter_gemma: ^0.10.0`. Follow reference pattern from `Proyecto referencia/gemma-vision/lib/chat_page/services/gemma_service.dart`. Feature-gate `useFlutterGemma` for staged rollout; Gemma 3n .task primary, Gemma 4 .litertlm stretch via OAuth.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Plugin pattern | `GemmaService._internal()` singleton — same as reference gemma-vision | Matches `FlutterGemmaPlugin.instance` API; proven in reference |
| Model format | Gemma 3n E2B .task (primary), Gemma 4 .litertlm (stretch via OAuth) | Gemma 3n ungated & proven; Gemma 4 gated — OAuth download path |
| Tool adaptation | `ToolRegistry.toFlutterGemmaTools()` → `List<Tool>` passed to `createChat(tools:, supportsFunctionCalls: true)` | Native parsing replaces custom ActionParser + GrammarBuilder; handlers unchanged |
| Streaming | `generateChatResponseAsync().listen()` replacing EventChannel handler | True async streaming; eliminates ANR on main thread |
| OOM recovery | REMOVE `_recoverFromOom`, `_purgeOldCheckpoints`, `oom_checkpoints.db` | MediaPipe handles memory natively |
| Legacy preservation | `legacy-llamacpp` git branch + `useFlutterGemma=false` gate | One-flag rollback; zero data migration |

## Data Flow

```
User message → GemmaService.procesarMensaje()
  ├─ useFlutterGemma? ──Yes→ FlutterGemmaPlugin.instance
  │   ├─ createModel(backend, gemmaIt, maxTokens: 1024)
  │   ├─ createChat(temperature: 0.4, topK: 64, topP: 0.85,
  │   │             tools: registry.toFlutterGemmaTools(),
  │   │             supportsFunctionCalls: true)
  │   ├─ chat.addQuery(Message.text(userMessage))
  │   └─ chat.generateChatResponseAsync().listen((res) {
  │       ├─ TextResponse → onToken(res.token)
  │       └─ FunctionCallResponse → tool_registry.run() → addQuery(result)
  │     })
  └─ No → legacy MethodChannel (llama.cpp) — preserved on git branch
```

### Model Download Flow

```
ModelDownloadService.downloadIfNeeded()
  ├─ FlutterGemma.modelManager.isModelInstalled? ──Yes→ skip
  └─ No → HF OAuth PKCE via flutter_web_auth_2
       → token exchange → installModel().fromNetwork(url, token)
       → SHA256 verify → setModelPath() OR retry×1 → fallback
```

## File Changes

| File | Action | Lines |
|------|--------|-------|
| `pubspec.yaml` | Modify | +2 deps |
| `android/app/build.gradle` | Modify | -3 blocks (CMake, aaptOptions, abiFilters) |
| `android/.../MainActivity.kt` | Modify | -11 lines (GemmaEngine) |
| `android/.../GemmaEngine.kt` | Delete | -576 lines |
| `android/app/src/main/cpp/` | Delete | -5000+ files |
| `lib/modules/gemma/gemma_service.dart` | Rewrite | 1049→~300 lines |
| `lib/modules/gemma/model_download_service.dart` | Create | +~80 lines |
| `lib/modules/gemma/tool_registry.dart` | Modify | +~30 lines (toFlutterGemmaTools) |
| `lib/modules/gemma/action_parser.dart` | Delete | -350 lines |
| `lib/modules/gemma/grammar_builder.dart` | Delete | -25 lines |
| `lib/modules/gemma/fallback_dispatcher.dart` | Modify | -~15 lines (move registry init out) |

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit — init | Plugin init, model creation, chat session | mock FlutterGemmaPlugin, verify createModel/createChat called |
| Unit — stream | Tokens arrive via generateChatResponseAsync | mock stream with TextResponse, verify onToken callbacks |
| Unit — tools | toFlutterGemmaTools() returns 13 Tool objects | verify Tool(functionName, description, parameters) for each spec |
| Unit — fallback | 4-layer dispatcher still works without model | dispatch("hola") → Layer 1 greeting |
| Integration | `flutter build apk --debug` | zero CMake refs, APK <50MB |
| E2E — gate | useFlutterGemma=false routes to legacy | test returns fallback response, no plugin call |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

- **Feature gate**: `static bool useFlutterGemma = true` in GemmaService
- **Rollback**: `useFlutterGemma = false` → legacy MethodChannel path (preserved on `legacy-llamacpp` branch)
- **Cleanup**: Post-hackathon verification → delete feature gate + legacy branch

## Open Questions

- [ ] Can `flutter_gemma ^0.10.0` compile with current Flutter SDK (^3.5.0)?
- [ ] Does `flutter_web_auth_2 ^4.1.0` require minSdkVersion bump for OAuth PKCE?
- [ ] Confirm `google/gemma-3n-E2B-it-litert-preview` .task model URL for non-gated download
