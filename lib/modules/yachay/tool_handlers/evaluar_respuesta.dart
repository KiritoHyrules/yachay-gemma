import '../../gemma/tool_registry.dart';
import '../bkt_engine.dart';

/// Handler for the `evaluar_respuesta` tool.
///
/// Updates the BKT model after a student's answer. Computes the new P(L)
/// via [BktEngine.updatePLearned], persists to [ctx.studentState], and
/// returns feedback with the updated mastery status.
///
/// Args:
/// - `tema` (String, required): broad topic area
/// - `subtema` (String, required): specific subtopic
/// - `correcta` (bool, required): whether the answer was correct
Future<ToolResult> evaluarRespuestaHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final tema = args['tema'] as String? ?? '';
  final subtema = args['subtema'] as String? ?? '';
  final correcta = args['correcta'] as bool? ?? false;
  final topicId = '$tema/$subtema';

  final state = ctx.studentState;

  // Find current P(L) from mastery map.
  double currentPL = BktEngine.pLearn0;
  String studentId = 'default';
  bool found = false;

  if (state != null && state.masteryMap != null) {
    final masteryMap = state.masteryMap as Map;
    for (final entry in masteryMap.entries) {
      final key = entry.key as String;
      if (key.endsWith('|$topicId')) {
        final m = entry.value;
        currentPL = (m.pLearned as num).toDouble();
        studentId = entry.key.toString().split('|').first;
        found = true;
        break;
      }
    }

    // Try profile for student ID when no mastery entry exists yet.
    if (!found && state.profile != null) {
      try {
        studentId = state.profile.id as String? ?? 'default';
      } catch (_) {
        studentId = 'default';
      }
    }
  }

  // Compute new P(L).
  final newPL = BktEngine.updatePLearned(currentPL, correcta);
  final dominio = BktEngine.isMastered(newPL);

  // Persist via StudentState.actualizarMastery (duck-typed — works with
  // in-memory state even when DB is not initialized).
  if (state != null) {
    try {
      await state.actualizarMastery(studentId, topicId, correcta);
    } catch (_) {
      // actualizarMastery may not exist on non-StudentState contexts;
      // silently proceed — the computed values are still in the payload.
    }
  }

  final porcentajeAnterior = (currentPL * 100).round();
  final porcentajeNuevo = (newPL * 100).round();

  final summary = correcta
      ? '¡Respuesta correcta en "$subtema"! '
          'Tu dominio pasó de $porcentajeAnterior% a $porcentajeNuevo%. '
          '${dominio ? "¡Felicitaciones, dominaste este tema!" : "¡Seguí así!"} '
          '${!dominio && porcentajeNuevo >= 80 ? "¡Estás muy cerca de dominarlo!" : ""}'
      : 'Respuesta incorrecta en "$subtema". '
          'No te preocupes, equivocarse es parte de aprender. '
          'Tu dominio ahora es $porcentajeNuevo%. '
          '¿Querés que te explique este tema de otra manera?';

  return ToolResult(
    summary: summary,
    payload: {
      'tema': topicId,
      'correcta': correcta,
      'p_l_anterior': currentPL,
      'nuevo_p_l': newPL,
      'porcentaje_anterior': porcentajeAnterior,
      'porcentaje_nuevo': porcentajeNuevo,
      'dominado': dominio,
    },
  );
}

/// The registered [ToolSpec] for `evaluar_respuesta`.
const evaluarRespuestaSpec = ToolSpec(
  name: 'evaluar_respuesta',
  description:
      'Evalúa si la respuesta del estudiante fue correcta o incorrecta '
      'y actualiza su progreso. Usalo después de cada ejercicio.',
  params: [
    ToolParam(
      name: 'tema',
      description: 'Área del tema (ej. "fracciones")',
      required: true,
    ),
    ToolParam(
      name: 'subtema',
      description: 'Subtema específico (ej. "suma")',
      required: true,
    ),
    ToolParam(
      name: 'correcta',
      description: '"true" si la respuesta es correcta, "false" si no',
      required: true,
    ),
  ],
  handler: evaluarRespuestaHandler,
);
