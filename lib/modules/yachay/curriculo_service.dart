import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A single subtopic node in the knowledge graph.
///
/// Each subtopic has an [id], a [titulo], and a list of [prerrequisitos]
/// (IDs of other subtopics that must be mastered first).
class Subtopic {
  final String id;
  final String titulo;
  final List<String> prerrequisitos;
  final String ejemplo;

  const Subtopic({
    required this.id,
    required this.titulo,
    this.prerrequisitos = const [],
    this.ejemplo = '',
  });

  /// Whether this subtopic is unlocked given [masteredIds].
  ///
  /// A subtopic is unlocked when ALL its prerequisites are in [masteredIds].
  bool isUnlocked(Set<String> masteredIds) {
    if (prerrequisitos.isEmpty) return true;
    return prerrequisitos.every((p) => masteredIds.contains(p));
  }

  Map<String, dynamic> toMap(Set<String> masteredIds) {
    final unlocked = isUnlocked(masteredIds);
    final mastered = masteredIds.contains(id);
    return {
      'id': id,
      'titulo': titulo,
      'bloqueado': !unlocked,
      'dominado': mastered,
    };
  }
}

/// A competency (unit) in the curriculum, containing one or more [subtemas].
class Competencia {
  final String id;
  final String titulo;
  final String descripcion;
  final int dificultad;
  final List<Subtopic> subtemas;

  const Competencia({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    this.dificultad = 1,
    this.subtemas = const [],
  });
}

/// The full curriculum graph: a subject with a list of competencies,
/// each containing subtopics with prerequisite edges.
class Curriculum {
  final String materia;
  final int grado;
  final List<Competencia> competencias;

  const Curriculum({
    required this.materia,
    this.grado = 1,
    this.competencias = const [],
  });

  /// Every subtopic ID across all competencies.
  Set<String> get allSubtopicIds {
    final ids = <String>{};
    for (final c in competencias) {
      for (final s in c.subtemas) {
        ids.add(s.id);
      }
    }
    return ids;
  }

  /// The first unlocked, unmastered subtopic, or a completion map if all are
  /// mastered.
  Map<String, dynamic>? obtenerSiguienteTema(Set<String> masteredIds) {
    for (final c in competencias) {
      for (final s in c.subtemas) {
        if (!masteredIds.contains(s.id) && s.isUnlocked(masteredIds)) {
          return {
            'id': s.id,
            'titulo': s.titulo,
            'competencia_id': c.id,
            'competencia_titulo': c.titulo,
            'dificultad': c.dificultad,
            'ejemplo': s.ejemplo,
          };
        }
      }
    }
    // All topics mastered
    return {'completado': true, 'mensaje': '¡Felicitaciones! Has dominado todos los temas de Aritmética.'};
  }

  /// Returns every subtopic annotated with mastery status and lock state.
  List<Map<String, dynamic>> obtenerPlanCompleto(Set<String> masteredIds) {
    final plan = <Map<String, dynamic>>[];
    for (final c in competencias) {
      for (final s in c.subtemas) {
        plan.add({
          'id': s.id,
          'titulo': s.titulo,
          'competencia': c.titulo,
          'grado': grado,
          'dominado': masteredIds.contains(s.id),
          'bloqueado': !s.isUnlocked(masteredIds),
          'dificultad': c.dificultad,
        });
      }
    }
    return plan;
  }
}

/// Loads, parses, and queries the Aritmética curriculum knowledge graph.
class CurriculoService {
  CurriculoService._();

  static const _assetPath = 'assets/curriculum/aritmetica_1.json';

  /// Embedded minimal fallback when the JSON asset is missing or corrupt.
  static const _fallbackJson = '''
{
  "materia": "Aritmética",
  "grado": 1,
  "competencias": [
    {
      "id": "arit_fb_01",
      "titulo": "Números Naturales",
      "descripcion": "Conceptos básicos (fallback)",
      "dificultad": 1,
      "subtemas": [
        {
          "id": "arit_fb_01a",
          "titulo": "Valor Posicional",
          "prerrequisitos": [],
          "ejemplo": "¿Qué valor tiene el 5 en 352?"
        },
        {
          "id": "arit_fb_01b",
          "titulo": "Suma Básica",
          "prerrequisitos": ["arit_fb_01a"],
          "ejemplo": "Calcula 234 + 512"
        }
      ]
    },
    {
      "id": "arit_fb_02",
      "titulo": "Fracciones",
      "descripcion": "Conceptos básicos (fallback)",
      "dificultad": 2,
      "subtemas": [
        {
          "id": "arit_fb_02a",
          "titulo": "Concepto de Fracción",
          "prerrequisitos": ["arit_fb_01b"],
          "ejemplo": "¿Qué fracción representa la parte sombreada?"
        }
      ]
    }
  ]
}
''';

  /// Loads `assets/curriculum/aritmetica_1.json` and parses it into a
  /// [Curriculum]. Falls back to an embedded minimal default on error
  /// so the app remains functional (N-04).
  static Future<Curriculum> cargar() async {
    try {
      final jsonStr = await rootBundle.loadString(_assetPath);
      return parse(jsonStr);
    } catch (e) {
      debugPrint('CurriculoService: no se pudo cargar $_assetPath — '
          'usando currículo mínimo de respaldo. Error: $e');
      return parse(_fallbackJson);
    }
  }

  /// Parses a curriculum JSON string into a [Curriculum].
  ///
  /// On invalid JSON, falls back to [parse] of the embedded fallback.
  static Curriculum parse(String jsonStr) {
    try {
      final root = jsonDecode(jsonStr) as Map<String, dynamic>;
      final competenciasRaw = root['competencias'] as List<dynamic>? ?? [];

      final competencias = <Competencia>[];
      for (final c in competenciasRaw) {
        final cMap = c as Map<String, dynamic>;
        final subtemasRaw = cMap['subtemas'] as List<dynamic>? ?? [];

        final subtemas = <Subtopic>[];
        for (final s in subtemasRaw) {
          final sMap = s as Map<String, dynamic>;
          final prereqs = (sMap['prerrequisitos'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          subtemas.add(Subtopic(
            id: sMap['id'] as String? ?? '',
            titulo: sMap['titulo'] as String? ?? '',
            prerrequisitos: prereqs,
            ejemplo: sMap['ejemplo'] as String? ?? '',
          ));
        }

        competencias.add(Competencia(
          id: cMap['id'] as String? ?? '',
          titulo: cMap['titulo'] as String? ?? '',
          descripcion: cMap['descripcion'] as String? ?? '',
          dificultad: cMap['dificultad'] as int? ?? 1,
          subtemas: subtemas,
        ));
      }

      return Curriculum(
        materia: root['materia'] as String? ?? 'Aritmética',
        grado: root['grado'] as int? ?? 1,
        competencias: competencias,
      );
    } catch (e) {
      debugPrint('CurriculoService: JSON inválido — usando fallback. Error: $e');
      // Re-parse the fallback — this should never fail
      return parse(_fallbackJson);
    }
  }
}
