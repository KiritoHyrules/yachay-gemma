import '../../gemma/tool_registry.dart';
import '../bkt_engine.dart';

/// Handler for the `obtener_plan_completo` tool.
///
/// Returns the full curriculum with each subtopic annotated with mastery
/// status (dominado, bloqueado) based on the student's current state.
/// Uses [ctx.curriculum] for the DAG and [ctx.studentState] for mastery.
///
/// Args: none (implicit — reads from context).
Future<ToolResult> obtenerPlanCompletoHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final curriculum = ctx.curriculum;
  if (curriculum == null) {
    return ToolResult(
      summary:
          'No tengo el plan de estudios cargado en este momento.',
      payload: <Map<String, dynamic>>[],
    );
  }

  // Build set of mastered topic IDs.
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
    final plan = curriculum.obtenerPlanCompleto(masteredIds);
    if (plan is! List) {
      return ToolResult(
        summary: 'Plan de estudios no disponible.',
        payload: <Map<String, dynamic>>[],
      );
    }

    final total = plan.length;
    final dominados = plan.where((t) => t['dominado'] == true).length;
    final desbloqueados =
        plan.where((t) => t['bloqueado'] == false && t['dominado'] == false).length;

    return ToolResult(
      summary:
          'Tu plan de Aritmética tiene $total temas. '
          'Ya dominaste $dominados, tenés $desbloqueados disponibles para practicar, '
          'y el resto están bloqueados (necesitás completar los prerrequisitos).',
      payload: plan,
    );
  } catch (e) {
    return ToolResult(
      summary: 'No pude cargar el plan de estudios. Error: $e.',
      payload: <Map<String, dynamic>>[],
    );
  }
}

/// The registered [ToolSpec] for `obtener_plan_completo`.
const obtenerPlanCompletoSpec = ToolSpec(
  name: 'obtener_plan_completo',
  description:
      'Muestra el plan de estudios completo de Aritmética con el estado '
      'de cada tema (dominado, disponible, bloqueado).',
  params: [],
  handler: obtenerPlanCompletoHandler,
);
