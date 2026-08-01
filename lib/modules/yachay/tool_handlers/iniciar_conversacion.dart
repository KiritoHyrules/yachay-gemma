import '../../gemma/tool_registry.dart';

/// Handler for the `iniciar_conversacion` tool.
///
/// Returns a warm greeting introducing Yachay as the student's AI tutor,
/// using Peruvian Spanish with a motivating tone. Designed to be the
/// first message a new student sees.
///
/// Args: none.
Future<ToolResult> iniciarConversacionHandler(
  Map<String, dynamic> args,
  ToolContext ctx,
) async {
  // Try to personalise with the student's name if available.
  String nombre = '';
  final state = ctx.studentState;
  if (state != null && state.profile != null) {
    try {
      nombre = '${state.profile.alias ?? ''}';
    } catch (_) {
      nombre = '';
    }
  }

  String saludo;
  if (nombre.isNotEmpty) {
    saludo =
        '¡Hola, $nombre! Soy Yachay, tu tutor personal de aritmética. '
        'Estoy aquí para ayudarte a aprender a tu ritmo, '
        'sin apuros y sin miedo a equivocarte.\n\n'
        '¿Qué te gustaría hacer hoy? Podemos:\n'
        '• Explicar un tema nuevo\n'
        '• Practicar con ejercicios\n'
        '• Ver tu progreso\n\n'
        'Decime por dónde querés empezar. 😊';
  } else {
    saludo =
        '¡Hola! Soy Yachay, tu tutor personal de aritmética. '
        'Vengo del quechua "yachay" que significa sabiduría y '
        'estoy aquí para acompañarte en tu aprendizaje.\n\n'
        '¿Qué te gustaría hacer hoy? Podemos:\n'
        '• Explicar un tema nuevo\n'
        '• Practicar con ejercicios\n'
        '• Ver tu progreso\n\n'
        'Decime por dónde querés empezar. 😊';
  }

  return ToolResult(
    summary: saludo,
    payload: {
      'inicio': true,
      'tipo': 'saludo_inicial',
      'personalizado': nombre.isNotEmpty,
    },
  );
}

/// The registered [ToolSpec] for `iniciar_conversacion`.
const iniciarConversacionSpec = ToolSpec(
  name: 'iniciar_conversacion',
  description:
      'Inicia una conversación con un saludo cálido en español peruano, '
      'presentándose como Yachay y ofreciendo opciones de aprendizaje.',
  params: [],
  handler: iniciarConversacionHandler,
);
