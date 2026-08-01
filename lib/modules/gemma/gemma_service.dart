import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Max output tokens per generation: 1024 — sufficient for tool-calling
  /// and multi-step explanations (was 256). This is the `maxOutputTokens`
  /// passed to `createChat` (generation cap, not the context window).
  static const int maxTokens = 1024;
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
  GemmaService.forTest({GemmaInferenceAdapter? adapter, Duration? streamTimeout})
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
  }

  final GemmaInferenceAdapter _adapter;
  final Duration _streamTimeout;

  // ---- state ----
  bool _modeloCargado = false;
  Map<String, dynamic>? _fallbackData;
  bool _fallbackLoaded = false;
  FallbackDispatcher? _dispatcher;

  final ToolRegistry _registry = ToolRegistry();
  ToolContext _toolContext = const ToolContext();
  bool _registryInitialized = false;

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
      'Eres un tutor de matematicas para secundaria '
      'en Peru. Explica conceptos de manera clara, usa ejemplos del contexto peruano '
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

  // ---- public API ----

  /// Loads the active model on the CPU backend and creates the 1.4.2 chat
  /// session (systemInstruction, maxOutputTokens >= 1024, toolChoice: auto,
  /// 13 tools). Idempotent.
  ///
  /// Returns `true` only when the model is ready for inference. ANY failure
  /// (no model installed, native error) degrades to fallback responses.
  Future<bool> cargarModelo({String? modelPath}) async {
    if (_modeloCargado) return true;

    // Pre-load fallback data so it's available regardless of outcome.
    await _cargarFallback();
    _inicializarRegistry();

    try {
      final ok = await _adapter.loadModel(maxTokens: 8192);
      if (!ok) {
        _modeloCargado = false;
        return false;
      }
      await _adapter.createChat(
        systemInstruction: _systemInstruction(),
        maxOutputTokens: SamplingConfig.maxTokens,
        tools: _registry.toFlutterGemmaTools(),
      );
      _modeloCargado = true;
      return true;
    } catch (e) {
      debugPrint('GemmaService: loadModel/createChat failed — $e. '
          'Using fallback.');
      _modeloCargado = false;
      return false;
    }
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

    try {
      await _adapter.addQuery(Message.text(text: userMessage, isUser: true));

      final buffer = StringBuffer();

      for (var round = 1; round <= maxDispatchRounds; round++) {
        final ronda = await _generarRonda();
        if (ronda == null) {
          // Empty round: the model produced nothing usable.
          return _dispatchFallback(userMessage);
        }

        if (ronda.text != null) {
          buffer.write(ronda.text);
          return buffer.toString().trim();
        }

        // Tool round: execute every call and feed the result back.
        for (final call in ronda.toolCalls!) {
          final result =
              await _registry.run(call.name, call.args, _toolContext);
          buffer.write('${result.summary}\n');
          await _adapter.addQuery(Message.toolResponse(
            toolName: call.name,
            response: {'summary': result.summary, 'payload': result.payload},
          ));
        }
      }

      // Round exhaustion: force a final text with the accumulated results.
      final forced = buffer.toString().trim();
      if (forced.isNotEmpty) return forced;
      return _dispatchFallback(userMessage);
    } catch (e) {
      debugPrint('GemmaService: dispatch failed — $e. Using fallback.');
      return _dispatchFallback(userMessage);
    }
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

      await _adapter
          .streamResponse()
          .timeout(_streamTimeout)
          .forEach((token) {
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
      await _adapter
          .streamResponse()
          .timeout(_streamTimeout)
          .forEach((token) => buffer.write(token));
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
  Future<_RondaResult?> _generarRonda() async {
    final buffer = StringBuffer();
    final toolCalls = <FunctionCallResponse>[];
    var sawToolCall = false;

    await _adapter
        .streamChatResponse()
        .timeout(_streamTimeout)
        .forEach((res) {
      if (res is TextResponse) {
        buffer.write(res.token);
      } else if (res is FunctionCallResponse) {
        sawToolCall = true;
        toolCalls.add(res);
      } else if (res is ParallelFunctionCallResponse) {
        sawToolCall = true;
        toolCalls.addAll(res.calls);
      }
    });

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

  bool _esSaludo(String message) {
    final m = message.trim().toLowerCase();
    return RegExp(
      r'^(hola|buenas|buen dia|buenos dias|buen día|buenos días|'
      r'buenas tardes|buenas noches|hey|que tal|qué tal|saludos)\b',
    ).hasMatch(m);
  }

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
}

/// Outcome of a single dispatch round: either accumulated [text] or the
/// [toolCalls] the model requested (never both).
class _RondaResult {
  final String? text;
  final List<FunctionCallResponse>? toolCalls;

  const _RondaResult({this.text, this.toolCalls});
}
