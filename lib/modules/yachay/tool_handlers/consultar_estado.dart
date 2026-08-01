import '../../gemma/tool_registry.dart';
import '../bkt_engine.dart';

/// Handler for the `consultar_estado` tool.
///
/// Queries the student's mastery state for a specific topic via the
/// in-memory [ctx.studentState.masteryMap]. Returns P(L), attempts,
/// consecutive count, and mastery flag.
///
/// Args:
/// - `tema` (String, required): broad topic area (e.g. "fracciones")
/// - `subtema` (String, required): specific subtopic (e.g. "identificar")
Future<ToolResult> consultarEstadoHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final tema = args['tema'] as String? ?? '';
  final subtema = args['subtema'] as String? ?? '';
  final topicId = '$tema/$subtema';

  final state = ctx.studentState;
  Map<String, dynamic>? masteryEntry;

  if (state != null && state.masteryMap != null) {
    final masteryMap = state.masteryMap as Map;
    for (final entry in masteryMap.entries) {
      final key = entry.key as String;
      if (key.endsWith('|$topicId')) {
        final m = entry.value;
        masteryEntry = {
          'p_l': (m.pLearned as num).toDouble(),
          'intentos': m.attempts as int? ?? 0,
          'consecutivas_correctas': m.consecutiveCorrect as int? ?? 0,
          'dominado': BktEngine.isMastered(
              (m.pLearned as num).toDouble()),
        };
        break;
      }
    }
  }

  if (masteryEntry == null) {
    masteryEntry = {
      'p_l': 0.0,
      'intentos': 0,
      'consecutivas_correctas': 0,
      'dominado': false,
    };
  }

  final pL = masteryEntry['p_l'] as double;
  final porcentaje = (pL * 100).round();

  return ToolResult(
    summary:
        'Tu progreso en "$subtema" ($tema) es de $porcentaje%. '
        '${pL >= BktEngine.masteryThreshold ? "¡Ya lo dominaste!" : "Seguí practicando."}',
    payload: {
      'tema': topicId,
      'p_l': pL,
      'porcentaje': porcentaje,
      'intentos': masteryEntry['intentos'],
      'consecutivas_correctas': masteryEntry['consecutivas_correctas'],
      'dominado': masteryEntry['dominado'],
    },
  );
}

/// The registered [ToolSpec] for `consultar_estado`.
const consultarEstadoSpec = ToolSpec(
  name: 'consultar_estado',
  description:
      'Consulta el progreso del estudiante en un tema específico. '
      'Devuelve el porcentaje de dominio (0-100%), intentos y si ya lo domina.',
  params: [
    ToolParam(
      name: 'tema',
      description: 'Área del tema (ej. "fracciones", "geometria")',
      required: true,
    ),
    ToolParam(
      name: 'subtema',
      description: 'Subtema específico (ej. "identificar", "suma")',
      required: true,
    ),
  ],
  handler: consultarEstadoHandler,
);
