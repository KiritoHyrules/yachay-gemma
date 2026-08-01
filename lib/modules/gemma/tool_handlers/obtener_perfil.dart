import '../tool_registry.dart';

/// Handler for the `obtener_perfil` tool.
///
/// Reads the current student's profile from [ctx.studentState] when
/// available. Returns profile metadata as the [ToolResult.payload].
/// When the student state is not initialized (testing / early app
/// lifecycle), returns a graceful fallback message.
///
/// Args:
/// - None required.
Future<ToolResult> obtenerPerfilHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  // Try to read from StudentState.
  if (ctx.studentState != null) {
    try {
      final profile = ctx.studentState.profile;
      if (profile != null) {
        return ToolResult(
          summary:
              'Perfil de ${profile.alias}: nivel matemática '
              '${profile.mathLevel}, nivel lectura ${profile.readingLevel}.',
          payload: {
            'alias': profile.alias,
            'mathLevel': profile.mathLevel,
            'readingLevel': profile.readingLevel,
            'totalTimeMin': profile.totalTimeMin,
          },
        );
      }
    } catch (_) {
      // Fall through to fallback below.
    }
  }

  // Fallback: no profile available.
  return ToolResult(
    summary:
        'Todavía no tengo tu perfil. Cuando completes el diagnóstico '
        'inicial, podré decirte en qué nivel estás y recomendarte '
        'lecciones adaptadas a ti.',
    payload: {
      'alias': 'Estudiante',
      'mathLevel': 1,
      'readingLevel': 1,
      'totalTimeMin': 0,
    },
  );
}

/// The registered [ToolSpec] for `obtener_perfil`.
const obtenerPerfilSpec = ToolSpec(
  name: 'obtener_perfil',
  description:
      'Obtiene el perfil actual del estudiante con sus niveles de '
      'matemática y lectura',
  params: const [],
  handler: obtenerPerfilHandler,
);
