import '../tool_registry.dart';

/// Handler for the `registrar_interaccion` tool.
///
/// Records an interaction event via [ctx.studentState] when available.
/// This provides an audit trail of tool usage (for offline analytics
/// and to drive adaptive content selection).
///
/// Args:
/// - `tipo` (String): interaction type (explicacion, ejercicio, diagnostico)
/// - `tema` (String): the topic involved
/// - `resultado` (String): "correcta" or "incorrecta" (optional)
Future<ToolResult> registrarInteraccionHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final tipo = args['tipo'] as String? ?? 'desconocido';
  final tema = args['tema'] as String? ?? 'no_especificado';
  final resultado = args['resultado'] as String?;

  // If studentState is available, record the interaction.
  if (ctx.studentState != null) {
    try {
      final isCorrect = resultado == 'correcta';
      ctx.studentState.recordInteraction(isCorrect: isCorrect);

      return ToolResult(
        summary:
            'Interacción registrada: $tipo sobre "$tema"'
            '${resultado != null ? " ($resultado)" : ""}.',
        payload: {
          'tipo': tipo,
          'tema': tema,
          'resultado': resultado ?? 'no_evaluado',
          'registrado': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Fall through to fallback below.
    }
  }

  // Fallback: studentState not initialized.
  return ToolResult(
    summary:
        'Interacción anotada: $tipo sobre "$tema". '
        '¡Seguimos aprendiendo!',
    payload: {
      'tipo': tipo,
      'tema': tema,
      'resultado': resultado ?? 'no_evaluado',
      'registrado': false,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
}

/// The registered [ToolSpec] for `registrar_interaccion`.
const registrarInteraccionSpec = ToolSpec(
  name: 'registrar_interaccion',
  description:
      'Registra una interacción del estudiante (explicación, ejercicio, '
      'diagnóstico) para análisis y adaptación',
  params: [
    ToolParam(
      name: 'tipo',
      description: 'Tipo de interacción (explicacion, ejercicio, diagnostico)',
      required: true,
    ),
    ToolParam(
      name: 'tema',
      description: 'Tema relacionado con la interacción',
      required: true,
    ),
    ToolParam(
      name: 'resultado',
      description: '"correcta" o "incorrecta" (opcional)',
    ),
  ],
  handler: registrarInteraccionHandler,
);
