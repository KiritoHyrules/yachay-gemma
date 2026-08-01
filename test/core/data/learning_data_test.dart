import 'package:flutter_test/flutter_test.dart';
import 'package:aprendo_plus/core/data/learning_data.dart';

void main() {
  // ===========================================================================
  // Curricula4toPrimaria — static curriculum (C2.3 / static-curriculum)
  // ===========================================================================

  group('Curricula4toPrimaria — carga en memoria', () {
    test(
        'GIVEN the app curriculum is defined statically '
        'WHEN temas is first accessed '
        'THEN at least 24 topics are available without I/O', () {
      const temas = Curricula4toPrimaria.temas;

      expect(temas, isNotEmpty);
      expect(temas.length, greaterThanOrEqualTo(24));
    });

    test(
        'GIVEN the curriculum is loaded '
        'WHEN accessing temas '
        'THEN all 3 areas are present and queryable', () {
      final areas = Curricula4toPrimaria.temas.map((t) => t.area).toSet();

      expect(areas, containsAll(['comunicacion', 'matematica', 'ciencia']));
      expect(areas.length, equals(3));
    });
  });

  group('Curricula4toPrimaria — cobertura por área', () {
    test(
        'GIVEN the curriculum is loaded '
        'WHEN filtering by comunicacion '
        'THEN at least 8 topics are returned', () {
      final com = Curricula4toPrimaria.filtrarPorArea('comunicacion');

      expect(com.length, greaterThanOrEqualTo(8));
      expect(com.every((t) => t.area == 'comunicacion'), isTrue);
    });

    test(
        'GIVEN the curriculum is loaded '
        'WHEN filtering by matematica '
        'THEN at least 8 topics are returned', () {
      final mat = Curricula4toPrimaria.filtrarPorArea('matematica');

      expect(mat.length, greaterThanOrEqualTo(8));
      expect(mat.every((t) => t.area == 'matematica'), isTrue);
    });

    test(
        'GIVEN the curriculum is loaded '
        'WHEN filtering by ciencia '
        'THEN at least 8 topics are returned', () {
      final cyt = Curricula4toPrimaria.filtrarPorArea('ciencia');

      expect(cyt.length, greaterThanOrEqualTo(8));
      expect(cyt.every((t) => t.area == 'ciencia'), isTrue);
    });
  });

  group('Curricula4toPrimaria — IDs únicos y formato', () {
    test(
        'GIVEN all topics '
        'WHEN collecting ids '
        'THEN every id is unique', () {
      final ids = Curricula4toPrimaria.temas.map((t) => t.id).toList();

      expect(ids.toSet().length, equals(ids.length));
    });

    test(
        'GIVEN all topics '
        'WHEN checking id format '
        'THEN each id matches com_|mat_|cyt_ plus two digits', () {
      final idPattern = RegExp(r'^(com|mat|cyt)_\d{2}$');

      for (final tema in Curricula4toPrimaria.temas) {
        expect(
          idPattern.hasMatch(tema.id),
          isTrue,
          reason: 'id inválido: ${tema.id}',
        );
      }
    });
  });

  group('TemaPrimaria — campos y reglas de contenido', () {
    test(
        'GIVEN every topic '
        'WHEN validating required fields '
        'THEN titulo is non-empty and prioridad is alta|media|baja', () {
      const prioridadesValidas = {'alta', 'media', 'baja'};

      for (final tema in Curricula4toPrimaria.temas) {
        expect(tema.titulo.trim(), isNotEmpty, reason: tema.id);
        expect(
          prioridadesValidas.contains(tema.prioridad),
          isTrue,
          reason: '${tema.id} prioridad=${tema.prioridad}',
        );
        expect(
          ['comunicacion', 'matematica', 'ciencia'].contains(tema.area),
          isTrue,
          reason: '${tema.id} area=${tema.area}',
        );
      }
    });

    test(
        'GIVEN every topic explanation '
        'WHEN counting words '
        'THEN each explicacion has at most 90 words', () {
      for (final tema in Curricula4toPrimaria.temas) {
        final words = tema.explicacion
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;

        expect(
          words,
          lessThanOrEqualTo(90),
          reason: '${tema.id} tiene $words palabras',
        );
      }
    });

    test(
        'GIVEN every topic '
        'WHEN validating chips '
        'THEN each topic has 3 or 4 non-empty chip labels', () {
      for (final tema in Curricula4toPrimaria.temas) {
        expect(
          tema.chips.length,
          inInclusiveRange(3, 4),
          reason: '${tema.id} chips=${tema.chips.length}',
        );
        expect(
          tema.chips.every((c) => c.trim().isNotEmpty),
          isTrue,
          reason: '${tema.id} tiene chips vacíos',
        );
      }
    });
  });

  group('Curricula4toPrimaria — buscarPorId', () {
    test(
        'GIVEN curriculum loaded '
        'WHEN buscarPorId(com_01) is called '
        'THEN returns the idea principal topic', () {
      final tema = Curricula4toPrimaria.buscarPorId('com_01');

      expect(tema, isNotNull);
      expect(tema!.id, equals('com_01'));
      expect(tema.area, equals('comunicacion'));
      expect(tema.titulo, equals('La idea principal'));
    });

    test(
        'GIVEN curriculum loaded '
        'WHEN buscarPorId(no_existe) is called '
        'THEN returns null', () {
      expect(Curricula4toPrimaria.buscarPorId('no_existe'), isNull);
    });
  });

  group('Curricula4toPrimaria — filtros', () {
    test(
        'GIVEN curriculum loaded '
        'WHEN filtrarPorPrioridad(alta) is called '
        'THEN returns only high-priority topics and is not empty', () {
      final altas = Curricula4toPrimaria.filtrarPorPrioridad('alta');

      expect(altas, isNotEmpty);
      expect(altas.every((t) => t.prioridad == 'alta'), isTrue);
    });
  });

  group('Curricula4toPrimaria — respuestasDefault', () {
    test(
        'GIVEN all topic ids '
        'WHEN checking respuestasDefault '
        'THEN every topic has a non-empty fallback response', () {
      for (final tema in Curricula4toPrimaria.temas) {
        final respuesta = Curricula4toPrimaria.respuestasDefault[tema.id];

        expect(respuesta, isNotNull, reason: 'falta respuesta para ${tema.id}');
        expect(
          respuesta!.trim(),
          isNotEmpty,
          reason: 'respuesta vacía para ${tema.id}',
        );
      }
    });
  });
}
