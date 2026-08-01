import '../../gemma/tool_registry.dart';
import '../bkt_engine.dart';

/// Handler for the `obtener_siguiente_tema` tool.
///
/// Traverses the curriculum DAG via [ctx.curriculum] to find the first
/// unlocked but not-yet-mastered subtopic. Uses [ctx.studentState]
/// mastery data to determine lock/mastery state.
///
/// Args: none (implicit — reads from context).
Future<ToolResult> obtenerSiguienteTemaHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final curriculum = ctx.curriculum;
  if (curriculum == null) {
    return ToolResult(
      summary:
          'No tengo el plan de estudios disponible en este momento. '
          '¿Podrías decirme qué tema te gustaría practicar?',
      payload: {'error': 'sin_curriculo'},
    );
  }

  // Build set of mastered topic IDs from mastery state.
  final masteredIds = <String>{};
  final state = ctx.studentState;
  if (state != null && state.masteryMap != null) {
    final masteryMap = state.masteryMap as Map;
    for (final entry in masteryMap.entries) {
      final m = entry.value;
      try {
        final pLearned = (m.pLearned as num).toDouble();
        if (BktEngine.isMastered(pLearned)) {
          final key = entry.key as String;
          final parts = key.split('|');
          if (parts.length == 2) {
            masteredIds.add(parts[1]);
          }
        }
      } catch (_) {
        // Skip malformed entries.
      }
    }
  }

  try {
    final siguiente = curriculum.obtenerSiguienteTema(masteredIds);
    if (siguiente == null) {
      return ToolResult(
        summary:
            'No encontré un siguiente tema disponible. '
            '¿Querés repasar algo en particular?',
        payload: {'encontrado': false},
      );
    }

    // Completion check — the curriculum returns special payload when done.
    if (siguiente['completado'] == true) {
      return ToolResult(
        summary: siguiente['mensaje'] as String? ??
            '¡Felicitaciones! Has dominado todos los temas.',
        payload: siguiente,
      );
    }

    final titulo = siguiente['titulo'] as String? ?? 'siguiente tema';
    return ToolResult(
      summary:
          'El siguiente tema para vos es "$titulo" '
          '(de ${siguiente['competencia_titulo'] ?? ''}). '
          '¿Empezamos?',
      payload: siguiente,
    );
  } catch (e) {
    return ToolResult(
      summary:
          'No pude determinar el siguiente tema. Error: $e. '
          '¿Qué te gustaría aprender?',
      payload: {'error': 'excepcion', 'detalle': '$e'},
    );
  }
}

/// The registered [ToolSpec] for `obtener_siguiente_tema`.
const obtenerSiguienteTemaSpec = ToolSpec(
  name: 'obtener_siguiente_tema',
  description:
      'Encuentra el siguiente tema desbloqueado que el estudiante aún no domina, '
      'basado en el plan de estudios y sus prerrequisitos.',
  params: [],
  handler: obtenerSiguienteTemaHandler,
);
