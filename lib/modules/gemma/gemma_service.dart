import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_gemma/flutter_gemma.dart'
    show
        FunctionCallResponse,
        Message,
        ParallelFunctionCallResponse,
        PreferredBackend,
        TextResponse;

import '../../core/models/message_stats.dart';
import '../yachay/tool_handlers/consultar_estado.dart';
import '../yachay/tool_handlers/evaluar_respuesta.dart';
import '../yachay/tool_handlers/obtener_siguiente_tema.dart';
import '../yachay/tool_handlers/obtener_plan_completo.dart';
import '../yachay/tool_handlers/generar_nota_progreso.dart';
import '../yachay/tool_handlers/generar_resumen_alumno.dart';
import '../yachay/tool_handlers/iniciar_conversacion.dart';
import 'fallback_dispatcher.dart';
import 'gemma_inference_adapter.dart';
import 'huggingface_oauth.dart';
import 'model_download_service.dart';
import 'model_installer.dart';
import 'model_status.dart';
import 'system_prompt.dart';
import 'token_store.dart';
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

  /// Max output tokens per generation: 256 — hard limit for MVP 4to Primaria
  /// (per stakeholder constraint). Keeps generation fast on low-RAM devices.
  static const int maxTokens = 256;
}

/// Default LiteRT model file used by `flutter_gemma`.
///
/// Kept for API compatibility; the 1.4.2 path uses `FlutterGemma.getActiveModel`
/// (the installed model is managed by the plugin, see PR2's bootstrap).
const String defaultFlutterGemmaModelFile = 'gemma-3n-E2B-it-int4.task';

/// Bridge to on-device Gemma inference on the flutter_gemma 1.4.2 API.
///
/// Replaces the legacy channel/Kotlin/JNI/llama.cpp engine AND the
/// 0.10.x MediaPipe surface with Google's `flutter_gemma` 1.4.2 API:
///   - init: `FlutterGemma.getActiveModel(maxTokens: 8192, backend: cpu)` +
///     `createChat(systemInstruction, maxOutputTokens, tools, toolChoice: auto)`
///   - dispatch: native function calling loop (max [maxDispatchRounds] rounds)
///     over `generateChatResponseAsync()`
///   - streaming: raw token stream from the chat session (`getResponseAsync`)
///   - timeout: injectable, 30 seconds by default
///   - failure policy: ANY failure degrades to the pre-authored
///     `FallbackDispatcher` (tokenCount == 0 / fallback text, never crash)
///   - `dispose()` only `close()`s the chat/model (ADR-5: never deleteModel)
///
/// All plugin access goes through the [GemmaInferenceAdapter] seam so the
/// whole service is testable with an in-memory fake.
class GemmaService {
  GemmaService._internal({
    GemmaInferenceAdapter? adapter,
    Duration? streamTimeout,
  })  : _adapter = adapter ?? FlutterGemmaInferenceAdapter(),
        _streamTimeout = streamTimeout ?? const Duration(seconds: 30);

  static final GemmaService instance = GemmaService._internal();

  /// Creates a fresh GemmaService instance for testing.
  /// Production code MUST use [instance] instead.
  @visibleForTesting
  GemmaService.forTest(
      {GemmaInferenceAdapter? adapter, Duration? streamTimeout})
      : this._internal(adapter: adapter, streamTimeout: streamTimeout);

  /// Resets all internal state. Only for testing — production code
  /// MUST call [dispose] and re-initialize if needed.
  @visibleForTesting
  void resetForTest() {
    _modeloCargado = false;
    _fallbackLoaded = false;
    _fallbackData = null;
    _dispatcher = null;
    _registryInitialized = false;
    _toolContext = const ToolContext();
    _registry.clearForTest();
    statusController.reset();
    _chatSessionOpen = false;
    _pendingClose = false;
    _lifecycleClosed = false;
  }

  final GemmaInferenceAdapter _adapter;
  final Duration _streamTimeout;

  /// Status machine exposed to the UI chip.
  ///
  /// The scaffold listens to this notifier and renders
  /// [ModelStatusInfo.label]. The download service feeds the download/verify
  /// transitions; [cargarModelo] feeds `ready` with the effective backend.
  final ModelStatusController statusController = ModelStatusController();

  // ---- state ----
  bool _modeloCargado = false;
  Map<String, dynamic>? _fallbackData;
  bool _fallbackLoaded = false;
  FallbackDispatcher? _dispatcher;
  ModelDownloadService? _downloadServiceInstance;

  final ToolRegistry _registry = ToolRegistry();
  ToolContext _toolContext = const ToolContext();
  bool _registryInitialized = false;

  // ---- lifecycle management (Fix 1: OOM prevention) ----

  /// Whether the chat session is currently open in the adapter.
  bool _chatSessionOpen = false;

  /// Prevents double-close during rapid lifecycle transitions.
  bool _pendingClose = false;

  /// True when the model was closed due to app backgrounding.
  bool _lifecycleClosed = false;

  // ---- persona flags ----

  /// When `true` (default), the Yachay Socratic tutor persona replaces the
  /// legacy Aprendo+ tutor: Yachay system prompt as `systemInstruction` and
  /// the full 13-tool set registered for native function calling.
  static bool useYachayOrchestrator = true;

  /// Maximum number of dispatch rounds in the tool-calling loop.
  ///
  /// Set to 7 to accommodate multi-step educational orchestration:
  /// consult progress → evaluate answer → suggest next topic →
  /// explain → practice.
  static const int maxDispatchRounds = 7;

  // ---- system prompt (spec requirement) ----

  static const String systemPrompt =
      'Eres un tutor de matemáticas para primaria '
      'en Perú. Explica conceptos de manera clara, usa ejemplos del contexto peruano '
      'y mantén un tono motivador sin calificaciones negativas.';

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

  /// Backend the loaded model runs on (CPU by design, ADR-3);
  /// null until [cargarModelo] succeeds.
  PreferredBackend? get activeBackend => _adapter.activeBackend;

  /// Injects the [ToolContext] passed to tool handlers.
  ///
  /// The app wires the live student state / DB here; tool handlers such as
  /// `evaluar_respuesta` use it to persist `student_mastery` checkpoints.
  /// Services set here survive registry initialization.
  void setToolContext(ToolContext ctx) {
    _toolContext = ctx;
  }

  // ---- lifecycle handling (Fix 1: OOM prevention) ----

  /// Called by the scaffold when [AppLifecycleState] changes.
  ///
  /// On `paused`/`detached`: closes the chat session and model to free RAM.
  /// On `resumed`: marks the service for reload on next [cargarModelo] call.
  /// Serialize close operations via [_pendingClose] to prevent double-free.
  Future<void> handleLifecycleChange(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_pendingClose) return;
      _pendingClose = true;
      try {
        await _adapter.close();
        _chatSessionOpen = false;
        _modeloCargado = false;
        _lifecycleClosed = true;
      } catch (e) {
        debugPrint('GemmaService: lifecycle close error — $e');
      } finally {
        _pendingClose = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_lifecycleClosed) {
        _modeloCargado = false;
        _chatSessionOpen = false;
      }
    }
  }

  /// Clears the chat session history without reloading the model (Fix 2).
  /// Much faster than full reinitialization for "new chat" functionality.
  Future<void> clearHistory() async {
    if (!_chatSessionOpen) return;
    await _adapter.clearHistory();
  }

  // ---- public API ----

  /// Loads the active model on the CPU backend and creates the 1.4.2 chat
  /// session (systemInstruction, maxOutputTokens >= 1024, toolChoice: auto,
  /// 13 tools). Idempotent.
  ///
  /// Returns `true` only when the model is ready for inference. ANY failure
  /// (no model installed, native error) degrades to fallback responses.
  ///
  /// Feeds [statusController]: `ready` with the effective backend on success;
  /// a model absent at boot keeps the chip in `Sin modelo` (the download
  /// service owns error transitions during install).
  Future<bool> cargarModelo({String? modelPath}) async {
    if (_modeloCargado) return true;

    // Pre-load fallback data so it's available regardless of outcome.
    await _cargarFallback();
    _inicializarRegistry();

    try {
      final ok = await _adapter.loadModel(
        maxTokens: SamplingConfig.maxTokens,
      );
      if (!ok) {
        // No active model (first run / not installed): stay degraded. The
        // chip keeps its real state (`Sin modelo`) — never a false `Listo`.
        _modeloCargado = false;
        return false;
      }
      try {
        // The model on this device does NOT support function calling (confirmed
        // by the plugin warning). Create a plain-text chat session like the
        // reference apps (gemma-vision, yachayprueba1-fc02) — no tools, just
        // text generation. This prevents the stream from stalling during CPU
        // prefill with a bloated tool-augmented system prompt.
        await _adapter.createChat(
          systemInstruction: _yachaySystemPrompt(),
          maxOutputTokens: SamplingConfig.maxTokens,
          tools: const [],
          temperature: SamplingConfig.temperature,
          topK: SamplingConfig.topK,
          topP: SamplingConfig.topP,
          repeatPenalty: SamplingConfig.repeatPenalty,
          tokenBuffer: 512,
          randomSeed: 1,
        );
        _chatSessionOpen = true;
        _lifecycleClosed = false;
      } catch (e) {
        debugPrint('GemmaService: createChat failed — $e. Using fallback.');
        _modeloCargado = false;
        statusController.error(
          'El modelo está instalado pero no se pudo iniciar la sesión de '
          'chat. Se usará el modo sin IA.',
        );
        return false;
      }
      _modeloCargado = true;
      statusController.ready(_adapter.activeBackend);
      return true;
    } catch (e) {
      debugPrint('GemmaService: loadModel/createChat failed — $e. '
          'Using fallback.');
      _modeloCargado = false;
      return false;
    }
  }

  /// Bounded bootstrap: ensures the model is downloaded/verified (feeding
  /// [statusController]) and then loads the chat session.
  ///
  /// The whole flow is bounded by [timeout] so the scaffold's send path can
  /// never deadlock on the network. Any failure simply returns `false` and
  /// the app keeps operating in degraded (no-AI) mode — it never crashes.
  Future<bool> bootstrapModelReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_modeloCargado) return true;
    try {
      final result =
          await _downloadService().ensureModelReady().timeout(timeout);
      if (!result.success) return false;
      return cargarModelo();
    } on TimeoutException {
      debugPrint('GemmaService: model bootstrap timed out — using fallback.');
      return false;
    } catch (e) {
      debugPrint('GemmaService: model bootstrap failed — $e. Using fallback.');
      return false;
    }
  }

  /// Lazily builds the real download pipeline wired to [statusController].
  ///
  /// Plugin-backed seams are only touched when [bootstrapModelReady] runs, so
  /// pure unit tests never reach the native surface.
  ModelDownloadService _downloadService() {
    return _downloadServiceInstance ??= ModelDownloadService(
      installer: FlutterGemmaModelInstaller(),
      verifier: const GemmaModelIntegrityVerifier(),
      tokens: HuggingFaceOAuth(store: const SharedPrefsTokenStore()),
      status: statusController,
    );
  }

  /// Unified dispatch entry point for student messages.
  ///
  /// Native function-calling loop on the 1.4.2 chat session, max
  /// [maxDispatchRounds] rounds:
  /// 1. Greetings respond directly via `iniciar_conversacion` (no chat round).
  /// 2. Each round feeds the query (`addQuery`) and streams the model response.
  /// 3. `FunctionCallResponse` → executes the tool via [ToolRegistry] →
  ///    feeds the result back as a tool response → next round.
  /// 4. `TextResponse` → returns the accumulated final text.
  /// 5. Round exhaustion → forces a final text with the accumulated results.
  ///
  /// The method NEVER returns empty — [FallbackDispatcher] always provides a
  /// response when the model is unavailable or any round fails.
  Future<String> procesarMensaje(String userMessage) async {
    await _cargarFallback();
    _inicializarRegistry();

    // ---- Model not loaded → FallbackDispatcher ----
    if (!_modeloCargado) {
      return _dispatchFallback(userMessage);
    }

    // ---- Greeting → respond directly ----
    if (_esSaludo(userMessage)) {
      final saludo =
          await _registry.run('iniciar_conversacion', {}, _toolContext);
      return saludo.summary;
    }

    // ---- Plain-text mode (no function calling on this device) ----
    // The model logs "Model does not support function calls" — stream text
    // directly like the reference apps (gemma-vision, yachayprueba1-fc02).
    return _dispatchPlainText(userMessage);
  }

  /// Sends [prompt] to the Gemma model with token-level streaming.
  ///
  /// Tokens are delivered via [onToken] at 3-token intervals (UI throttle
  /// for low-RAM devices). When generation finishes, [onComplete] receives
  /// a [MessageStats] with timing and token metrics.
  ///
  /// Falls back to empty stats (`tokenCount: 0`) when the model is not
  /// loaded, and catches exceptions/timeouts (default 30s, injectable) to
  /// deliver partial stats so the caller never hangs.
  Future<void> sendWithStreaming(
    String prompt, {
    void Function(String tokenBatch)? onToken,
    void Function(MessageStats stats)? onComplete,
  }) async {
    await _cargarFallback();

    // ---- guard: model not loaded → degraded empty stats ----
    if (!_modeloCargado) {
      onComplete?.call(const MessageStats(tokenCount: 0, totalLatency: 0));
      return;
    }

    final startTime = DateTime.now();
    DateTime? firstTokenTime;
    int tokenCount = 0;
    int tokensSinceLastFlush = 0;
    final tokenBuffer = StringBuffer();

    try {
      await _adapter.addQuery(Message.text(text: prompt, isUser: true));

      final stream = _adapter.streamResponse().timeout(_streamTimeout);
      await for (final token in stream) {
        firstTokenTime ??= DateTime.now();
        tokenCount++;
        tokenBuffer.write(token);
        tokensSinceLastFlush++;

        // 3-token UI throttle per spec requirement.
        if (tokensSinceLastFlush >= 3) {
          final batch = tokenBuffer.toString();
          tokenBuffer.clear();
          tokensSinceLastFlush = 0;
          onToken?.call(batch);
        }
      }
    } on TimeoutException {
      debugPrint('GemmaService: stream timed out');
    } catch (e) {
      debugPrint('GemmaService: stream error — $e');
    }

    // Flush any remaining buffered tokens.
    if (tokensSinceLastFlush > 0) {
      onToken?.call(tokenBuffer.toString());
    }

    // Compute final statistics (partial on timeout).
    final endTime = DateTime.now();
    final stats = MessageStats.compute(
      startTime: startTime,
      firstTokenTime: firstTokenTime,
      endTime: endTime,
      tokenCount: tokenCount,
    );

    onComplete?.call(stats);
  }

  /// Frees native resources. Safe to call even if the model was never loaded.
  /// Only `close()` — NEVER `deleteModel()` (ADR-5).
  Future<void> dispose() async {
    try {
      await _adapter.close();
    } catch (e) {
      debugPrint('GemmaService: adapter close error — $e');
    }
    _modeloCargado = false;
  }

  // ---- legacy Aprendo+ helpers (used by leccion_screen) ----

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
    } catch (e) {
      debugPrint('GemmaService: ejercicios failed — $e. Falling back.');
      return _dispatchFallbackEjercicios(tema, nivel);
    }
  }

  // ---- private: synchronous generation helper ----

  Future<String?> _generateSync(String prompt) async {
    try {
      await _adapter.addQuery(Message.text(text: prompt, isUser: true));
      final buffer = StringBuffer();
      final stream = _adapter.streamResponse().timeout(_streamTimeout);
      await for (final token in stream) {
        buffer.write(token);
      }
      final text = buffer.toString().trim();
      return text.isNotEmpty ? text : null;
    } catch (_) {
      // Timeout or stream failure → null → caller falls back.
      return null;
    }
  }

  // ---- private: dispatch round ----

  /// Runs one inference round over `streamChatResponse()` and classifies the
  /// outcome: accumulated text, tool calls, or nothing usable.
  ///
  /// Uses `await for` (like the reference app) instead of `.forEach()` so that
  /// stream errors are caught and the loop terminates instead of hanging
  /// indefinitely.
  Future<_RondaResult?> _generarRonda() async {
    final buffer = StringBuffer();
    final toolCalls = <FunctionCallResponse>[];
    var sawToolCall = false;

    try {
      final stream = _adapter.streamChatResponse().timeout(_streamTimeout);
      await for (final res in stream) {
        if (res is TextResponse) {
          buffer.write(res.token);
        } else if (res is FunctionCallResponse) {
          sawToolCall = true;
          toolCalls.add(res);
        } else if (res is ParallelFunctionCallResponse) {
          sawToolCall = true;
          toolCalls.addAll(res.calls);
        }
      }
    } on TimeoutException {
      debugPrint('GemmaService: _generarRonda timed out');
    } catch (e) {
      debugPrint('GemmaService: _generarRonda stream error — $e');
    }

    if (sawToolCall) {
      return _RondaResult(toolCalls: toolCalls);
    }
    final text = buffer.toString();
    if (text.trim().isNotEmpty) {
      return _RondaResult(text: text);
    }
    return null;
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

    // Preserve services injected via setToolContext (e.g. student state).
    _toolContext = ToolContext(
      studentState: _toolContext.studentState,
      dbService: _toolContext.dbService,
      diagnosticoService: _toolContext.diagnosticoService,
      curriculum: _toolContext.curriculum,
      fallbackData: _fallbackData,
    );
    _registryInitialized = true;
  }

  // ---- private: prompt builders ----

  String _systemInstruction() {
    return useYachayOrchestrator
        ? SystemPrompt.buildYachay(_registry.listTools())
        : SystemPrompt.build(_registry.listTools());
  }

  /// Compact system prompt for plain-text mode (no tools).
  ///
  /// Used when the model does not support function calls — keeps the persona
  /// and Socratic rules but omits tool descriptions to minimise CPU prefill.
  String _yachaySystemPrompt() {
    return useYachayOrchestrator
        ? 'Eres Yachay, un tutor socrático para estudiantes '
            'de 4to de primaria en Perú. "Yachay" significa sabiduría en '
            'quechua. Guiá al estudiante con preguntas, nunca des respuestas '
            'directas. Usá ejemplos del contexto peruano (soles, mercados, '
            'chacras). Usá palabras simples — tenés que hablarle a niños de '
            '9 y 10 años. Celebrá cuando el estudiante aprende algo nuevo. '
            'Nunca digas "está mal" — decí "casi, probá de otra manera". ¡Allin!'
        : 'Eres Aprendo+, un tutor para primaria en Perú. '
            'Explicá con claridad, paciencia y ejemplos del contexto local.';
  }

  bool _esSaludo(String message) {
    final m = message.trim().toLowerCase();
    const greetings = [
      'hola',
      'buenas',
      'buen dia',
      'buenos dias',
      'buen día',
      'buenos días',
      'buenas tardes',
      'buenas noches',
      'hey',
      'que tal',
      'qué tal',
      'saludos',
    ];
    for (final g in greetings) {
      if (m.startsWith(g)) return true;
    }
    return false;
  }

  String _buildExplanationPrompt({
    required String tema,
    required String nivel,
    String? explicacionOriginal,
    String? errorEstudiante,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Explica el tema "$tema" para un estudiante de primaria '
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
        'nivel $nivel de primaria.');
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

  /// Test seam: pre-populates the fallback data so [_cargarFallback] skips
  /// the rootBundle asset load entirely. Widget tests use this to keep the
  /// whole bootstrap chain inside the fake-async zone (real asset IO does not
  /// progress there). Production code never calls this.
  @visibleForTesting
  void setFallbackDataForTest(Map<String, dynamic> data) {
    _fallbackData = data;
    _fallbackLoaded = true;
    _dispatcher = FallbackDispatcher(fallbackData: data);
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

  /// Plain-text generation for models that don't support function calling.
  ///
  /// Mirrors the reference apps (gemma-vision, yachayprueba1-fc02): uses
  /// `generateChatResponseAsync()` (chat-level stream) instead of
  /// `session.getResponseAsync()` (raw token stream), which the reference
  /// apps show is the correct path for text generation.
  Future<String> _dispatchPlainText(String userMessage) async {
    try {
      await _adapter.addQuery(Message.text(text: userMessage, isUser: true));

      final buffer = StringBuffer();
      final stream = _adapter.streamChatResponse().timeout(_streamTimeout);
      await for (final res in stream) {
        if (res is TextResponse && res.token.isNotEmpty) {
          buffer.write(res.token);
        }
      }

      final text = buffer.toString().trim();
      if (text.isNotEmpty) return text;
    } on TimeoutException {
      debugPrint('GemmaService: plain-text stream timed out');
    } catch (e) {
      debugPrint('GemmaService: plain-text stream failed — $e');
    }

    return _dispatchFallback(userMessage);
  }

  List<Map<String, dynamic>> _fallbackEjercicios(String tema, String nivel) {
    final topic = _fallbackData?[tema];
    if (topic is! Map) return _genericEjercicios(tema);

    final levelData = topic[nivel] ?? topic['1'];
    if (levelData == null) return _genericEjercicios(tema);

    final entry = levelData as Map<String, dynamic>;
    final ejercicios = entry['ejercicios'];
    if (ejercicios is List) return ejercicios.cast<Map<String, dynamic>>();

    return _genericEjercicios(tema);
  }

  List<Map<String, dynamic>> _genericEjercicios(String tema) {
    final clean = _stripPrefix(tema);
    return [
      {
        'enunciado': 'Repasa el concepto principal de "$clean" '
            'y explica con tus propias palabras en que consiste.',
        'opciones': ['Entendido', 'Necesito mas ayuda'],
        'respuestaCorrecta': 'Entendido',
      },
    ];
  }

  String _temaToUserMessage(String tema, String intent) {
    final clean = _stripPrefix(tema);
    if (intent == 'explicar') return 'explicame $clean';
    if (intent == 'ejercicios') return 'dame ejercicios de $clean';
    return clean;
  }

  /// Strips the topic-ID prefix (e.g. "M01_fracciones" → "fracciones").
  /// Uses native String methods only — zero RegExp.
  String _stripPrefix(String id) {
    final idx = id.indexOf('_');
    return idx >= 0 ? id.substring(idx + 1) : id;
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
}

/// Outcome of a single dispatch round: either accumulated [text] or the
/// [toolCalls] the model requested (never both).
class _RondaResult {
  final String? text;
  final List<FunctionCallResponse>? toolCalls;

  const _RondaResult({this.text, this.toolCalls});
}
