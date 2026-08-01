import '../tool_registry.dart';

/// Handler for the `obtener_leccion` tool.
///
/// Looks up a lesson by its ID via the [LessonRepository] available
/// through [ctx.dbService]. When the database is not initialized
/// (testing / early app lifecycle), returns a graceful fallback.
///
/// Args:
/// - `id` (String, required): the lesson identifier (e.g. "M001_fracciones")
Future<ToolResult> obtenerLeccionHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  final id = args['id'] as String?;

  if (id == null) {
    return ToolResult(
      summary:
          'Necesito el identificador de la lección que quieres consultar. '
          'Por ejemplo: "M001_fracciones" o "L001_comprension".',
      payload: {'estado': 'sin_id'},
    );
  }

  // Try to read from StudentState's LessonRepository.
  if (ctx.studentState != null) {
    try {
      final repo = ctx.studentState.lessonRepo;
      if (repo != null) {
        final lesson = await repo.getById(id);
        if (lesson != null) {
          return ToolResult(
            summary:
                'Lección "${lesson.title}" (${lesson.subject}, '
                'nivel ${lesson.difficultyLevel})',
            payload: {
              'id': lesson.id,
              'subject': lesson.subject,
              'title': lesson.title,
              'difficultyLevel': lesson.difficultyLevel,
            },
          );
        }
      }
    } catch (_) {
      // Fall through to fallback below.
    }
  }

  // Fallback: database not available.
  final cleanName = _stripPrefix(id);
  return ToolResult(
    summary:
        'La lección "$cleanName" está disponible en la sección de '
        'Aprendizaje de la aplicación. Cuando la abras, podré ayudarte '
        'con explicaciones y ejercicios sobre este tema.',
    payload: {
      'id': id,
      'nombre': cleanName,
      'estado': 'fuera_de_linea',
    },
  );
}

/// Strips the topic-ID prefix (e.g. "M01_fracciones" → "fracciones").
/// Uses native String methods only — zero RegExp.
String _stripPrefix(String id) {
  final idx = id.indexOf('_');
  return idx >= 0 ? id.substring(idx + 1) : id;
}

/// The registered [ToolSpec] for `obtener_leccion`.
const obtenerLeccionSpec = ToolSpec(
  name: 'obtener_leccion',
  description:
      'Obtiene la información de una lección (título, materia, nivel) '
      'por su identificador',
  params: [
    ToolParam(
      name: 'id',
      description: 'Identificador de la lección (ej. M001_fracciones)',
      required: true,
    ),
  ],
  handler: obtenerLeccionHandler,
);
