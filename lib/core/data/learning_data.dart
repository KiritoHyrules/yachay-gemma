/// Contenido curricular estático para 4to de Primaria (MINEDU Perú).
///
/// Cada [TemaPrimaria] representa un tema del currículo con su explicación
/// y chips de respuesta rápida. Todo el contenido es offline — no requiere
/// base de datos ni conexión a internet.
///
/// Para agregar un tema nuevo, copiá el formato de los ejemplos existentes.
/// Las explicaciones deben tener máximo 90 palabras y usar lenguaje para
/// niños de 9-10 años.

/// Un tema individual del currículo de 4to de Primaria.
class TemaPrimaria {
  /// Identificador único (ej. 'com_01', 'mat_02', 'cyt_01').
  final String id;

  /// Área curricular: 'comunicacion', 'matematica', o 'ciencia'.
  final String area;

  /// Título del tema, visible para el estudiante.
  final String titulo;

  /// Explicación del tema en español peruano, máximo 90 palabras,
  /// lenguaje adecuado para 9-10 años.
  final String explicacion;

  /// Opciones de respuesta rápida que el estudiante puede seleccionar
  /// después de leer la explicación. Mínimo 3, máximo 4.
  final List<String> chips;

  /// Prioridad del tema: 'alta' (esencial), 'media' (importante), 'baja' (complementario).
  final String prioridad;

  const TemaPrimaria({
    required this.id,
    required this.area,
    required this.titulo,
    required this.explicacion,
    required this.chips,
    required this.prioridad,
  });
}

/// Contenido curricular completo para 4to de Primaria.
///
/// Contiene la lista plana de todos los temas disponibles y un mapa
/// de respuestas por defecto para cuando el modelo de IA no está disponible.
class Curricula4toPrimaria {
  Curricula4toPrimaria._();

  /// Lista completa de temas del currículo.
  static const List<TemaPrimaria> temas = [
    // ──────────────────────────────────────────────
    // COMUNICACIÓN
    // ──────────────────────────────────────────────

    // EJEMPLO — reemplazar con los temas reales
    TemaPrimaria(
      id: 'com_01',
      area: 'comunicacion',
      titulo: 'La idea principal',
      explicacion:
          'La idea principal es de qué trata un texto. '
          'Es lo más importante que el autor quiere decir. '
          'Para encontrarla, preguntate: ¿de qué habla todo el texto? '
          'No te fijes en los detalles pequeños, solo en el mensaje más grande.',
      chips: ['Quiero un ejemplo', 'Seguir practicando', 'Otro tema'],
      prioridad: 'alta',
    ),

    // AGREGAR MÁS TEMAS DE COMUNICACIÓN AQUÍ
    // - La inferencia simple
    // - El afiche
    // - El cuento
    // - La noticia
    // - Sinónimos y antónimos

    // ──────────────────────────────────────────────
    // MATEMÁTICA
    // ──────────────────────────────────────────────

    // EJEMPLO — reemplazar con los temas reales
    TemaPrimaria(
      id: 'mat_01',
      area: 'matematica',
      titulo: 'Fracciones simples',
      explicacion:
          'Una fracción representa una parte de un todo. '
          'Si partís una pizza en 4 pedazos iguales y tomás 1, '
          'tenés 1/4 (un cuarto) de la pizza. '
          'El número de arriba se llama numerador (cuántas partes tomás) '
          'y el de abajo denominador (en cuántas partes se dividió).',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),

    // AGREGAR MÁS TEMAS DE MATEMÁTICA AQUÍ
    // - Multiplicación por una cifra
    // - Patrones numéricos
    // - División simple
    // - Unidades de medida
    // - Gráficos de barras

    // ──────────────────────────────────────────────
    // CIENCIA Y TECNOLOGÍA
    // ──────────────────────────────────────────────

    // AGREGAR TEMAS DE CIENCIA AQUÍ
    // - Ecosistemas del Perú
    // - Animales protegidos del Perú
    // - El sistema digestivo
    // - La cadena alimenticia
    // - Las plantas
    // - El agua
  ];

  /// Respuestas por defecto cuando el modelo de IA no responde.
  /// La clave es el ID del tema.
  static const Map<String, String> respuestasDefault = {
    'com_01':
        '¡Hola! La idea principal es el mensaje más importante de un texto. '
        '¿Querés que te dé un ejemplo con un cuento corto?',
    'mat_01':
        '¡Claro! Las fracciones son partes de un todo. '
        'Imaginá una pizza partida en 4: cada pedazo es 1/4. '
        '¿Querés practicar con otro ejemplo?',
  };

  /// Busca un tema por su ID.
  static TemaPrimaria? buscarPorId(String id) {
    try {
      return temas.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Filtra temas por área curricular.
  static List<TemaPrimaria> filtrarPorArea(String area) {
    return temas.where((t) => t.area == area).toList();
  }

  /// Filtra temas por prioridad.
  static List<TemaPrimaria> filtrarPorPrioridad(String prioridad) {
    return temas.where((t) => t.prioridad == prioridad).toList();
  }
}
