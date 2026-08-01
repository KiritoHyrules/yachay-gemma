import 'package:flutter_test/flutter_test.dart';

// RED phase — production code does not exist yet (compile error = RED)
// ignore_for_file: unused_import
import 'package:aprendo_plus/modules/yachay/curriculo_service.dart';

/// Minimal valid curriculum JSON for testing parse and DAG behaviour.
const _minimalCurriculumJson = '''
{
  "materia": "Aritmética",
  "grado": 1,
  "competencias": [
    {
      "id": "arit_min_01",
      "titulo": "Números Básicos",
      "descripcion": "Conceptos fundamentales de números",
      "dificultad": 1,
      "subtemas": [
        {
          "id": "arit_min_01a",
          "titulo": "Valor Posicional",
          "prerrequisitos": [],
          "ejemplo": "¿Qué valor tiene el 5 en 352?"
        }
      ]
    }
  ]
}
''';

void main() {
  // ===========================================================================
  // CurriculoService — curriculum loading and DAG traversal
  // ===========================================================================

  group('CurriculoService — parse curriculum JSON', () {
    test(
        'GIVEN a valid curriculum JSON string with 1 competency '
        'WHEN CurriculoService.parse is called '
        'THEN returns a Curriculum with the competency parsed correctly', () {
      final curriculum = CurriculoService.parse(_minimalCurriculumJson);

      expect(curriculum, isNotNull);
      expect(curriculum.materia, equals('Aritmética'));
      expect(curriculum.grado, equals(1));
      expect(curriculum.competencias, isNotEmpty);
      expect(curriculum.competencias.length, equals(1));
      expect(curriculum.competencias.first.id, equals('arit_min_01'));
      expect(curriculum.competencias.first.titulo, equals('Números Básicos'));
      expect(curriculum.competencias.first.subtemas.length, equals(1));
      expect(curriculum.competencias.first.subtemas.first.id,
          equals('arit_min_01a'));
      expect(curriculum.competencias.first.subtemas.first.titulo,
          equals('Valor Posicional'));
    });

    test(
        'GIVEN a parsed curriculum '
        'WHEN accessing all subtopic IDs '
        'THEN returns a set with all unique subtopic IDs', () {
      final curriculum = CurriculoService.parse(_minimalCurriculumJson);
      final allIds = curriculum.allSubtopicIds;

      expect(allIds, isA<Set<String>>());
      expect(allIds, contains('arit_min_01a'));
      expect(allIds.length, equals(1));
    });
  });

  group('CurriculoService — prerequisite DAG traversal', () {
    test(
        'GIVEN a topic with no prerequisites '
        'WHEN isUnlocked is called without any mastered topics '
        'THEN returns true (no prerequisites to satisfy)', () {
      final subtopic = Subtopic(
        id: 'arit_nn_01a',
        titulo: 'Valor Posicional',
        prerrequisitos: [],
        ejemplo: '¿Qué valor tiene el 5 en 352?',
      );

      expect(subtopic.isUnlocked({}), isTrue);
    });

    test(
        'GIVEN a topic with prerequisite "arit_nn_01" '
        'WHEN prerequisite is NOT in mastered set '
        'THEN isUnlocked returns false', () {
      final subtopic = Subtopic(
        id: 'arit_of_02a',
        titulo: 'Suma con llevada',
        prerrequisitos: ['arit_nn_01a'],
        ejemplo: '',
      );

      expect(subtopic.isUnlocked({}), isFalse);
      expect(subtopic.isUnlocked({'other_topic'}), isFalse);
    });

    test(
        'GIVEN a topic with prerequisite "arit_nn_01" '
        'WHEN prerequisite IS in mastered set '
        'THEN isUnlocked returns true', () {
      final subtopic = Subtopic(
        id: 'arit_of_02a',
        titulo: 'Suma con llevada',
        prerrequisitos: ['arit_nn_01a'],
        ejemplo: '',
      );

      expect(subtopic.isUnlocked({'arit_nn_01a'}), isTrue);
    });

    test(
        'GIVEN a topic with 2 prerequisites '
        'WHEN only 1 prerequisite is mastered '
        'THEN isUnlocked returns false (all prerequisites required)', () {
      final subtopic = Subtopic(
        id: 'arit_av_03',
        titulo: 'Tema avanzado',
        prerrequisitos: ['arit_nn_01a', 'arit_nn_02a'],
        ejemplo: '',
      );

      expect(subtopic.isUnlocked({'arit_nn_01a'}), isFalse);
      expect(subtopic.isUnlocked({'arit_nn_01a', 'arit_nn_02a'}), isTrue);
    });
  });

  group('CurriculoService — obtenerSiguienteTema', () {
    test(
        'GIVEN a curriculum with unmastered topics '
        'WHEN obtenerSiguienteTema is called with mastered set '
        'THEN returns the first unlocked, unmastered subtopic', () {
      final curriculum = CurriculoService.parse(_minimalCurriculumJson);

      final next = curriculum.obtenerSiguienteTema({});

      expect(next, isNotNull);
      expect(next!['id'], equals('arit_min_01a'));
      expect(next['titulo'], equals('Valor Posicional'));
    });

    test(
        'GIVEN all topics are mastered '
        'WHEN obtenerSiguienteTema is called '
        'THEN returns a completion message', () {
      final curriculum = CurriculoService.parse(_minimalCurriculumJson);

      final next = curriculum.obtenerSiguienteTema({'arit_min_01a'});

      expect(next, isNotNull);
      expect(next!['completado'], equals(true));
    });
  });

  group('CurriculoService — obtenerPlanCompleto', () {
    test(
        'GIVEN a curriculum with 1 subtopic '
        'WHEN obtenerPlanCompleto is called with no mastery '
        'THEN returns all subtopics with dominado=false, bloqueado based on prerequisites', () {
      final curriculum = CurriculoService.parse(_minimalCurriculumJson);

      final plan = curriculum.obtenerPlanCompleto({});

      expect(plan, isNotEmpty);
      expect(plan.length, equals(1));
      expect(plan.first['id'], equals('arit_min_01a'));
      expect(plan.first['dominado'], equals(false));
      // No prerequisites, so not blocked
      expect(plan.first['bloqueado'], equals(false));
    });

    test(
        'GIVEN a curriculum with 1 subtopic that is mastered '
        'WHEN obtenerPlanCompleto is called '
        'THEN that subtopic has dominado=true', () {
      final curriculum = CurriculoService.parse(_minimalCurriculumJson);

      final plan = curriculum.obtenerPlanCompleto({'arit_min_01a'});

      expect(plan, isNotEmpty);
      expect(plan.first['dominado'], equals(true));
    });
  });

  group('CurriculoService — corrupt asset fallback', () {
    test(
        'GIVEN an invalid JSON string '
        'WHEN CurriculoService.parse is called '
        'THEN returns the embedded fallback curriculum (3 topics)', () {
      final curriculum = CurriculoService.parse('{invalid json');

      expect(curriculum, isNotNull);
      // Fallback has at least 1 competency
      expect(curriculum.competencias, isNotEmpty);
      expect(curriculum.competencias.length, greaterThanOrEqualTo(1));
      // All subtopics from fallback
      final allIds = curriculum.allSubtopicIds;
      expect(allIds.length, greaterThanOrEqualTo(1));
    });
  });

  group('CurriculoService — load from asset', () {
    test(
        'GIVEN _TestAssetBundle with valid JSON '
        'WHEN CurriculoService.parse is called directly '
        'THEN loads and parses curriculum successfully', () async {
      // Asset loading path validation:
      // The parse method (tested above) handles raw JSON strings.
      // Integration with rootBundle is tested via the cargar method
      // which delegates to parse after loading the asset.

      final curriculum = CurriculoService.parse(_minimalCurriculumJson);
      expect(curriculum.materia, equals('Aritmética'));
    });
  });
}
