import 'dart:math';

import '../yachay/tool_handlers/consultar_estado.dart';
import '../yachay/tool_handlers/evaluar_respuesta.dart';
import '../yachay/tool_handlers/obtener_siguiente_tema.dart';
import '../yachay/tool_handlers/obtener_plan_completo.dart';
import '../yachay/tool_handlers/generar_nota_progreso.dart';
import '../yachay/tool_handlers/generar_resumen_alumno.dart';
import '../yachay/tool_handlers/iniciar_conversacion.dart';
import 'tool_registry.dart';
import 'tool_handlers/explicar_tema.dart';
import 'tool_handlers/generar_ejercicios.dart';
import 'tool_handlers/ejecutar_diagnostico.dart';
import 'tool_handlers/obtener_perfil.dart';
import 'tool_handlers/obtener_leccion.dart';
import 'tool_handlers/registrar_interaccion.dart';

/// Result of Layer 2 keyword-intent detection.
class _DetectedIntent {
  final String tool;
  final Map<String, String> args;

  const _DetectedIntent(this.tool, this.args);
}

/// 4-layer deterministic dispatch that powers the DEGRADED (no-AI) mode.
///
/// Whenever the on-device model is unavailable — first run (`Sin modelo`),
/// still downloading/verifying, auth/storage error, or a native inference
/// failure — the app keeps tutoring through this dispatcher instead of
/// crashing or going silent. It is the guaranteed-response backbone of the
/// offline-first design, not a last-resort hack (stakeholder needs N-01,
/// N-03, N-04).
///
/// Evaluates layers in order, short-circuiting at the first match:
///
/// | Layer | Trigger                    | Response                              |
/// |-------|----------------------------|---------------------------------------|
/// | 1     | Trivial greeting regex     | Instant Spanish encouragement         |
/// | 2     | Keyword → tool mapping     | Route to tool with bundled args       |
/// | 3     | Tool execution (local)     | Look up pre-authored content from JSON |
/// | 4     | No match                   | Generic Peruvian-Spanish encouragement |
///
/// The dispatcher guarantees a pedagogically sound response at every failure
/// point, independent of model availability. The status chip (driven by
/// [ModelStatusController]) keeps showing the real model state while the
/// student continues chatting in this mode.
class FallbackDispatcher {
  final Map<String, dynamic> _data;
  final ToolRegistry _registry;
  late final ToolContext _ctx;

  /// Creates a dispatcher backed by the full fallback JSON data.
  ///
  /// [fallbackData] must contain the extended structure with
  /// `trivial_greetings`, `keyword_intents`, `topic_keywords`,
  /// `generic_responses`, and the legacy `topicId → level` entries.
  FallbackDispatcher({required Map<String, dynamic> fallbackData})
      : _data = fallbackData,
        _registry = ToolRegistry() {
    // Register all 13 tool handlers.
    _registry.register(explicarTemaSpec);
    _registry.register(generarEjerciciosSpec);
    _registry.register(ejecutarDiagnosticoSpec);
    _registry.register(obtenerPerfilSpec);
    _registry.register(obtenerLeccionSpec);
    _registry.register(registrarInteraccionSpec);

    // Yachay tools.
    _registry.register(consultarEstadoSpec);
    _registry.register(evaluarRespuestaSpec);
    _registry.register(obtenerSiguienteTemaSpec);
    _registry.register(obtenerPlanCompletoSpec);
    _registry.register(generarNotaProgresoSpec);
    _registry.register(generarResumenAlumnoSpec);
    _registry.register(iniciarConversacionSpec);

    // Build a ToolContext with fallbackData for the handlers that
    // rely on bundled JSON content.
    _ctx = ToolContext(fallbackData: _data);
  }

  // ---- Public API ----

  /// Dispatches [userMessage] through the 4-layer fallback system.
  ///
  /// Returns a Spanish-language response. Never returns empty — Layer 4
  /// always provides a generic fallback.
  Future<String> dispatch(String userMessage) async {
    final trimmed = userMessage.trim().toLowerCase();

    // Guard: empty or whitespace-only messages go straight to L4.
    if (trimmed.isEmpty) {
      return _layer4Generic();
    }

    // ---- Layer 1: Trivial Greeting ----
    final greeting = _layer1Greeting(trimmed);
    if (greeting != null) return greeting;

    // ---- Layer 2: Keyword Intent Detection ----
    final intent = _layer2DetectIntent(trimmed);
    if (intent != null) {
      // ---- Layer 3: Deterministic Tool Execution ----
      final result = await _layer3ExecuteTool(intent.tool, intent.args);
      if (result != null) return result;
    }

    // ---- Layer 4: Generic Fallback ----
    return _layer4Generic();
  }

  // ---- Layer 1: Trivial Greeting Gate ----

  /// Checks [lowered] against the `trivial_greetings` pattern table.
  /// Each pattern is treated as a plain-text substring (no RegExp) for
  /// deterministic, allocation-light matching.
  /// Returns the matching response or `null` if no greeting matches.
  String? _layer1Greeting(String lowered) {
    final greetings = _data['trivial_greetings'];
    if (greetings is! List) return null;

    for (final entry in greetings) {
      if (entry is! Map<String, dynamic>) continue;
      final pattern = (entry['pattern'] ?? entry['regex']) as String?;
      final response = entry['response'] as String?;
      if (pattern == null || response == null) continue;

      if (lowered.contains(pattern.toLowerCase())) {
        return response;
      }
    }

    return null;
  }

  // ---- Layer 2: Keyword Intent Detection ----

  /// Scans [lowered] for tool-intent keywords and topic keywords.
  ///
  /// Returns a `_DetectedIntent` with the tool name and extracted args,
  /// or `null` if no tool intent is recognized.
  _DetectedIntent? _layer2DetectIntent(String lowered) {
    final intents = _data['keyword_intents'];
    if (intents is! Map<String, dynamic>) return _detectYachayIntent(lowered);

    // Step A: find which tool the message is asking for.
    String? matchedTool;
    for (final entry in intents.entries) {
      final toolName = entry.key;
      final patterns = entry.value;
      if (patterns is! List) continue;

      for (final p in patterns) {
        if (p is String && lowered.contains(p.toLowerCase())) {
          matchedTool = toolName;
          break;
        }
      }
      if (matchedTool != null) break;
    }

    // Step B: extract topic from the message.
    final topicId = _extractTopic(lowered);

    // If a topic keyword matched but no tool intent, default to explicar_tema.
    if (matchedTool == null && topicId != null) {
      matchedTool = 'explicar_tema';
    }

    // Yachay keywords override.
    matchedTool ??= _detectYachayKeyword(lowered);

    // If no tool and no topic, L2 has nothing to route.
    if (matchedTool == null) return null;

    // Build args.
    final args = <String, String>{};
    if (topicId != null) {
      args['tema'] = topicId;
    }

    // For diagnostic, add materia hint.
    if (matchedTool == 'ejecutar_diagnostico') {
      args['materia'] =
          (topicId != null && topicId.startsWith('L')) ? 'lectura' : 'matematica';
    }

    // Default nivel.
    if (!args.containsKey('nivel')) {
      args['nivel'] = '1';
    }

    return _DetectedIntent(matchedTool, args);
  }

  /// Detects Yachay-specific keywords for Layer 2 fallback.
  String? _detectYachayKeyword(String lowered) {
    if (_matchesAnyYachay(lowered, ['como voy', 'mi progreso', 'progreso', 'avance'])) {
      return 'consultar_estado';
    }
    if (_matchesAnyYachay(lowered, ['siguiente tema', 'que sigue', 'qué sigue', 'continuar'])) {
      return 'obtener_siguiente_tema';
    }
    if (_matchesAnyYachay(lowered, ['plan completo', 'todos los temas', 'plan de estudios'])) {
      return 'obtener_plan_completo';
    }
    if (_matchesAnyYachay(lowered, ['resumen', 'que sabes de mi', 'qué sabes de mí', 'perfil'])) {
      return 'generar_resumen_alumno';
    }
    return null;
  }

  /// Keyword detection without JSON intents (bare fallback).
  _DetectedIntent? _detectYachayIntent(String lowered) {
    final tool = _detectYachayKeyword(lowered) ?? _detectBasicIntent(lowered);
    if (tool == null) return null;
    return _DetectedIntent(tool, <String, String>{'nivel': '1'});
  }

  /// Basic intent detection when no keyword_intents JSON is available.
  String? _detectBasicIntent(String lowered) {
    if (_matchesAnyYachay(lowered, ['explica', 'explicar', 'que es', 'qué es'])) {
      return 'explicar_tema';
    }
    if (_matchesAnyYachay(lowered, ['ejercicio', 'practica', 'practicar'])) {
      return 'generar_ejercicios';
    }
    return null;
  }

  /// Returns true when [text] contains any Yachay keyword pattern.
  bool _matchesAnyYachay(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  /// Scans [lowered] for known topic keywords and returns the corresponding
  /// topic ID from the JSON, or `null` if no topic match.
  String? _extractTopic(String lowered) {
    final topics = _data['topic_keywords'];
    if (topics is! Map<String, dynamic>) return null;

    // Sort by keyword length descending so longer phrases match first
    // (e.g. "tanto por ciento" before "porcentaje").
    final sorted = topics.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sorted) {
      final keyword = entry.key.toLowerCase();
      if (lowered.contains(keyword)) {
        return entry.value as String?;
      }
    }

    return null;
  }

  // ---- Layer 3: Deterministic Tool Execution ----

  /// Executes [tool] with [args] via the [ToolRegistry].
  ///
  /// Returns the pre-authored response or `null` if the tool cannot
  /// produce a result (delegates to Layer 4 in that case).
  Future<String?> _layer3ExecuteTool(
    String tool,
    Map<String, String> args,
  ) async {
    // Convert String args to Map<String, dynamic> for ToolRegistry.
    final dynArgs = args.map((k, v) => MapEntry(k, v as dynamic));

    final result = await _registry.run(tool, dynArgs, _ctx);

    // If the tool returned an error summary (unknown tool), treat as
    // no-match and let Layer 4 handle it.
    if (result.summary.startsWith('Error:')) return null;

    // Tools that return non-text payloads (e.g. exercise lists) are
    // handled by the handler's summary, which includes a description.
    return result.summary;
  }

  // ---- Layer 4: Generic Encouragement ----

  /// Returns a random generic encouragement in Peruvian Spanish,
  /// with Yachay Socratic tutor persona when no keyword matches.
  String _layer4Generic() {
    final generics = _data['generic_responses'];
    if (generics is! List || generics.isEmpty) {
      return _yachayFallback();
    }

    final random = Random();
    return (generics[random.nextInt(generics.length)] as String?) ??
        _yachayFallback();
  }

  /// Yachay Socratic fallback response — used when no other layer matches.
  String _yachayFallback() {
    const yachayResponses = [
      '¡Hola! Soy Yachay, tu tutor de aritmética. '
          '¿Qué te gustaría aprender hoy? Podemos empezar con números, '
          'fracciones o lo que vos elijas.',

      'Estoy aquí para ayudarte. ¿Hay algún tema de aritmética '
          'que te esté costando? No tengas miedo de preguntar — '
          'equivocarse es parte de aprender.',

      '¿En qué tema querés enfocarte? Puedo explicarte, darte ejercicios '
          'o mostrarte tu progreso. Vos decidís.',

      '¡Qué bueno verte! ¿Seguimos practicando donde lo dejamos? '
          'Decime en qué tema te gustaría trabajar.',
    ];

    final random = Random();
    return yachayResponses[random.nextInt(yachayResponses.length)];
  }
}
