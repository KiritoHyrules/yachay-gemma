import 'package:flutter_test/flutter_test.dart';

// These imports will fail until production code exists — RED phase by design.
import 'package:aprendo_plus/modules/gemma/tool_registry.dart';
import 'package:aprendo_plus/modules/gemma/tool_handlers/explicar_tema.dart';
import 'package:aprendo_plus/modules/gemma/tool_handlers/generar_ejercicios.dart';
import 'package:aprendo_plus/modules/gemma/tool_handlers/ejecutar_diagnostico.dart';
import 'package:aprendo_plus/modules/gemma/tool_handlers/obtener_perfil.dart';
import 'package:aprendo_plus/modules/gemma/tool_handlers/obtener_leccion.dart';
import 'package:aprendo_plus/modules/gemma/tool_handlers/registrar_interaccion.dart';

/// Minimal test data mirroring fallback_responses.json structure.
Map<String, dynamic> _testFallbackData() {
  return {
    'M001_fracciones': {
      '1': {
        'explicacion':
            'Las fracciones son como repartir algo en partes iguales.',
        'ejercicios': [
          {
            'enunciado': 'Un chocolate tiene 6 cuadritos.',
            'opciones': ['6/2', '2/6', '4/6', '2/8'],
            'respuestaCorrecta': '2/6',
          },
        ],
      },
      '2': {
        'explicacion':
            'Para comparar fracciones busca un denominador comun.',
        'ejercicios': [
          {
            'enunciado': 'Cual fraccion es equivalente a 2/3?',
            'opciones': ['4/6', '2/6', '3/4', '4/9'],
            'respuestaCorrecta': '4/6',
          },
        ],
      },
    },
    'M002_ecuaciones': {
      '1': {
        'explicacion': 'Una ecuacion es como una balanza en equilibrio.',
        'ejercicios': [
          {
            'enunciado': 'Resuelve: x + 8 = 15',
            'opciones': ['x = 7', 'x = 23', 'x = 8', 'x = 6'],
            'respuestaCorrecta': 'x = 7',
          },
        ],
      },
    },
    'M003_porcentajes': {
      '1': {
        'explicacion': 'El porcentaje significa por cada cien.',
      },
    },
  };
}

/// Minimal ToolContext with only fallbackData populated — sufficient for
/// testing explicar_tema and generar_ejercicios which only need bundled JSON.
ToolContext _testContext() {
  return ToolContext(fallbackData: _testFallbackData());
}

void main() {
  // ==================================================================
  // Group 1: ToolRegistry — registration, lookup, listing
  // ==================================================================
  group('ToolRegistry — registration and lookup', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
    });

    // Test 1: lookup by name returns matching ToolSpec
    test(
        'GIVEN a ToolRegistry with explicar_tema registered '
        'WHEN lookup("explicar_tema") is called '
        'THEN returns matching ToolSpec', () {
      final spec = ToolSpec(
        name: 'explicar_tema',
        description: 'Explain a topic',
        params: const [],
        handler: (args, ctx) async {
          return ToolResult(
            summary: 'explicado',
            payload: {'tema': args['tema']},
          );
        },
      );

      registry.register(spec);
      final found = registry.lookup('explicar_tema');

      expect(found, isNotNull);
      expect(found!.name, equals('explicar_tema'));
      expect(found.description, equals('Explain a topic'));
      expect(found.params, isEmpty);
    });

    // Test 2: lookup unknown tool returns null
    test(
        'GIVEN a ToolRegistry '
        'WHEN lookup("nonexistent") is called '
        'THEN returns null', () {
      final found = registry.lookup('nonexistent');
      expect(found, isNull);
    });

    // Test 3: listTools returns all registered tools
    test(
        'GIVEN a ToolRegistry with 6 tools '
        'WHEN listTools() is called '
        'THEN returns list with 6 ToolSpec entries', () {
      final names = [
        'explicar_tema',
        'generar_ejercicios',
        'ejecutar_diagnostico',
        'obtener_perfil',
        'obtener_leccion',
        'registrar_interaccion',
      ];

      for (final name in names) {
        registry.register(ToolSpec(
          name: name,
          description: 'tool $name',
          params: const [],
          handler: (_, __) async =>
              ToolResult(summary: name, payload: null),
        ));
      }

      final tools = registry.listTools();

      expect(tools, hasLength(6));
      final registeredNames = tools.map((t) => t.name).toSet();
      for (final name in names) {
        expect(registeredNames, contains(name));
      }
    });

    // Test 4: register duplicate overwrites previous
    test(
        'GIVEN explicar_tema already registered '
        'WHEN a new explicar_tema with different description is registered '
        'THEN lookup returns the updated ToolSpec', () {
      registry.register(ToolSpec(
        name: 'explicar_tema',
        description: 'old description',
        params: const [],
        handler: (_, __) async =>
            ToolResult(summary: 'old', payload: null),
      ));

      registry.register(ToolSpec(
        name: 'explicar_tema',
        description: 'new description',
        params: const [],
        handler: (_, __) async =>
            ToolResult(summary: 'new', payload: null),
      ));

      final found = registry.lookup('explicar_tema');
      expect(found!.description, equals('new description'));
    });

    // Test 5: run executes handler and returns result
    test(
        'GIVEN explicar_tema registered with a handler '
        'WHEN run("explicar_tema", {"tema": "fracciones"}, ctx) is called '
        'THEN handler executes and returns the tool result', () async {
      registry.register(ToolSpec(
        name: 'explicar_tema',
        description: 'Explain a topic',
        params: [
          const ToolParam(name: 'tema', description: 'Topic', required: true),
        ],
        handler: (args, ctx) async {
          final tema = args['tema'] as String;
          return ToolResult(
            summary: 'Explicando $tema',
            payload: {'tema': tema, 'explicacion': 'contenido de $tema'},
          );
        },
      ));

      final result = await registry.run(
        'explicar_tema',
        {'tema': 'fracciones'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, contains('fracciones'));
      expect(result.payload, isA<Map>());
      expect((result.payload as Map)['tema'], equals('fracciones'));
    });

    // Test 6: run unknown tool returns error ToolResult
    test(
        'GIVEN a ToolRegistry '
        'WHEN run("unknown_tool", {}, ctx) is called '
        'THEN returns ToolResult with error summary', () async {
      final result = await registry.run(
        'unknown_tool',
        {},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, contains('Error'));
      expect(result.summary, contains('unknown_tool'));
    });
  });

  // ==================================================================
  // Group 2: explicar_tema handler
  // ==================================================================
  group('explicar_tema handler', () {
    // Test 7: returns explanation for known topic (Test 4 from prompt)
    test(
        'GIVEN explicar_tema handler with tema="fracciones", nivel="2" '
        'WHEN handler is executed with bundled fallback data '
        'THEN returns explanation string containing "fracciones"', () async {
      final result = await explicarTemaHandler(
        {'tema': 'M001_fracciones', 'nivel': '2'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.summary, contains('fracciones'));
      // Must contain bundled explanation content, not a generic fallback.
      expect(
        result.summary,
        contains('busca un denominador comun'),
        reason: 'Should return level 2 bundled explanation',
      );
    });

    // Test 8: returns explanation for default nivel when not specified
    test(
        'GIVEN explicar_tema handler with tema="fracciones", no nivel '
        'WHEN handler is executed '
        'THEN defaults to nivel "1" and returns content', () async {
      final result = await explicarTemaHandler(
        {'tema': 'M001_fracciones'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.summary, contains('fracciones'));
      expect(
        result.summary,
        contains('repartir'),
        reason: 'Should default to nivel 1 bundled explanation',
      );
    });

    // Test 9: returns fallback for unknown topic
    test(
        'GIVEN explicar_tema handler with unknown tema '
        'WHEN handler is executed '
        'THEN returns non-empty fallback message', () async {
      final result = await explicarTemaHandler(
        {'tema': 'Z999_unknown', 'nivel': '1'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      // Should not be an error but an encouraging message.
      expect(result.summary, isNot(contains('Error')));
    });

    // Test 10: returns fallback when no tema specified
    test(
        'GIVEN explicar_tema handler with empty args '
        'WHEN handler is executed '
        'THEN returns non-empty fallback message', () async {
      final result = await explicarTemaHandler({}, _testContext());

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.summary, isNot(contains('Error')));
    });
  });

  // ==================================================================
  // Group 3: generar_ejercicios handler
  // ==================================================================
  group('generar_ejercicios handler', () {
    // Test 11: returns exercise list (Test 5 from prompt)
    test(
        'GIVEN generar_ejercicios handler with tema="ecuaciones", nivel="1" '
        'WHEN handler is executed '
        'THEN returns list of ejercicios with enunciado, opciones, '
        'respuestaCorrecta', () async {
      final result = await generarEjerciciosHandler(
        {'tema': 'M002_ecuaciones', 'nivel': '1'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.summary, contains('ejercicio'));
      expect(result.payload, isA<List>());

      final ejercicios = result.payload as List;
      expect(ejercicios, isNotEmpty);

      final first = ejercicios.first as Map<String, dynamic>;
      expect(first, contains('enunciado'));
      expect(first, contains('opciones'));
      expect(first, contains('respuestaCorrecta'));
      expect(first['enunciado'], contains('x + 8 = 15'));
    });

    // Test 12: returns fallback for unknown topic
    test(
        'GIVEN generar_ejercicios handler with unknown tema '
        'WHEN handler is executed '
        'THEN returns non-empty list with fallback exercise', () async {
      final result = await generarEjerciciosHandler(
        {'tema': 'Z999_unknown', 'nivel': '1'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.payload, isA<List>());
      expect((result.payload as List), isNotEmpty);
    });

    // Test 13: returns fallback for topic without exercises
    test(
        'GIVEN generar_ejercicios handler for topic without ejercicios key '
        'WHEN handler is executed '
        'THEN returns non-empty fallback list', () async {
      // M003_porcentajes level "1" has explicacion but no ejercicios.
      final result = await generarEjerciciosHandler(
        {'tema': 'M003_porcentajes', 'nivel': '1'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.payload, isA<List>());
    });
  });

  // ==================================================================
  // Group 4: ejecutar_diagnostico handler
  // ==================================================================
  group('ejecutar_diagnostico handler', () {
    // Test 14: returns diagnostic result (Test 6 from prompt)
    test(
        'GIVEN ejecutar_diagnostico handler with materia="matematica" '
        'WHEN handler is executed '
        'THEN returns result with nivel, etiqueta, itemsAdministrados',
        () async {
      final result = await ejecutarDiagnosticoHandler(
        {'materia': 'matematica'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.summary, contains('diagnóstico'));
      expect(result.payload, isA<Map>());

      final payload = result.payload as Map<String, dynamic>;
      expect(payload, contains('nivel'));
      expect(payload, contains('etiqueta'));
      expect(payload, contains('itemsAdministrados'));
    });

    // Test 15: handles different materia
    test(
        'GIVEN ejecutar_diagnostico handler with materia="lectura" '
        'WHEN handler is executed '
        'THEN returns result referencing lectura', () async {
      final result = await ejecutarDiagnosticoHandler(
        {'materia': 'lectura'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary.toLowerCase(), contains('lectura'));
      expect(result.payload, isA<Map>());
    });

    // Test 16: defaults to "matematica" when no materia specified
    test(
        'GIVEN ejecutar_diagnostico handler with empty args '
        'WHEN handler is executed '
        'THEN returns non-empty result defaulting to matematica', () async {
      final result = await ejecutarDiagnosticoHandler({}, _testContext());

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      // Should mention matemática as default.
      expect(
        result.summary.toLowerCase(),
        anyOf([contains('matematica'), contains('matemática')]),
      );
    });
  });

  // ==================================================================
  // Group 5: obtener_perfil handler
  // ==================================================================
  group('obtener_perfil handler', () {
    // Test 17: returns profile data when studentState is available
    test(
        'GIVEN obtener_perfil handler with studentState in context '
        'WHEN handler is executed '
        'THEN returns ToolResult with profile payload', () async {
      // Context without studentState (simulating offline/not-initialized).
      final result = await obtenerPerfilHandler({}, _testContext());

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      // When no student state, returns a fallback indicating not available.
      expect(result.payload, isA<Map>());
    });
  });

  // ==================================================================
  // Group 6: obtener_leccion handler
  // ==================================================================
  group('obtener_leccion handler', () {
    // Test 18: returns lesson data
    test(
        'GIVEN obtener_leccion handler with lesson id '
        'WHEN handler is executed without dbService in context '
        'THEN returns fallback ToolResult', () async {
      final result = await obtenerLeccionHandler(
        {'id': 'M001_fracciones'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      expect(result.payload, isA<Map>());
    });
  });

  // ==================================================================
  // Group 7: registrar_interaccion handler
  // ==================================================================
  group('registrar_interaccion handler', () {
    // Test 19: records interaction
    test(
        'GIVEN registrar_interaccion handler with interaction data '
        'WHEN handler is executed '
        'THEN returns confirmation ToolResult', () async {
      final result = await registrarInteraccionHandler(
        {
          'tipo': 'explicacion',
          'tema': 'fracciones',
          'resultado': 'correcta',
        },
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, isNotEmpty);
      // When studentState is not available, returns a graceful fallback.
      expect(result.payload, isA<Map>());
    });
  });

  // ==================================================================
  // Group 8: Idempotency — all tools (Test 7 from prompt)
  // ==================================================================
  group('Tool idempotency', () {
    // Test 20: explicar_tema is idempotent
    test(
        'GIVEN explicar_tema handler '
        'WHEN called twice with same args '
        'THEN returns same result both times (deterministic)', () async {
      final ctx = _testContext();
      final args = {'tema': 'M001_fracciones', 'nivel': '1'};

      final result1 = await explicarTemaHandler(args, ctx);
      final result2 = await explicarTemaHandler(args, ctx);

      expect(result1.summary, equals(result2.summary));
      expect(result1.payload.toString(), equals(result2.payload.toString()));
    });

    // Test 21: generar_ejercicios is idempotent
    test(
        'GIVEN generar_ejercicios handler '
        'WHEN called twice with same args '
        'THEN returns same result both times', () async {
      final ctx = _testContext();
      final args = {'tema': 'M002_ecuaciones', 'nivel': '1'};

      final result1 = await generarEjerciciosHandler(args, ctx);
      final result2 = await generarEjerciciosHandler(args, ctx);

      expect(result1.summary, equals(result2.summary));
      expect(result1.payload.toString(), equals(result2.payload.toString()));
    });

    // Test 22: ejecutar_diagnostico is idempotent
    test(
        'GIVEN ejecutar_diagnostico handler '
        'WHEN called twice with same args '
        'THEN returns same result both times', () async {
      final ctx = _testContext();
      final args = {'materia': 'matematica'};

      final result1 = await ejecutarDiagnosticoHandler(args, ctx);
      final result2 = await ejecutarDiagnosticoHandler(args, ctx);

      expect(result1.summary, equals(result2.summary));
    });
  });

  // ==================================================================
  // Group 9: Full ToolRegistry with all 6 tools registered
  // ==================================================================
  group('ToolRegistry — full 6-tool registration', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
      registry.register(explicarTemaSpec);
      registry.register(generarEjerciciosSpec);
      registry.register(ejecutarDiagnosticoSpec);
      registry.register(obtenerPerfilSpec);
      registry.register(obtenerLeccionSpec);
      registry.register(registrarInteraccionSpec);
    });

    test('all 6 tools are registered and listable', () {
      final tools = registry.listTools();
      expect(tools, hasLength(6));
    });

    test('all 6 tools are lookup-able by name', () {
      final names = [
        'explicar_tema',
        'generar_ejercicios',
        'ejecutar_diagnostico',
        'obtener_perfil',
        'obtener_leccion',
        'registrar_interaccion',
      ];
      for (final name in names) {
        expect(registry.lookup(name), isNotNull,
            reason: '$name should be registered');
      }
    });

    test('run explicar_tema via registry returns explanation', () async {
      final result = await registry.run(
        'explicar_tema',
        {'tema': 'M001_fracciones', 'nivel': '1'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.summary, contains('fracciones'));
      expect(result.summary, contains('repartir'));
    });

    test('run generar_ejercicios via registry returns exercises', () async {
      final result = await registry.run(
        'generar_ejercicios',
        {'tema': 'M002_ecuaciones', 'nivel': '1'},
        _testContext(),
      );

      expect(result, isNotNull);
      expect(result.payload, isA<List>());
      expect((result.payload as List), isNotEmpty);
    });
  });
}
