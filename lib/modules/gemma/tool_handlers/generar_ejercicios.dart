import '../tool_registry.dart';

/// Handler for the `generar_ejercicios` tool.
///
/// Pulls pre-authored exercises from [ctx.fallbackData] for the given
/// topic and level. Returns a [ToolResult] whose [payload] is a
/// `List<Map<String, dynamic>>` of exercises, each with `enunciado`,
/// `opciones`, and `respuestaCorrecta`.
///
/// Args:
/// - `tema` (String, required): topic ID like "M002_ecuaciones"
/// - `nivel` (String, optional): difficulty level, defaults to "1"
Future<ToolResult> generarEjerciciosHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final tema = args['tema'] as String?;
  final nivel = args['nivel'] as String? ?? '1';

  if (tema == null) {
    return ToolResult(
      summary:
          'Dime qué tema quieres practicar. '
          'Puedo generarte ejercicios de fracciones, ecuaciones, '
          'porcentajes, comprensión lectora, y más.',
      payload: <Map<String, dynamic>>[],
    );
  }

  final data = ctx.fallbackData;
  final cleanName = _stripPrefix(tema);

  if (data != null) {
    // Handle generic subject fallbacks — delegate to explanation to
    // give topic suggestions instead of a confusing exercise prompt.
    if (tema == '_generic_math' || tema == '_generic_reading') {
      // Reuse explicar_tema logic inline for the fallback message.
      final subject = tema == '_generic_math' ? 'matemáticas' : 'comunicación';
      return ToolResult(
        summary:
            'Antes de los ejercicios, ¿qué tema específico de '
            '$subject te gustaría practicar? '
            'Por ejemplo: fracciones, ecuaciones, comprensión lectora...',
        payload: <Map<String, dynamic>>[
          {
            'enunciado':
                'Selecciona un tema de $subject para empezar a practicar.',
            'opciones': <String>['Entendido', 'Necesito más ayuda'],
            'respuestaCorrecta': 'Entendido',
          },
        ],
      );
    }

    final topicData = data[tema];
    if (topicData is Map<String, dynamic>) {
      var levelData = topicData[nivel];
      levelData ??= topicData['1'];
      if (levelData is Map<String, dynamic>) {
        final ejercicios = levelData['ejercicios'];
        if (ejercicios is List && ejercicios.isNotEmpty) {
          final list =
              ejercicios.cast<Map<String, dynamic>>();
          return ToolResult(
            summary:
                '¡Perfecto! Aquí tienes ${list.length} ejercicio(s) '
                'sobre "$cleanName". Cuando tengas tus respuestas, dime '
                'y las revisamos juntos.',
            payload: list,
          );
        }
      }
    }
  }

  // Fallback when no exercises are bundled.
  return ToolResult(
    summary:
        'Vamos a practicar "$cleanName". '
        'Aunque no tengo ejercicios específicos ahora, dime qué aspecto '
        'quieres reforzar y te ayudo con ejemplos.',
    payload: <Map<String, dynamic>>[
      {
        'enunciado':
            'Repasa el concepto principal de "$cleanName" '
            'y explica con tus propias palabras en qué consiste.',
        'opciones': <String>['Entendido', 'Necesito más ayuda'],
        'respuestaCorrecta': 'Entendido',
      },
    ],
  );
}

/// Strips the topic-ID prefix (e.g. "M01_fracciones" → "fracciones").
/// Uses native String methods only — zero RegExp.
String _stripPrefix(String id) {
  final idx = id.indexOf('_');
  return idx >= 0 ? id.substring(idx + 1) : id;
}

/// The registered [ToolSpec] for `generar_ejercicios`.
const generarEjerciciosSpec = ToolSpec(
  name: 'generar_ejercicios',
  description:
      'Genera ejercicios de práctica para un tema con opciones de respuesta',
  params: [
    ToolParam(
      name: 'tema',
      description: 'Identificador del tema (ej. M002_ecuaciones)',
      required: true,
    ),
    ToolParam(
      name: 'nivel',
      description: 'Nivel de dificultad (1-3)',
    ),
  ],
  handler: generarEjerciciosHandler,
);
