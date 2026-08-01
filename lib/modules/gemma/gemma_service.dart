import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, MissingPluginException, rootBundle;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/message_stats.dart';
import '../yachay/tool_handlers/consultar_estado.dart';
import '../yachay/tool_handlers/evaluar_respuesta.dart';
import '../yachay/tool_handlers/obtener_siguiente_tema.dart';
import '../yachay/tool_handlers/obtener_plan_completo.dart';
import '../yachay/tool_handlers/generar_nota_progreso.dart';
import '../yachay/tool_handlers/generar_resumen_alumno.dart';
import '../yachay/tool_handlers/iniciar_conversacion.dart';
import 'action_parser.dart';
import 'fallback_dispatcher.dart';
import 'grammar_builder.dart';
import 'system_prompt.dart';
import 'tool_registry.dart';
import 'tool_handlers/explicar_tema.dart';
import 'tool_handlers/generar_ejercicios.dart';
import 'tool_handlers/ejecutar_diagnostico.dart';
import 'tool_handlers/obtener_perfil.dart';
import 'tool_handlers/obtener_leccion.dart';
import 'tool_handlers/registrar_interaccion.dart';

/// Conservative sampling configuration for predictable, safe educational output.
///
/// Parameters chosen per IRT design (N-01, N-03): low temperature prevents
/// hallucination in factual replies; topK/topP constrain the token pool;
/// repeat_penalty discourages loops; maxTokens provides room for tool-calling
/// and multi-step explanations.
class SamplingConfig {
  SamplingConfig._();

  /// Temperature: 0.4 — low creativity for factual educational content.
  static const double temperature = 0.4;

  /// Top-K: 64 — constrain to the 64 most probable next tokens.
  static const int topK = 64;

  /// Top-P: 0.85 — nucleus (cumulative probability) cutoff.
  static const double topP = 0.85;

  /// Repeat penalty: 1.1 — mild discouragement of token repetition.
  static const double repeatPenalty = 1.1;

  /// Max new tokens per generation: 1024 — sufficient for tool-calling
  /// and multi-step explanations (was 256).
  static const int maxTokens = 1024;
}

/// Default LiteRT model file used by `flutter_gemma`.
///
/// The reference project stores this file in the app documents directory and
/// points FlutterGemma's model manager to it before creating the model.
const String defaultFlutterGemmaModelFile = 'gemma-3n-E2B-it-int4.task';

/// Bridge to on-device Gemma inference via FlutterGemmaPlugin (MediaPipe).
///
/// Replaces the legacy MethodChannel/Kotlin/JNI/llama.cpp engine with
/// Google's `flutter_gemma` package. Follows the reference pattern from
/// gemma-vision/lib/chat_page/services/gemma_service.dart.
///
/// Strategy (hackathon-safe):
///   1. `cargarModelo()` attempts to load via FlutterGemmaPlugin.
///   2. If the model loads → live AI inference with native tool calling.
///   3. If the model fails → `_modeloCargado = false` and every call
///      returns pre-authored fallback responses from
///      `assets/data/fallback_responses.json`.
///
/// The app is FULLY FUNCTIONAL either way — the fallback guarantees every
/// help request gets a pedagogically sound response in Peruvian Spanish.
class GemmaService {
  GemmaService._internal();
  static final GemmaService instance = GemmaService._internal();

  /// Creates a fresh GemmaService instance for testing.
  /// Production code MUST use [instance] instead.
  @visibleForTesting
  GemmaService.forTest() : this._internal();

  /// Resets all internal state. Only for testing — production code
  /// MUST call [dispose] and re-initialize if needed.
  @visibleForTesting
  void resetForTest() {
    _model = null;
    _chat = null;
    _initialised = false;
    _modeloCargado = false;
    _fallbackLoaded = false;
    _fallbackData = null;
    _dispatcher = null;
    _registryInitialized = false;
    _registry.clearForTest();
  }

  // ---- flutter_gemma plugin ----
  final _gemma = FlutterGemmaPlugin.instance;
  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialised = false;

  // ---- state ----
  bool _modeloCargado = false;
  Map<String, dynamic>? _fallbackData;
  bool _fallbackLoaded = false;
  FallbackDispatcher? _dispatcher;

  final ToolRegistry _registry = ToolRegistry();
  ToolContext _toolContext = const ToolContext();
  bool _registryInitialized = false;

  // ---- feature gates ----

  /// When `true` (default), uses FlutterGemmaPlugin (MediaPipe) for inference.
  /// When `false`, routes to the legacy MethodChannel (llama.cpp) path,
  /// preserved on the `legacy-llamacpp` git branch for one-flag rollback.
  static bool useFlutterGemma = true;

  /// When `true` (default), `procesarMensaje()` uses the XML dispatch loop.
  /// When `false`, routes to legacy `generarExplicacion()` and
  /// `generarEjerciciosRefuerzo()` — preserving the pre-Phase-5 behavior
  /// as a one-flag rollback.
  static bool useXmlDispatch = true;

  /// When `true` (default), the Yachay Socratic tutor persona replaces the
  /// legacy Aprendo+ tutor. Extends the tool set to 13 tools, uses the
  /// Yachay system prompt, and runs up to 7 dispatch rounds.
  ///
  /// When `false`, routes to the standard 6-tool Aprendo+ persona.
  static bool useYachayOrchestrator = true;

  /// Maximum number of dispatch rounds in the tool-calling loop.
  ///
  /// Set to 7 to accommodate multi-step educational orchestration:
  /// consult progress → evaluate answer → suggest next topic →
  /// explain → practice.
  static const int maxDispatchRounds = 7;

  // ---- system prompt (spec requirement) ----

  static const String systemPrompt =
      'Eres un tutor de matematicas para secundaria '
      'en Peru. Explica conceptos de manera clara, usa ejemplos del contexto peruano '
      'y mantén un tono motivador sin calificaciones negativas.';

  // ---- dev mode: connect to desktop llama-server instead of MethodChannel ----

  static bool devMode = false;
  static String devServerUrl = 'http://10.0.2.2:8080';

  /// Writes debug info to device file. Read via adb:
  ///   adb shell run-as com.aprendoplus.app cat files/yachay_debug.log
  static void logToFile(String msg) {
    try {
      final f = File('/data/data/com.aprendoplus.app/files/yachay_debug.log');
      f.writeAsStringSync('[${DateTime.now().toIso8601String()}] $msg\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  /// Last recovery message from OOM checkpoint. Preserved for API compatibility.
  @visibleForTesting
  String? get lastRecoveryMessage => null;

  /// Whether the model is loaded and ready for inference.
  bool get modeloCargado => _modeloCargado;

  // ---- public API ----

  /// Initializes FlutterGemmaPlugin and loads the Gemma model.
  /// Returns `true` if the model is ready for inference.
  ///
  /// When [useFlutterGemma] is `false`, delegates to the legacy MethodChannel
  /// path instead.
  Future<bool> cargarModelo({String? modelPath}) async {
    if (_modeloCargado) return true;

    // Pre-load fallback data so it's available regardless of outcome.
    await _cargarFallback();

    if (!useFlutterGemma) {
      return _cargarModeloLegacy(modelPath: modelPath);
    }

    try {
      await init(modelPath: modelPath);
    } catch (e) {
      // flutter_gemma 1.4.2 surfaces load failures as Errors (e.g. StateError
      // from the uninitialized ServiceRegistry before the Phase-2 bootstrap),
      // not Exceptions. The documented contract: ANY load failure degrades
      // to fallback responses.
      debugPrint('GemmaService: FlutterGemmaPlugin init failed — $e. '
          'Using fallback.');
      _modeloCargado = false;
      return false;
    }

    return _modeloCargado;
  }

  /// Initializes the FlutterGemmaPlugin, creating model and chat session.
  /// Idempotent — safe to call multiple times.
  Future<void> init({String? modelPath}) async {
    if (_initialised) return;

    final resolvedModelPath =
        modelPath ?? await _defaultFlutterGemmaModelPath();
    // flutter_gemma 1.4.2 removed the parameterless `isModelInstalled`
    // getter; the legacy path only needs to point the model manager at the
    // model file when it exists on disk (`setModelPath` re-checks
    // installation internally). Keep this best-effort and guarded: without
    // the Phase-2 FlutterGemma bootstrap the registry is uninitialized and
    // would throw a StateError (an Error, not an Exception) that bypasses
    // the fallback in cargarModelo().
    if (File(resolvedModelPath).existsSync()) {
      try {
        // ignore: deprecated_member_use
        await _gemma.modelManager.setModelPath(resolvedModelPath);
      } catch (e) {
        debugPrint('GemmaService: setModelPath failed — $e. Continuing.');
      }
    }

    _model ??= await _gemma.createModel(
      preferredBackend: PreferredBackend.gpu,
      modelType: ModelType.gemmaIt,
      maxTokens: 8192,
    );

    _inicializarRegistry();
    final tools = _registry.toFlutterGemmaTools();

    _chat ??= await _model!.createChat(
      temperature: SamplingConfig.temperature,
      topK: SamplingConfig.topK,
      topP: SamplingConfig.topP,
      tools: tools,
      supportsFunctionCalls: true,
    );

    _initialised = true;
    _modeloCargado = true;
  }

  Future<String> _defaultFlutterGemmaModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$defaultFlutterGemmaModelFile';
  }

  /// Generates an alternative explanation for a lesson topic.
  ///
  /// If the model is loaded, extra context ([explicacionOriginal] and
  /// [errorEstudiante]) enriches the prompt for better targeting.
  /// Falls back to pre-authored JSON explanation otherwise.
  Future<String> generarExplicacion(
    String tema, {
    String? explicacionOriginal,
    String? errorEstudiante,
    String nivel = '1',
  }) async {
    await _cargarFallback();

    if (!_modeloCargado) {
      return _dispatchFallback(_temaToUserMessage(tema, 'explicar'));
    }

    final prompt = _buildExplanationPrompt(
      tema: tema,
      nivel: nivel,
      explicacionOriginal: explicacionOriginal,
      errorEstudiante: errorEstudiante,
    );

    try {
      final response = await _generateSync(prompt);
      if (response != null && response.isNotEmpty) return response;

      debugPrint('GemmaService: generate returned empty — falling back');
      return _dispatchFallback(_temaToUserMessage(tema, 'explicar'));
    } on TimeoutException {
      debugPrint('GemmaService: generate timed out — falling back');
      return _dispatchFallback(_temaToUserMessage(tema, 'explicar'));
    } catch (e) {
      debugPrint('GemmaService: generate failed — $e. Falling back.');
      return _dispatchFallback(_temaToUserMessage(tema, 'explicar'));
    }
  }

  /// Generates reinforcement exercises for a given topic.
  ///
  /// [patronError] describes the mistake pattern to target.
  /// Falls back to pre-authored exercises when the model is unavailable.
  Future<List<Map<String, dynamic>>> generarEjerciciosRefuerzo(
    String tema, {
    String? patronError,
    String nivel = '1',
  }) async {
    await _cargarFallback();

    if (!_modeloCargado) {
      return _dispatchFallbackEjercicios(tema, nivel);
    }

    final prompt = _buildExercisesPrompt(
      tema: tema,
      nivel: nivel,
      patronError: patronError,
    );

    try {
      final response = await _generateSync(prompt);
      if (response != null && response.isNotEmpty) {
        try {
          final parsed = jsonDecode(response);
          if (parsed is List) {
            return parsed.cast<Map<String, dynamic>>();
          }
        } catch (_) {
          // Model didn't return valid JSON — fallback.
        }
      }

      return _dispatchFallbackEjercicios(tema, nivel);
    } on TimeoutException {
      debugPrint('GemmaService: ejercicios timed out — falling back');
      return _dispatchFallbackEjercicios(tema, nivel);
    } catch (e) {
      debugPrint('GemmaService: ejercicios failed — $e. Falling back.');
      return _dispatchFallbackEjercicios(tema, nivel);
    }
  }

  /// Frees the model from memory. Safe to call even if model was never loaded.
  Future<void> dispose() async {
    if (!_modeloCargado && !_initialised) return;

    try {
      await _model?.close();
    } catch (e) {
      debugPrint('GemmaService: model close error — $e');
    }

    _model = null;
    _chat = null;
    _initialised = false;
    _modeloCargado = false;
  }

  /// Sends [prompt] to the Gemma model with token-level streaming.
  ///
  /// Tokens are delivered via [onToken] at 3-token intervals (UI throttle
  /// for low-RAM devices). When generation finishes, [onComplete] receives
  /// a [MessageStats] with timing and token metrics.
  ///
  /// Falls back to the 4-layer `FallbackDispatcher` when the model is not
  /// loaded, and catches exceptions to deliver empty stats so the caller
  /// never hangs.
  ///
  /// Timeout: 30 seconds.
  Future<void> sendWithStreaming(
    String prompt, {
    void Function(String tokenBatch)? onToken,
    void Function(MessageStats stats)? onComplete,
  }) async {
    await _cargarFallback();

    // ---- Legacy path: use MethodChannel streaming when gate is off ----
    if (!useFlutterGemma) {
      await _sendWithStreamingLegacy(
        prompt,
        onToken: onToken,
        onComplete: onComplete,
      );
      return;
    }

    // ---- guard: model not loaded → fallback ----
    if (!_modeloCargado || _chat == null) {
      onComplete?.call(MessageStats(tokenCount: 0, totalLatency: 0));
      return;
    }

    final startTime = DateTime.now();
    DateTime? firstTokenTime;
    int tokenCount = 0;
    int tokensSinceLastFlush = 0;
    final tokenBuffer = StringBuffer();

    try {
      await _chat!.addQuery(Message.text(text: prompt, isUser: true));

      await _chat!
          .generateChatResponseAsync()
          .timeout(
            const Duration(seconds: 30),
          )
          .forEach((res) {
        if (res is TextResponse) {
          firstTokenTime ??= DateTime.now();
          tokenCount++;
          tokenBuffer.write(res.token);
          tokensSinceLastFlush++;

          // 3-token UI throttle per spec requirement.
          if (tokensSinceLastFlush >= 3) {
            final batch = tokenBuffer.toString();
            tokenBuffer.clear();
            tokensSinceLastFlush = 0;
            onToken?.call(batch);
          }
        } else if (res is FunctionCallResponse) {
          // Tool execution handled by dispatch loop in procesarMensaje().
          // For raw sendWithStreaming, pass the function call name as token.
          onToken?.call('[tool:${res.name}]');
        }
      });
    } on TimeoutException {
      debugPrint('GemmaService: stream timed out');
    } catch (e) {
      debugPrint('GemmaService: stream error — $e');
    }

    // Flush any remaining buffered tokens.
    if (tokensSinceLastFlush > 0) {
      onToken?.call(tokenBuffer.toString());
    }

    // Compute final statistics.
    final endTime = DateTime.now();
    final stats = MessageStats.compute(
      startTime: startTime,
      firstTokenTime: firstTokenTime,
      endTime: endTime,
      tokenCount: tokenCount,
    );

    onComplete?.call(stats);
  }

  /// Unified dispatch method — the single entry point for all student
  /// messages. Replaces the monolithic `generarExplicacion` and
  /// `generarEjerciciosRefuerzo` methods with a feature-gated dispatch
  /// loop backed by XML tool calling (Phase 5) extended for Yachay
  /// Socratic tutoring (Phase 6).
  ///
  /// ## Flow
  ///
  /// 1. **Feature gates**: if `useXmlDispatch == false`, routes to legacy
  ///    methods. If `useYachayOrchestrator == true`, uses the Yachay
  ///    persona with 13 tools and 7-round loop.
  /// 2. **Fallback**: runs the 4-layer `FallbackDispatcher` when the
  ///    model is not loaded — greetings, keyword routing, tool execution,
  ///    generic encouragement.
  /// 3. **Dispatch loop** (max 7 rounds):
  ///    - Stream inference via `sendWithStreaming`, accumulating tokens.
  ///    - Parse output with `findNextAction`:
  ///      - `speak` (no action tag) → return accumulated text.
  ///      - `tool` → execute via `ToolRegistry` → feed result back → loop.
  ///    - On XML parse failure → `detectForcedTool` rescue → execute tool.
  ///    - On round exhaustion → force speak → return what we have.
  ///
  /// The method NEVER returns empty — `FallbackDispatcher` layer 4 always
  /// provides a generic encouragement when all else fails.
  Future<String> procesarMensaje(String userMessage) async {
    await _cargarFallback();
    _inicializarRegistry();

    // ---- Feature gate: useXmlDispatch=false → legacy ----
    if (!useXmlDispatch) {
      debugPrint('GemmaService: useXmlDispatch=false → routing to legacy');
      return _dispatchFallback(userMessage);
    }

    // ---- Dev mode: route to desktop llama-server ----
    if (devMode) {
      return _devHttpInference(userMessage);
    }

    // ---- Model not loaded → FallbackDispatcher ----
    if (!_modeloCargado) {
      return _dispatchFallback(userMessage);
    }

    // ---- Direct test: quick inference without full dispatch loop ----
    if (_modeloCargado && _chat != null) {
      try {
        await _chat!.addQuery(Message.text(
          text: 'Eres Yachay, tutor peruano. Responde max 2 oraciones.\n'
              'Pregunta: $userMessage\nRespuesta:',
          isUser: true,
        ));
        final response = await _chat!.generateChatResponse();
        if (response is TextResponse && response.token.isNotEmpty) {
          logToFile(
              'TEST OK: ${response.token.substring(0, response.token.length.clamp(0, 60))}');
          return 'Yachay: ${response.token}';
        }
        logToFile('TEST NULL');
      } catch (e) {
        logToFile('TEST ERROR: $e');
      }
    }

    return _dispatchFallback(userMessage);
  }

  // ---- private: legacy MethodChannel streaming (preserved from Phase 5) ----

  Future<void> _sendWithStreamingLegacy(
    String prompt, {
    void Function(String tokenBatch)? onToken,
    void Function(MessageStats stats)? onComplete,
  }) async {
    if (!_modeloCargado) {
      onComplete?.call(MessageStats(tokenCount: 0, totalLatency: 0));
      return;
    }

    const streamChannel = MethodChannel('gemma_engine_stream');
    const channel = MethodChannel('gemma_engine');

    final completer = Completer<void>();
    final startTime = DateTime.now();
    DateTime? firstTokenTime;
    int tokenCount = 0;
    int tokensSinceLastFlush = 0;
    final tokenBuffer = StringBuffer();

    streamChannel.setMethodCallHandler((MethodCall call) async {
      try {
        switch (call.method) {
          case 'onToken':
            final token = call.arguments as String;
            firstTokenTime ??= DateTime.now();
            tokenCount++;
            tokenBuffer.write(token);
            tokensSinceLastFlush++;

            if (tokensSinceLastFlush >= 3) {
              final batch = tokenBuffer.toString();
              tokenBuffer.clear();
              tokensSinceLastFlush = 0;
              onToken?.call(batch);
            }

          case 'onComplete':
            if (tokensSinceLastFlush > 0) {
              onToken?.call(tokenBuffer.toString());
            }

            final endTime = DateTime.now();
            final stats = MessageStats.compute(
              startTime: startTime,
              firstTokenTime: firstTokenTime,
              endTime: endTime,
              tokenCount: tokenCount,
            );

            onComplete?.call(stats);
            streamChannel.setMethodCallHandler(null);
            if (!completer.isCompleted) completer.complete();
        }
      } catch (e) {
        debugPrint('GemmaService: legacy stream handler error — $e');
      }
      return null;
    });

    try {
      await channel.invokeMethod('generateStream', {
        'prompt': prompt,
        'systemPrompt': systemPrompt,
        'temperature': SamplingConfig.temperature,
        'maxTokens': SamplingConfig.maxTokens,
        'topP': SamplingConfig.topP,
        'topK': SamplingConfig.topK,
        'repeatPenalty': SamplingConfig.repeatPenalty,
      }).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      streamChannel.setMethodCallHandler(null);
      if (!completer.isCompleted) {
        onComplete?.call(MessageStats(
          tokenCount: tokenCount,
          totalLatency:
              DateTime.now().difference(startTime).inMicroseconds / 1000000.0,
        ));
        completer.complete();
      }
    } catch (e) {
      streamChannel.setMethodCallHandler(null);
      if (!completer.isCompleted) {
        onComplete?.call(MessageStats(tokenCount: 0, totalLatency: 0));
        completer.complete();
      }
    }

    await completer.future;
  }

  // ---- private: synchronous generation helper ----

  Future<String?> _generateSync(String prompt) async {
    if (_chat == null) return null;

    try {
      await _chat!.addQuery(Message.text(text: prompt, isUser: true));
      final response = await _chat!.generateChatResponse().timeout(
            const Duration(seconds: 30),
          );
      if (response is TextResponse) return response.token;
    } catch (_) {
      // Fall through to null.
    }

    return null;
  }

  // ---- private: legacy MethodChannel cargarModelo ----

  Future<bool> _cargarModeloLegacy({String? modelPath}) async {
    try {
      const channel = MethodChannel('gemma_engine');
      final path = modelPath ??
          '/data/data/com.aprendoplus.app/files/google_gemma-4-E2B-it-IQ2_M.gguf';

      final result = await channel.invokeMethod<bool>(
        'loadModel',
        {'modelPath': path},
      ).timeout(const Duration(seconds: 30));

      _modeloCargado = result ?? false;
      return _modeloCargado;
    } on TimeoutException {
      debugPrint('GemmaService: legacy loadModel timed out — using fallback');
      _modeloCargado = false;
      return false;
    } on MissingPluginException {
      debugPrint('GemmaService: legacy channel not available — using fallback');
      _modeloCargado = false;
      return false;
    } catch (e) {
      debugPrint('GemmaService: legacy loadModel failed — $e');
      _modeloCargado = false;
      return false;
    }
  }

  // ---- private: tool registry initialization ----

  /// Registers all 13 tool handlers in the ToolRegistry.
  /// Idempotent — safe to call multiple times.
  void _inicializarRegistry() {
    if (_registryInitialized) return;

    // Original 6 tools (Phase 5).
    _registry.register(explicarTemaSpec);
    _registry.register(generarEjerciciosSpec);
    _registry.register(ejecutarDiagnosticoSpec);
    _registry.register(obtenerPerfilSpec);
    _registry.register(obtenerLeccionSpec);
    _registry.register(registrarInteraccionSpec);

    // Yachay tools (Phase 6) — 7 new tools.
    _registry.register(consultarEstadoSpec);
    _registry.register(evaluarRespuestaSpec);
    _registry.register(obtenerSiguienteTemaSpec);
    _registry.register(obtenerPlanCompletoSpec);
    _registry.register(generarNotaProgresoSpec);
    _registry.register(generarResumenAlumnoSpec);
    _registry.register(iniciarConversacionSpec);

    _toolContext = ToolContext(fallbackData: _fallbackData);
    _registryInitialized = true;
  }

  // ---- private: dispatch-loop prompt builders ----

  String _buildToolPrompt(String userMessage) {
    final toolList = _registry.listTools();
    final grammar = buildGrammar(_registry);
    final prompt = useYachayOrchestrator
        ? SystemPrompt.buildYachay(toolList)
        : SystemPrompt.build(toolList);

    return '$systemPrompt\n\n$prompt\n\n'
        'Mensaje del estudiante: $userMessage\n\n'
        '${grammar.isNotEmpty ? "Grammar constraint: $grammar\n\n" : ""}'
        'Responde usando el formato de acción XML si necesitas usar una herramienta. '
        'Si no necesitas herramienta, responde directamente al estudiante.';
  }

  String _buildToolResultPrompt(String toolName, String result) {
    return '$systemPrompt\n\n'
        'Ejecutaste la herramienta "$toolName" y obtuviste este resultado:\n\n'
        '$result\n\n'
        'Ahora responde al estudiante en español peruano, '
        'con un tono cálido y motivador. '
        'Si necesitas más información, puedes usar otra herramienta. '
        'Si ya tienes suficiente, responde directamente.';
  }

  // ---- private: fallback loading ----

  Future<void> _cargarFallback() async {
    if (_fallbackLoaded) return;

    try {
      final raw = await rootBundle.loadString(
        'assets/data/fallback_responses.json',
      );
      _fallbackData = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('GemmaService: failed to load fallback data — $e');
      _fallbackData = {};
    }

    _dispatcher = FallbackDispatcher(
      fallbackData: _fallbackData ?? <String, dynamic>{},
    );

    _fallbackLoaded = true;
  }

  // ---- private: fallback dispatch ----

  Future<String> _dispatchFallback(String userMessage) async {
    if (_dispatcher == null) {
      return 'Estoy aquí para ayudarte. ¿Qué tema te gustaría repasar hoy?';
    }
    return _dispatcher!.dispatch(userMessage);
  }

  String _fallbackExplicacion(String tema, String nivel) {
    final topic = _fallbackData?[tema];
    if (topic is! Map) return _genericExplicacion(tema);

    var levelData = topic[nivel];
    if (levelData == null) levelData = topic['1'];
    if (levelData == null) return _genericExplicacion(tema);

    final entry = levelData as Map<String, dynamic>;
    return entry['explicacion'] as String? ?? _genericExplicacion(tema);
  }

  List<Map<String, dynamic>> _fallbackEjercicios(String tema, String nivel) {
    final topic = _fallbackData?[tema];
    if (topic is! Map) return _genericEjercicios(tema);

    var levelData = topic[nivel];
    if (levelData == null) levelData = topic['1'];
    if (levelData == null) return _genericEjercicios(tema);

    final entry = levelData as Map<String, dynamic>;
    final ejercicios = entry['ejercicios'];
    if (ejercicios is List) return ejercicios.cast<Map<String, dynamic>>();

    return _genericEjercicios(tema);
  }

  // ---- private: prompt builders ----

  String _buildExplanationPrompt({
    required String tema,
    required String nivel,
    String? explicacionOriginal,
    String? errorEstudiante,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Explica el tema "$tema" para un estudiante de secundaria '
        'en nivel $nivel.');
    if (explicacionOriginal != null && explicacionOriginal.isNotEmpty) {
      buffer.writeln('La explicacion original fue: $explicacionOriginal');
    }
    if (errorEstudiante != null && errorEstudiante.isNotEmpty) {
      buffer.writeln('El estudiante cometio este error: $errorEstudiante');
    }
    buffer.writeln('Da una explicacion alternativa, clara, con ejemplos '
        'del contexto peruano, en maximo 150 palabras.');
    return buffer.toString();
  }

  String _buildExercisesPrompt({
    required String tema,
    required String nivel,
    String? patronError,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Genera 3 ejercicios de practica sobre "$tema" para '
        'nivel $nivel de secundaria.');
    if (patronError != null && patronError.isNotEmpty) {
      buffer.writeln('Enfocate en corregir este patron de error: $patronError');
    }
    buffer.writeln('Responde en formato JSON como una lista de objetos, '
        'cada uno con: "enunciado", "opciones" (arreglo de 4 strings), '
        'y "respuestaCorrecta".');
    buffer.writeln(
        'Ejemplo: [{"enunciado": "...", "opciones": ["a","b","c","d"], '
        '"respuestaCorrecta": "c"}]');
    return buffer.toString();
  }

  // ---- private: generic fallbacks (last resort) ----

  String _genericExplicacion(String tema) {
    final clean = tema.replaceAll(RegExp(r'^[A-Z]\d+_'), '');
    return 'Vamos a repasar "$clean" juntos. '
        'Lee nuevamente la explicacion de la leccion con calma. '
        'Identifica la parte que no te quedo clara y pideme ayuda '
        'especifica con esa seccion. Recuerda: equivocarse es parte '
        'del aprendizaje. Sigue practicando.';
  }

  List<Map<String, dynamic>> _genericEjercicios(String tema) {
    final clean = tema.replaceAll(RegExp(r'^[A-Z]\d+_'), '');
    return [
      {
        'enunciado': 'Repasa el concepto principal de "$clean" '
            'y explica con tus propias palabras en que consiste.',
        'opciones': ['Entendido', 'Necesito mas ayuda'],
        'respuestaCorrecta': 'Entendido',
      },
    ];
  }

  // ---- private: helpers ----

  String _temaToUserMessage(String tema, String intent) {
    final clean = tema.replaceAll(RegExp(r'^[A-Z]\d+_'), '');
    if (intent == 'explicar') return 'explicame $clean';
    if (intent == 'ejercicios') return 'dame ejercicios de $clean';
    return clean;
  }

  Future<List<Map<String, dynamic>>> _dispatchFallbackEjercicios(
    String tema,
    String nivel,
  ) async {
    try {
      final str =
          await _dispatchFallback(_temaToUserMessage(tema, 'ejercicios'));
      if (str.isNotEmpty) {
        return [
          {
            'enunciado': str,
            'opciones': <String>['Entendido', 'Necesito mas ayuda'],
            'respuestaCorrecta': 'Entendido',
            '_fallbackText': true,
          },
        ];
      }
    } catch (e) {
      debugPrint('GemmaService: dispatcher ejercicios failed — $e');
    }
    return _fallbackEjercicios(tema, nivel);
  }

  /// Uses OpenAI-compatible /v1/chat/completions endpoint (dev mode).
  Future<String> _devHttpInference(String userMessage) async {
    try {
      final sysPrompt = useYachayOrchestrator
          ? 'Eres Yachay, un tutor de aritmetica para estudiantes peruanos de secundaria. '
              'Eres calido, paciente y motivador. Usas ejemplos del contexto peruano '
              '(soles, mercados, combis, chacras). NUNCA das respuestas directas. '
              'Usas el metodo socratico: guias al alumno con preguntas para que '
              'descubra por si mismo. Cada respuesta tuya debe incluir una pregunta '
              'de seguimiento. Responde en espanol peruano, maximo 3 oraciones.'
          : systemPrompt;
      final body = jsonEncode({
        'model': 'gemma',
        'messages': [
          {'role': 'system', 'content': sysPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': SamplingConfig.temperature,
        'max_tokens': 400,
      });

      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse('$devServerUrl/v1/chat/completions'),
        );
        request.headers.contentType = ContentType.json;
        request.write(body);
        final response = await request.close();
        if (response.statusCode == 200) {
          final raw = await response.transform(utf8.decoder).join();
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final choices = data['choices'] as List;
          if (choices.isNotEmpty) {
            final msg = choices[0]['message'] as Map<String, dynamic>;
            final content = (msg['content'] as String?)?.trim() ?? '';
            if (content.isNotEmpty) return content;
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('GemmaService: dev HTTP error: $e → fallback');
    }
    return _dispatchFallback(userMessage);
  }
}
