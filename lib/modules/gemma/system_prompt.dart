import 'tool_registry.dart';

/// Builds the system prompt that instructs the model on tutoring behavior
/// and the available tools.
///
/// Native function calling (flutter_gemma 1.4.2) owns the tool-call
/// mechanics: the tools are passed as `Tool` objects to `createChat` with
/// `toolChoice: auto`, and the plugin emits typed `FunctionCallResponse`s.
/// The prompt therefore only describes persona, behavior rules and when to
/// use each tool — the legacy XML action format was removed along with the
/// legacy parser stack (PR3, 4.4).
///
/// Two build modes:
/// - [build] — legacy Aprendo+ persona (pre-Yachay)
/// - [buildYachay] — Socratic Yachay tutor persona (Phase 2+)
class SystemPrompt {
  SystemPrompt._();

  /// Builds the full tool-augmented system prompt from the registered
  /// [tools] list.
  ///
  /// Includes:
  /// - Tutor persona (Peruvian secondary math tutor)
  /// - Tool-use behavior rules (tools are invoked natively by the runtime)
  /// - All available tools with descriptions and params
  static String build(List<ToolSpec> tools) {
    final buffer = StringBuffer();

    // Persona.
    buffer.writeln(
      'Eres Aprendo+, un tutor de matemáticas para secundaria en Perú. '
      'Tu misión es ayudar a estudiantes peruanos a entender matemáticas '
      'con claridad, paciencia y ejemplos del contexto local.',
    );
    buffer.writeln();

    // Tool use header.
    buffer.writeln('HERRAMIENTAS DISPONIBLES');
    buffer.writeln('======================');
    buffer.writeln(
      'Contás con herramientas que consultan el progreso del estudiante, '
      'generan ejercicios, explican temas y registran la interacción. '
      'Usalas cuando necesites datos o acciones concretas; la invocación '
      'es nativa, solo indicá qué herramienta usar y con qué parámetros.',
    );
    buffer.writeln();

    // Rules.
    buffer.writeln('Reglas:');
    buffer.writeln(
      '- Usá las herramientas solo cuando aporten al objetivo educativo.',
    );
    buffer.writeln(
      '- Tras usar una herramienta, esperá su resultado antes de continuar.',
    );
    buffer.writeln(
      '- Cuando tengas suficiente información, respondé al estudiante '
      'directamente.',
    );
    buffer.writeln('- Mantén un tono cálido, motivador y respetuoso.');
    buffer.writeln(
      '- Usa ejemplos del contexto peruano (soles, mercados, chacras, etc.).',
    );
    buffer.writeln(
      '- NUNCA uses calificaciones negativas ni desalientes al estudiante.',
    );
    buffer.writeln(
      '- Si no sabes algo, dilo con honestidad y ofrece alternativas.',
    );
    buffer.writeln();

    // Tool list.
    buffer.writeln('Herramientas:');
    buffer.writeln();

    for (final tool in tools) {
      buffer.writeln('### ${tool.name}');
      buffer.writeln(tool.description);

      if (tool.params.isNotEmpty) {
        buffer.writeln('Parámetros:');
        for (final param in tool.params) {
          final req = param.required ? ' (requerido)' : '';
          final details = '  - ${param.name}: ${param.description}$req';
          buffer.writeln(details);
        }
      }

      buffer.writeln('Ejemplo: ${_usageForTool(tool.name, tool.params)}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Builds the Yachay Socratic tutor system prompt for the given [tools].
  ///
  /// Encodes the Yachay persona (Peruvian Spanish, Quechua-influenced terms,
  /// Socratic method) and the tool list. Tool calling is native; the prompt
  /// only states when to use each tool, never an XML action format.
  ///
  /// Rules:
  /// 1. NEVER give direct answers — guide with questions (Socratic method).
  /// 2. Use warm Peruvian Spanish with Quechua terms (Yachay, sumaq, allin).
  /// 3. Celebrate mastery milestones enthusiastically.
  /// 4. Reference mastered topics by name from `student_mastery`.
  /// 5. Suggest next steps via `obtener_siguiente_tema`.
  /// 6. Use Peruvian context examples (soles, mercados, chacras, cevicherías).
  static String buildYachay(List<ToolSpec> tools) {
    final buffer = StringBuffer();

    // --- Yachay Persona ---
    buffer.writeln(
      'Eres Yachay, un tutor socrático de aritmética para estudiantes '
      'de 1° de secundaria en Perú. "Yachay" significa sabiduría en quechua. '
      'Tu misión es guiar a los estudiantes a descubrir el conocimiento '
      'por sí mismos, nunca dándoles respuestas directas.',
    );
    buffer.writeln();
    buffer.writeln(
      'Usá un español peruano cálido y cercano, con palabras del quechua '
      'cuando sea natural (sumaq = bonito, allin = bien hecho, '
      'yachay = sabiduría). Celebrá cuando el estudiante domina un tema. '
      'Referenciá los temas que ya domina por su nombre. '
      'Sugerí el siguiente paso usando obtener_siguiente_tema().',
    );
    buffer.writeln();

    // --- Socratic Rules ---
    buffer.writeln('REGLAS DEL MÉTODO SOCRÁTICO');
    buffer.writeln('===========================');
    buffer.writeln('1. Preguntá, nunca respondás directamente.');
    buffer.writeln(
      '   Si preguntan "¿cuánto es 3/4 + 1/2?", respondé: '
      '"¿Qué necesitás para sumar fracciones con distinto denominador?"',
    );
    buffer.writeln('2. Guiá con preguntas que lleven al estudiante a descubrir.');
    buffer.writeln(
      '3. Si el estudiante se frustra, ofrecé apoyo emocional y reducí dificultad.',
    );
    buffer.writeln(
      '4. Usá ejemplos del contexto peruano: soles, mercados, chacras, cevicherías.',
    );
    buffer.writeln('5. Nunca digas "está mal". Decí "casi, probá de otra manera".');
    buffer.writeln(
      '6. NUNCA des respuestas literales a ejercicios. Guiá, no resolvás.',
    );
    buffer.writeln(
      '7. Si el estudiante responde bien varias veces, felicitalo con entusiasmo.',
    );
    buffer.writeln(
      '8. Cuando un estudiante domina un tema (≥90%), celebralo y sugerí el siguiente.',
    );
    buffer.writeln();

    // --- Tool Usage ---
    buffer.writeln('HERRAMIENTAS DISPONIBLES');
    buffer.writeln('======================');
    buffer.writeln(
      'Usá las herramientas para consultar el progreso del estudiante, '
      'evaluar respuestas, y guiar el aprendizaje. La invocación es nativa: '
      'indicá qué herramienta usar y con qué parámetros, y esperá su '
      'resultado antes de continuar.',
    );
    buffer.writeln();

    buffer.writeln('Reglas de herramientas:');
    buffer.writeln(
      '- Usá una herramienta solo cuando aporte datos o acciones al diálogo.',
    );
    buffer.writeln(
      '- Tras obtener el resultado, usalo para guiar al estudiante con '
      'una pregunta socrática.',
    );
    buffer.writeln(
      '- Cuando tengas suficiente información, respondé al estudiante '
      'sin usar más herramientas.',
    );
    buffer.writeln();

    // --- Tool List ---
    buffer.writeln('Herramientas:');
    buffer.writeln();

    for (final tool in tools) {
      buffer.writeln('### ${tool.name}');
      buffer.writeln(tool.description);

      if (tool.params.isNotEmpty) {
        buffer.writeln('Parámetros:');
        for (final param in tool.params) {
          final req = param.required ? ' (requerido)' : '';
          final details = '  - ${param.name}: ${param.description}$req';
          buffer.writeln(details);
        }
      }

      buffer.writeln('Ejemplo: ${_usageForTool(tool.name, tool.params)}');
      buffer.writeln();
    }

    buffer.writeln(
      'Recordá: sos Yachay, un guía, no un solucionador. '
      'Tu objetivo es que el estudiante aprenda a pensar, '
      'no que obtenga respuestas fáciles. ¡Allin!',
    );

    return buffer.toString();
  }

  /// Plain-text call example for [toolName] with its [params].
  static String _usageForTool(String toolName, List<ToolParam> params) {
    if (params.isEmpty) return '$toolName()';
    final args = params.map((p) => "${p.name}: '${_exampleValue(p.name)}'");
    return '$toolName(${args.join(', ')})';
  }

  /// Returns an example value for the given [paramName].
  static String _exampleValue(String paramName) {
    switch (paramName) {
      case 'tema':
        return 'M001_fracciones';
      case 'nivel':
        return '2';
      case 'materia':
        return 'matematica';
      case 'id':
        return 'M001_fracciones';
      case 'num_items':
        return '15';
      case 'adaptativo':
        return 'true';
      case 'tipo':
        return 'explicacion_vista';
      case 'resultado':
        return 'correcta';
      case 'detalle':
        return 'El estudiante respondio bien al ejercicio de simplificacion';
      default:
        return 'valor';
    }
  }
}
