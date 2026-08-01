/// Contenido curricular estático para 4to de Primaria (MINEDU Perú).
///
/// Cada [TemaPrimaria] representa un tema del currículo con su explicación
/// y chips de respuesta rápida. Todo el contenido es offline — no requiere
/// base de datos ni conexión a internet.
///
/// Para agregar un tema nuevo, copiá el formato de los ejemplos existentes.
/// Las explicaciones deben tener máximo 90 palabras y usar lenguaje para
/// niños de 9-10 años.
library;

import '../models/topic_mastery.dart';

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

    TemaPrimaria(
      id: 'com_01',
      area: 'comunicacion',
      titulo: 'La idea principal',
      explicacion: 'La idea principal es de qué trata un texto. '
          'Es lo más importante que el autor quiere decir. '
          'Para encontrarla, preguntate: ¿de qué habla todo el texto? '
          'No te fijes en los detalles pequeños, solo en el mensaje más grande.',
      chips: ['Quiero un ejemplo', 'Seguir practicando', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'com_02',
      area: 'comunicacion',
      titulo: 'La inferencia simple',
      explicacion: 'Inferir es leer entre líneas. El texto no lo dice todo, '
          'pero te deja pistas. Si dice "Ana sacó el paraguas", '
          'podés inferir que iba a llover. Usá lo que leés y lo que ya sabés '
          'para descubrir lo que no está escrito.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'com_03',
      area: 'comunicacion',
      titulo: 'El afiche',
      explicacion: 'Un afiche es un aviso grande que llama la atención. '
          'Tiene título o eslogan, imagen, colores llamativos y un mensaje corto. '
          'Sirve para invitar, informar o vender algo. '
          'Cuando lo veas, buscá: ¿qué quiere que hagas o sepas?',
      chips: ['Quiero un ejemplo', 'Partes del afiche', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'com_04',
      area: 'comunicacion',
      titulo: 'El cuento',
      explicacion: 'Un cuento tiene tres partes: inicio, nudo y desenlace. '
          'En el inicio conocés a los personajes y el lugar. '
          'En el nudo aparece el problema o la aventura. '
          'En el desenlace se resuelve todo. '
          'Leé con atención y preguntate qué pasa en cada parte.',
      chips: ['Quiero un ejemplo', 'Practicar estructura', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'com_05',
      area: 'comunicacion',
      titulo: 'La noticia',
      explicacion: 'Una noticia cuenta algo real que pasó. '
          'Responde cuatro preguntas: qué pasó, quiénes participaron, '
          'cuándo y dónde ocurrió. A veces también dice por qué o cómo. '
          'El título resume lo más importante en pocas palabras.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'com_06',
      area: 'comunicacion',
      titulo: 'Sinónimos y antónimos',
      explicacion: 'Los sinónimos son palabras con significado parecido: '
          'feliz y alegre. Los antónimos son palabras con significado opuesto: '
          'grande y pequeño. Conocerlos te ayuda a entender mejor los textos '
          'y a escribir con más variedad.',
      chips: ['Quiero un ejemplo', 'Practicar pares', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'com_07',
      area: 'comunicacion',
      titulo: 'El texto instructivo',
      explicacion: 'Un texto instructivo te dice cómo hacer algo paso a paso. '
          'Puede ser una receta, un manual o las reglas de un juego. '
          'Usa verbos en imperativo: mezcla, corta, enciende. '
          'Seguí el orden de los pasos para lograr el resultado.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'com_08',
      area: 'comunicacion',
      titulo: 'El adjetivo calificativo',
      explicacion: 'El adjetivo calificativo describe al sustantivo. '
          'Dice cómo es alguien o algo: casa grande, niño alegre, cielo azul. '
          'Te ayuda a imaginar mejor lo que leés o escribís. '
          'Preguntate: ¿qué cualidad tiene esta persona o cosa?',
      chips: ['Quiero un ejemplo', 'Seguir practicando', 'Otro tema'],
      prioridad: 'media',
    ),

    // ──────────────────────────────────────────────
    // MATEMÁTICA
    // ──────────────────────────────────────────────

    TemaPrimaria(
      id: 'mat_01',
      area: 'matematica',
      titulo: 'Fracciones simples',
      explicacion: 'Una fracción representa una parte de un todo. '
          'Si partís una pizza en 4 pedazos iguales y tomás 1, '
          'tenés 1/4 (un cuarto) de la pizza. '
          'El número de arriba se llama numerador (cuántas partes tomás) '
          'y el de abajo denominador (en cuántas partes se dividió).',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'mat_02',
      area: 'matematica',
      titulo: 'Multiplicación por una cifra',
      explicacion: 'Multiplicar es sumar el mismo número varias veces. '
          '3 × 4 significa 3 + 3 + 3 + 3, que es 12. '
          'El primer número es lo que repetís y el segundo cuántas veces. '
          'Practicá las tablas del 2 al 9 para resolver más rápido.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'mat_03',
      area: 'matematica',
      titulo: 'Patrones numéricos',
      explicacion: 'Un patrón numérico es una secuencia que sigue una regla. '
          'Por ejemplo: 2, 4, 6, 8… suma de 2 en 2. '
          'O 5, 10, 15, 20… suma de 5 en 5. '
          'Para continuar, descubrí la regla y aplicála al siguiente número.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'mat_04',
      area: 'matematica',
      titulo: 'División simple',
      explicacion: 'Dividir es repartir en partes iguales. '
          'Si tenés 12 galletas y 3 amigos, cada uno recibe 4: 12 ÷ 3 = 4. '
          'El número grande es el total, el otro es en cuántas partes lo repartís. '
          'El resultado es cuánto le toca a cada uno.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'mat_05',
      area: 'matematica',
      titulo: 'Unidades de medida',
      explicacion: 'Medimos con unidades: el metro para longitudes, '
          'el litro para líquidos y el kilogramo para peso. '
          '100 centímetros son 1 metro. 1000 mililitros son 1 litro. '
          '1000 gramos son 1 kilogramo. Elegí la unidad según lo que midas.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'mat_06',
      area: 'matematica',
      titulo: 'Gráficos de barras',
      explicacion:
          'Un gráfico de barras muestra datos con barras de distinta altura. '
          'Cuanto más alta la barra, mayor es el valor. '
          'El eje de abajo suele nombrar categorías y el de al lado los números. '
          'Para leerlo, mirá el título, las etiquetas y compará las alturas.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'alta',
    ),
    TemaPrimaria(
      id: 'mat_07',
      area: 'matematica',
      titulo: 'Área y perímetro',
      explicacion:
          'El perímetro es el contorno de una figura: sumás todos sus lados. '
          'El área es el espacio que cubre por dentro. '
          'En un rectángulo, perímetro = 2 × (largo + ancho) '
          'y área = largo × ancho. Pensá en la cerca (perímetro) '
          'y en el jardín (área).',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'mat_08',
      area: 'matematica',
      titulo: 'Monedas y billetes peruanos',
      explicacion: 'En el Perú usamos soles y céntimos. '
          'Hay monedas de 10, 20 y 50 céntimos, y de 1, 2 y 5 soles. '
          'Los billetes son de 10, 20, 50, 100 y 200 soles. '
          'Para comprar, sumá lo que cuesta y restá del dinero que entregás '
          'para saber el vuelto.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'media',
    ),

    // ──────────────────────────────────────────────
    // CIENCIA Y TECNOLOGÍA
    // ──────────────────────────────────────────────

    TemaPrimaria(
      id: 'cyt_01',
      area: 'ciencia',
      titulo: 'Ecosistemas del Perú',
      explicacion:
          'El Perú tiene tres grandes regiones: costa, sierra y selva. '
          'En la costa hay desiertos y mar. En la sierra, montañas y valles andinos. '
          'En la selva, ríos y mucha vegetación. '
          'Cada lugar tiene plantas, animales y clima propios que forman su ecosistema.',
      chips: ['Quiero un ejemplo', 'Comparar regiones', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'cyt_02',
      area: 'ciencia',
      titulo: 'Animales protegidos del Perú',
      explicacion:
          'Algunos animales del Perú están en peligro y hay que protegerlos. '
          'Ejemplos: el oso de anteojos, la vicuña, el cóndor andino y la tortuga marina. '
          'Están en riesgo por la caza, la tala o la contaminación. '
          'Cuidar su hábitat ayuda a que no desaparezcan.',
      chips: ['Quiero un ejemplo', 'Más animales', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'cyt_03',
      area: 'ciencia',
      titulo: 'El sistema digestivo',
      explicacion: 'El sistema digestivo transforma la comida en nutrientes. '
          'Empieza en la boca, sigue por el esófago hasta el estómago, '
          'y luego al intestino. El hígado y el páncreas ayudan. '
          'Los nutrientes pasan a la sangre y los desechos salen del cuerpo.',
      chips: ['Quiero un ejemplo', 'Órganos principales', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'cyt_04',
      area: 'ciencia',
      titulo: 'La cadena alimenticia',
      explicacion:
          'En una cadena alimenticia, la energía pasa de un ser vivo a otro. '
          'Los productores son las plantas: hacen su alimento con el sol. '
          'Los consumidores comen plantas u otros animales. '
          'Si falta un eslabón, todo el equilibrio del ecosistema se altera.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'cyt_05',
      area: 'ciencia',
      titulo: 'Las plantas',
      explicacion:
          'Las plantas tienen raíz, tallo, hojas, y a veces flores y frutos. '
          'La raíz absorbe agua y sales. El tallo sostiene. '
          'Las hojas hacen fotosíntesis: con luz solar, agua y aire '
          'fabrican su alimento y liberan oxígeno que nosotros respiramos.',
      chips: ['Quiero un ejemplo', 'Fotosíntesis simple', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'cyt_06',
      area: 'ciencia',
      titulo: 'El agua',
      explicacion:
          'El agua puede estar sólida (hielo), líquida o gaseosa (vapor). '
          'En el ciclo del agua se evapora, forma nubes, precipita como lluvia '
          'y vuelve a ríos, lagos o al mar. '
          'Cuidar el agua es importante porque todos los seres vivos la necesitan.',
      chips: ['Quiero un ejemplo', 'Estados del agua', 'Otro tema'],
      prioridad: 'media',
    ),
    TemaPrimaria(
      id: 'cyt_07',
      area: 'ciencia',
      titulo: 'Los huesos y músculos',
      explicacion:
          'Los huesos forman el esqueleto: sostienen el cuerpo y protegen órganos. '
          'Los músculos se contraen y se estiran para que puedas moverte. '
          'Juntos son el sistema locomotor. '
          'Caminar, saltar y escribir es posible gracias a huesos y músculos.',
      chips: ['Quiero un ejemplo', 'Seguir practicando', 'Otro tema'],
      prioridad: 'baja',
    ),
    TemaPrimaria(
      id: 'cyt_08',
      area: 'ciencia',
      titulo: 'Los sentidos',
      explicacion:
          'Tenemos cinco sentidos: vista, oído, tacto, gusto y olfato. '
          'Los ojos ven, los oídos oyen, la piel siente, '
          'la lengua prueba sabores y la nariz detecta olores. '
          'Cada sentido envía información al cerebro para entender el mundo.',
      chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
      prioridad: 'baja',
    ),
  ];

  /// Respuestas por defecto cuando el modelo de IA no responde.
  /// La clave es el ID del tema.
  static const Map<String, String> respuestasDefault = {
    'com_01':
        '¡Hola! La idea principal es el mensaje más importante de un texto. '
            '¿Querés que te dé un ejemplo con un cuento corto?',
    'com_02':
        'Inferir es descubrir lo que el texto no dice directo, usando pistas. '
            '¿Querés practicar con una oración corta?',
    'com_03':
        'Un afiche llama la atención con imagen, colores y un mensaje breve. '
            '¿Querés que veamos las partes de un afiche juntos?',
    'com_04': 'Todo cuento tiene inicio, nudo y desenlace. '
        '¿Te cuento un cuento corto y lo armamos por partes?',
    'com_05': 'La noticia responde qué, quién, cuándo y dónde. '
        '¿Querés armar una noticia con esas cuatro preguntas?',
    'com_06': 'Sinónimos se parecen en significado; antónimos se oponen. '
        '¿Practicamos con algunas palabras?',
    'com_07': 'El texto instructivo te guía paso a paso, como una receta. '
        '¿Querés un ejemplo de instrucciones simples?',
    'com_08': 'El adjetivo calificativo describe cómo es algo o alguien. '
        '¿Buscamos adjetivos en una oración?',
    'mat_01': '¡Claro! Las fracciones son partes de un todo. '
        'Imaginá una pizza partida en 4: cada pedazo es 1/4. '
        '¿Querés practicar con otro ejemplo?',
    'mat_02': 'Multiplicar es sumar el mismo número varias veces. '
        '¿Probamos con una tabla o un problema corto?',
    'mat_03': 'En un patrón hay una regla que se repite. '
        '¿Seguimos juntos una secuencia de números?',
    'mat_04': 'Dividir es repartir en partes iguales. '
        '¿Querés un problema de galletas o de lápices?',
    'mat_05': 'Usamos metro, litro y kilogramo según lo que midamos. '
        '¿Te doy ejemplos de la vida diaria?',
    'mat_06': 'En un gráfico de barras, la altura muestra la cantidad. '
        '¿Leemos un gráfico juntos?',
    'mat_07': 'Perímetro es el contorno; área es lo de adentro. '
        '¿Calculamos el de un rectángulo simple?',
    'mat_08': 'Con soles y céntimos podés sumar precios y sacar el vuelto. '
        '¿Hacemos un problema de compra?',
    'cyt_01': 'Costa, sierra y selva son ecosistemas distintos del Perú. '
        '¿Compararmos sus plantas y animales?',
    'cyt_02':
        'Algunos animales peruanos necesitan protección para no desaparecer. '
            '¿Conocemos al oso de anteojos o al cóndor?',
    'cyt_03': 'El sistema digestivo transforma la comida en energía. '
        '¿Recorremos el camino desde la boca hasta el intestino?',
    'cyt_04':
        'En la cadena alimenticia, las plantas producen y otros seres consumen. '
            '¿Armamos una cadena simple juntos?',
    'cyt_05': 'Las plantas hacen fotosíntesis y nos dan oxígeno. '
        '¿Repasamos raíz, tallo y hojas?',
    'cyt_06': 'El agua cambia de estado y recorre el ciclo del agua. '
        '¿Vemos evaporación, nubes y lluvia?',
    'cyt_07': 'Huesos y músculos trabajan juntos para que te muevas. '
        '¿Querés un ejemplo de un movimiento simple?',
    'cyt_08': 'Los cinco sentidos nos ayudan a conocer el mundo. '
        '¿Repasamos qué órgano usa cada sentido?',
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

  /// Returns the first topic in the curriculum whose mastery is below the
  /// threshold (or not yet attempted), using the per-student BKT data in
  /// [masteryMap]. When all topics are mastered, returns `null`.
  static TemaPrimaria? obtenerPrimerTemaNoDominado(
    Map<String, TopicMastery> masteryMap,
    String studentId,
  ) {
    for (final tema in temas) {
      final key = '$studentId|${tema.id}';
      final mastery = masteryMap[key];
      if (mastery == null || mastery.pLearned < 0.90) {
        return tema;
      }
    }
    return null;
  }

  /// Returns the topic that follows [currentTopicId] in the curriculum
  /// sequence, or `null` when [currentTopicId] is the last topic or not found.
  static TemaPrimaria? encontrarSiguienteTema(String currentTopicId) {
    final idx = temas.indexWhere((t) => t.id == currentTopicId);
    if (idx >= 0 && idx < temas.length - 1) {
      return temas[idx + 1];
    }
    return null;
  }
}
