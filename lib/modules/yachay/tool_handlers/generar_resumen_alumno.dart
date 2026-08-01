import '../../gemma/tool_registry.dart';
import '../bkt_engine.dart';

/// Handler for the `generar_resumen_alumno` tool.
///
/// Generates a "Lo que Yachay sabe de vos" summary paragraph based on the
/// student's overall mastery statistics. Uses template-based text generation
/// (mini-inference without separate model call).
///
/// Args: none (reads all data from [ctx.studentState]).
Future<ToolResult> generarResumenAlumnoHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final state = ctx.studentState;

  int totalTemas = 0;
  int dominados = 0;
  double sumaPL = 0.0;
  String? mejorTema;

  if (state != null && state.masteryMap != null) {
    final masteryMap = state.masteryMap as Map;
    totalTemas = masteryMap.length;

    for (final entry in masteryMap.entries) {
      final m = entry.value;
      try {
        final pLearned = (m.pLearned as num).toDouble();
        sumaPL += pLearned;
        if (BktEngine.isMastered(pLearned)) {
          dominados++;
        }
        // Track best topic.
        if (pLearned >= 0.90) {
          final key = entry.key as String;
          final parts = key.split('|');
          if (parts.length == 2) {
            mejorTema ??= parts[1];
          }
        }
      } catch (_) {}
    }
  }

  final promedio = totalTemas > 0 ? (sumaPL / totalTemas * 100).round() : 0;
  final resumen = _buildResumen(totalTemas, dominados, promedio, mejorTema);

  return ToolResult(
    summary: resumen,
    payload: {
      'total_temas': totalTemas,
      'temas_dominados': dominados,
      'promedio_porcentaje': promedio,
      'mejor_tema': mejorTema,
      'tipo': 'resumen_alumno',
    },
  );
}

/// Builds the student profile summary paragraph.
String _buildResumen(
  int totalTemas,
  int dominados,
  int promedio,
  String? mejorTema,
) {
  if (totalTemas == 0) {
    return 'Hola, soy Yachay, tu tutor de aritmética. '
        'Todavía no tengo datos sobre tu progreso, '
        'pero estoy listo para ayudarte a aprender. '
        '¿Qué tema te gustaría empezar?';
  }

  final buffer = StringBuffer();
  buffer.write('¡Hola! Esto es lo que sé sobre tu aprendizaje:\n\n');

  buffer.write('Has trabajado en $totalTemas temas');

  if (dominados > 0) {
    buffer.write(', de los cuales ya dominaste $dominados');
    if (mejorTema != null) {
      buffer.write('. ¡Excelente trabajo en "$mejorTema"!');
    } else {
      buffer.write('. ¡Excelente trabajo!');
    }
  } else {
    buffer.write('. Todavía no dominaste ninguno, '
        'pero vas por buen camino.');
  }

  buffer.write('\n\nTu progreso general es de $promedio%. ');

  if (promedio >= 80) {
    buffer.write(
        '¡Estás haciendo un trabajo increíble! '
        'Seguí practicando para mantener ese nivel.');
  } else if (promedio >= 50) {
    buffer.write(
        'Vas muy bien. Con un poco más de práctica '
        'en los temas que te cuestan, vas a mejorar mucho.');
  } else {
    buffer.write(
        'Estás empezando y eso es lo más importante. '
        'Cada ejercicio te acerca más a dominar los temas.');
  }

  return buffer.toString();
}

/// The registered [ToolSpec] for `generar_resumen_alumno`.
const generarResumenAlumnoSpec = ToolSpec(
  name: 'generar_resumen_alumno',
  description:
      'Genera un resumen personalizado del progreso del estudiante: '
      '"Lo que Yachay sabe de vos". Incluye temas dominados, promedio y aliento.',
  params: [],
  handler: generarResumenAlumnoHandler,
);
