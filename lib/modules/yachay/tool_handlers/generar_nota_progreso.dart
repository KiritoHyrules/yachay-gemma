import '../../gemma/tool_registry.dart';
import '../bkt_engine.dart';

/// Handler for the `generar_nota_progreso` tool.
///
/// Generates a personalized progress note for a specific topic using
/// template-based encouragement (mini-inference without separate model call).
/// Reads current P(L) from [ctx.studentState] and crafts a context-aware message.
///
/// Args:
/// - `tema` (String, required): topic name for the note
Future<ToolResult> generarNotaProgresoHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final tema = args['tema'] as String? ?? 'este tema';

  // Try to find P(L) for matching topic.
  double pLearned = 0.0;
  final state = ctx.studentState;
  if (state != null && state.masteryMap != null) {
    final masteryMap = state.masteryMap as Map;
    for (final entry in masteryMap.entries) {
      final key = entry.key as String;
      if (key.toLowerCase().contains(tema.toLowerCase())) {
        final m = entry.value;
        try {
          pLearned = (m.pLearned as num).toDouble();
        } catch (_) {}
        break;
      }
    }
  }

  final porcentaje = (pLearned * 100).round();
  final nota = _buildNota(tema, porcentaje, pLearned);

  return ToolResult(
    summary: nota,
    payload: {
      'tema': tema,
      'p_l': pLearned,
      'porcentaje': porcentaje,
      'tipo': 'nota_progreso',
    },
  );
}

/// Builds a personalized encouragement note based on P(L) level.
String _buildNota(String tema, int porcentaje, double pLearned) {
  if (pLearned >= 0.90) {
    return '¡Excelente trabajo con "$tema"! '
        'Lo dominaste con $porcentaje%. '
        'Estás listo para el siguiente desafío. ¡Seguí así! 💪';
  } else if (pLearned >= 0.60) {
    return 'Vas muy bien con "$tema". '
        'Ya tenés un $porcentaje% de dominio. '
        'Con un poco más de práctica, ¡lo vas a dominar completamente! '
        '¿Querés hacer un ejercicio de práctica?';
  } else if (pLearned > 0.0) {
    return 'Estás empezando con "$tema" y ya tenés un $porcentaje%. '
        'Es normal que al principio cueste — cada ejercicio te acerca más. '
        '¿Te explico este tema de otra manera?';
  } else {
    return 'Todavía no empezamos con "$tema". '
        'Cuando quieras, podemos arrancar. '
        '¿Te gustaría que te explique de qué se trata?';
  }
}

/// The registered [ToolSpec] for `generar_nota_progreso`.
const generarNotaProgresoSpec = ToolSpec(
  name: 'generar_nota_progreso',
  description:
      'Genera una nota personalizada sobre el progreso del estudiante '
      'en un tema específico, con aliento y recomendaciones.',
  params: [
    ToolParam(
      name: 'tema',
      description: 'Nombre del tema (ej. "Fracciones", "Decimales")',
      required: true,
    ),
  ],
  handler: generarNotaProgresoHandler,
);
