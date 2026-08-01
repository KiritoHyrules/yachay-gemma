import '../tool_registry.dart';

/// Handler for the `explicar_tema` tool.
///
/// Looks up pre-authored lesson content from [ctx.fallbackData] and
/// returns an explanation at the requested topic and level.
///
/// Args:
/// - `tema` (String, required): topic ID like "M001_fracciones"
/// - `nivel` (String, optional): difficulty level, defaults to "1"
Future<ToolResult> explicarTemaHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final tema = args['tema'] as String?;
  final nivel = args['nivel'] as String? ?? '1';

  if (tema == null) {
    return ToolResult(
      summary:
          'Cuéntame qué tema quieres que te explique. '
          'Puedo ayudarte con fracciones, ecuaciones, porcentajes, '
          'comprensión lectora, y más.',
      payload: {'estado': 'sin_tema'},
    );
  }

  final data = ctx.fallbackData;
  final cleanName = tema.replaceAll(RegExp(r'^[A-Z]\d+_'), '');

  if (data != null) {
    // Handle generic subject fallbacks.
    if (tema == '_generic_math') {
      return ToolResult(
        summary:
            'Las matemáticas son una herramienta poderosa. '
            'Podemos empezar con fracciones (cómo repartir), '
            'ecuaciones (encontrar valores desconocidos) o '
            'porcentajes (descuentos y proporciones). '
            '¿Cuál de estos temas te gustaría explorar primero?',
        payload: {'tema': tema, 'tipo': 'generico_matematica'},
      );
    }
    if (tema == '_generic_reading') {
      return ToolResult(
        summary:
            'La comunicación es fundamental para expresarnos y entender '
            'a los demás. Podemos practicar comprensión lectora '
            '(entender lo que leemos) o trabajar inferencias '
            '(descubrir lo que el texto no dice directamente). '
            '¿Qué te gustaría practicar?',
        payload: {'tema': tema, 'tipo': 'generico_lectura'},
      );
    }

    final topicData = data[tema];
    if (topicData is Map<String, dynamic>) {
      var levelData = topicData[nivel];
      levelData ??= topicData['1'];
      if (levelData is Map<String, dynamic>) {
        final explicacion = levelData['explicacion'] as String?;
        if (explicacion != null) {
          return ToolResult(
            summary:
                '¡Claro! Vamos a repasar "$cleanName".\n\n$explicacion\n\n'
                '¿Te quedó claro? Puedes pedirme más ejemplos o '
                'ejercicios de práctica.',
            payload: {
              'tema': tema,
              'nivel': nivel,
              'nombre': cleanName,
              'explicacion': explicacion,
            },
          );
        }
      }
    }
  }

  // Fallback when topic data is unavailable.
  return ToolResult(
    summary:
        'Vamos a repasar "$cleanName" juntos. '
        'Aunque no tengo los detalles exactos ahora, puedo ayudarte '
        'con una explicación general. '
        'Cuéntame qué parte específica te interesa.',
    payload: {'tema': tema, 'nivel': nivel, 'nombre': cleanName},
  );
}

/// The registered [ToolSpec] for `explicar_tema`.
const explicarTemaSpec = ToolSpec(
  name: 'explicar_tema',
  description: 'Explica un tema académico con ejemplos y teoría',
  params: [
    ToolParam(
      name: 'tema',
      description: 'Identificador del tema (ej. M001_fracciones)',
      required: true,
    ),
    ToolParam(
      name: 'nivel',
      description: 'Nivel de dificultad (1-3)',
    ),
  ],
  handler: explicarTemaHandler,
);
