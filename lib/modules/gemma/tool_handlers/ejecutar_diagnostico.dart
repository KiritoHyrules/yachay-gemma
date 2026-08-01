import '../tool_registry.dart';

/// Handler for the `ejecutar_diagnostico` tool.
///
/// When [ctx.diagnosticoService] is available, delegates to
/// `DiagnosticoService.ejecutarComoHerramienta()` for a full IRT
/// diagnostic run. When the service is unavailable (testing /
/// not yet initialized), returns a fallback diagnostic based on
/// the student profile or a default level.
///
/// Args:
/// - `materia` (String, optional): "matematicas" or "lectura",
///   defaults to "matematicas"
Future<ToolResult> ejecutarDiagnosticoHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final materia = args['materia'] as String? ?? 'matematica';

  // Try the full diagnostic service first.
  if (ctx.diagnosticoService != null) {
    try {
      final perfil =
          ctx.studentState != null ? ctx.studentState.profile : null;
      return await ctx.diagnosticoService
          .ejecutarComoHerramienta(materia, perfil);
    } catch (_) {
      // Fall through to fallback below.
    }
  }

  // Fallback: return a friendly message directing the student to the
  // diagnostic screen, with payload metadata.
  final nivel = 3; // Default: Practicante
  const etiqueta = 'Practicante';

  if (materia == 'lectura') {
    return ToolResult(
      summary:
          '¡Buena idea! Hagamos un diagnóstico de comprensión lectora. '
          'Así sabremos en qué nivel estás y por dónde empezar.\n\n'
          'Para hacer el diagnóstico, ve a la sección de Diagnóstico '
          'en la aplicación y selecciona "Lectura". Te haré preguntas '
          'adaptadas a tu nivel y al final te diré si eres Explorador, '
          'Aprendiz, Competente, Avanzado o Experto.\n\n'
          '¿Quieres que te explique cómo funciona el diagnóstico?',
      payload: {
        'materia': 'lectura',
        'nivel': nivel,
        'etiqueta': etiqueta,
        'itemsAdministrados': 0,
      },
    );
  }

  return ToolResult(
    summary:
        '¡Buena idea! Hagamos un diagnóstico de matemática. '
        'Así sabremos en qué nivel estás y por dónde empezar.\n\n'
        'Para hacer el diagnóstico, ve a la sección de Diagnóstico '
        'en la aplicación y selecciona "Matemática". Te haré preguntas '
        'adaptadas a tu nivel y al final te diré si eres Explorador, '
        'Aprendiz, Competente, Avanzado o Experto.\n\n'
        '¿Quieres que te explique cómo funciona el diagnóstico?',
    payload: {
      'materia': 'matematica',
      'nivel': nivel,
      'etiqueta': etiqueta,
      'itemsAdministrados': 0,
    },
  );
}

/// The registered [ToolSpec] for `ejecutar_diagnostico`.
const ejecutarDiagnosticoSpec = ToolSpec(
  name: 'ejecutar_diagnostico',
  description:
      'Ejecuta un diagnóstico adaptativo (IRT 2PL) para medir el nivel '
      'del estudiante en matemática o lectura',
  params: [
    ToolParam(
      name: 'materia',
      description: '"matematicas" o "lectura" — por defecto "matematicas"',
    ),
  ],
  handler: ejecutarDiagnosticoHandler,
);
