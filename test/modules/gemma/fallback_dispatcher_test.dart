import 'package:flutter_test/flutter_test.dart';

// These imports will fail until production code exists — RED phase by design.
import 'package:aprendo_plus/modules/gemma/fallback_dispatcher.dart';

/// Minimal test data mirroring the extended `fallback_responses.json` structure
/// expected after Phase 2.2.
Map<String, dynamic> _testFallbackData() {
  return {
    // --- Existing topic-level structure (preserved) ---
    'M001_fracciones': {
      '1': {
        'explicacion': 'Las fracciones son como repartir algo en partes iguales.',
        'ejercicios': [
          {
            'enunciado': 'Un chocolate tiene 6 cuadritos.',
            'opciones': ['6/2', '2/6', '4/6', '2/8'],
            'respuestaCorrecta': '2/6',
          },
        ],
      },
    },
    'M002_ecuaciones': {
      '1': {
        'explicacion': 'Una ecuacion es como una balanza en equilibrio.',
      },
    },
    'M003_porcentajes': {
      '1': {
        'explicacion': 'El porcentaje significa por cada cien.',
      },
    },

    // --- NEW: trivial greetings (Layer 1) ---
    'trivial_greetings': [
      {
        'regex': r'^(hola|holaa|holaaa|holi|hey|buenos días|buenas tardes|buenas noches|gracias|muchas gracias)[!.\s]*$',
        'response':
            '¡Hola! Soy Yachay, tu tutor de aritmética. ¿Qué querés aprender hoy?',
      },
    ],

    // --- NEW: topic keyword → topic_id mapping (Layer 2/3) ---
    'topic_keywords': {
      'fracciones': 'M001_fracciones',
      'ecuaciones': 'M002_ecuaciones',
      'porcentajes': 'M003_porcentajes',
    },

    // --- NEW: keyword → tool mapping (Layer 2) ---
    'keyword_intents': {
      'explicar_tema': [
        'explica',
        'ayudame con',
        'no entiendo',
        'que es',
        'enseñame',
        'dime que',
      ],
      'generar_ejercicios': [
        'practicar',
        'ejercicios',
        'practica',
        'problemas',
        'ponme',
      ],
      'ejecutar_diagnostico': [
        'diagnostico',
        'evaluame',
        'prueba',
        'examen',
        'que tanto se',
        'hazme un',
      ],
    },

    // --- NEW: generic responses (Layer 4) ---
    'generic_responses': [
      'Entiendo que quieres aprender. Podemos empezar con fracciones, ecuaciones o comprensión lectora. ¿Cuál prefieres?',
      'No te preocupes, estoy aquí para ayudarte. Dime qué tema quieres repasar: matemática o comunicación.',
      '¡Qué bien que quieras estudiar! Cuéntame, ¿qué materia te gustaría practicar hoy?',
    ],
  };
}

void main() {
  group('FallbackDispatcher — 4-layer system', () {
    late FallbackDispatcher dispatcher;

    setUp(() {
      dispatcher = FallbackDispatcher(fallbackData: _testFallbackData());
    });

    // ================================================================
    // Test 1: Layer 1 — trivial greeting gate ("hola")
    // ================================================================
    test('Layer 1: "hola" returns greeting response without model', () async {
      final result = await dispatcher.dispatch('hola');

      expect(result, isNotEmpty);
      expect(result, contains('Yachay'));
      // Layer 1 must NOT be a generic L4 response — it's the specific greeting.
      expect(result, isNot(contains('Podemos empezar con')));
      expect(result, isNot(contains('No te preocupes')));
    });

    // ================================================================
    // Test 2: Layer 1 — greeting variants
    // ================================================================
    test('Layer 1: greeting variants all return greeting-level responses',
        () async {
      final variants = ['buenos días', 'buenas tardes', 'gracias'];

      for (final msg in variants) {
        final result = await dispatcher.dispatch(msg);
        expect(result, isNotEmpty, reason: 'Empty response for "$msg"');
        expect(result, contains('Yachay'), reason: '"$msg" did not match L1');
        // Ensure L4 was NOT reached.
        expect(
          result,
          isNot(contains('Podemos empezar con')),
          reason: '"$msg" incorrectly reached L4',
        );
      }
    });

    // ================================================================
    // Test 3: Layer 2 — keyword routing to explicar_tema (math)
    // ================================================================
    test('Layer 2: "ayudame con fracciones" routes to explicar_tema', () async {
      final result = await dispatcher.dispatch('ayudame con fracciones');

      expect(result, isNotEmpty);
      // L3 should return the bundled explanation from the test data.
      expect(
        result,
        contains('Las fracciones son como repartir'),
        reason: 'Should return bundled explanation for fracciones',
      );
    });

    // ================================================================
    // Test 4: Layer 2 — keyword routing to generar_ejercicios
    // ================================================================
    test('Layer 2: "quiero practicar ecuaciones" routes to generar_ejercicios',
        () async {
      final result =
          await dispatcher.dispatch('quiero practicar ecuaciones');

      expect(result, isNotEmpty);
      // Exercises routing returns exercise content (L3 lookup).
      // The bundled data for M002_ecuaciones has explicacion; generating
      // exercises from fallback data should include exercise-related content.
      expect(
        result,
        isNotEmpty,
      );
      // It should NOT be a generic L4 response.
      expect(result, isNot(contains('Podemos empezar con')));
    });

    // ================================================================
    // Test 5: Layer 2 — keyword routing to ejecutar_diagnostico
    // ================================================================
    test('Layer 2: "hazme un diagnostico" routes to ejecutar_diagnostico',
        () async {
      final result = await dispatcher.dispatch('hazme un diagnostico');

      expect(result, isNotEmpty);
      // Diagnostic tool response — should reference evaluation/assessment.
      expect(
        result,
        anyOf([
          contains('diagnóstico'),
          contains('diagnostico'),
          contains('evaluación'),
          contains('evaluacion'),
          contains('nivel'),
        ]),
      );
    });

    // ================================================================
    // Test 6: Layer 3 — deterministic tool fallback (bundled JSON)
    // ================================================================
    test('Layer 3: "porcentajes" returns bundled explanation from JSON',
        () async {
      // "porcentajes" is a topic keyword — L2 matches → explicar_tema,
      // L3 returns bundled content.
      final result = await dispatcher.dispatch('porcentajes');

      expect(result, isNotEmpty);
      // Must return the pre-authored explanation from fallback JSON.
      expect(
        result,
        contains('por cada cien'),
        reason: 'L3 should return bundled content for porcentajes',
      );
    });

    // ================================================================
    // Test 7: Layer 4 — generic fallback
    // ================================================================
    test('Layer 4: "dime algo interesante" returns generic encouragement',
        () async {
      final result =
          await dispatcher.dispatch('dime algo interesante');

      expect(result, isNotEmpty);
      // Must be one of the generic Peruvian Spanish encouragements.
      final generics = _testFallbackData()['generic_responses'] as List;
      expect(
        generics.contains(result),
        isTrue,
        reason: 'Response must be one of the generic_responses strings',
      );
    });

    // ================================================================
    // Test 8: No double-dispatch — L2 routes → L3 does NOT re-route
    // ================================================================
    test('No double-dispatch: keyword match on explicar_tema stops at L2/L3',
        () async {
      // A message that triggers explicar_tema via L2 keyword "ayudame con"
      // AND contains a topic keyword "fracciones".
      final result = await dispatcher.dispatch('ayudame con fracciones');

      // The response MUST be the bundled L3 explanation for fracciones,
      // NOT a generic L4 encouragement.
      expect(result, contains('Las fracciones son como repartir'));
      expect(result, isNot(contains('Podemos empezar con')));
      expect(result, isNot(contains('No te preocupes')));
    });
  });

  group('FallbackDispatcher — edge cases', () {
    late FallbackDispatcher dispatcher;

    setUp(() {
      dispatcher = FallbackDispatcher(fallbackData: _testFallbackData());
    });

    test('empty message returns generic L4 response', () async {
      final result = await dispatcher.dispatch('');
      expect(result, isNotEmpty);
    });

    test('whitespace-only message returns generic L4 response', () async {
      final result = await dispatcher.dispatch('   ');
      expect(result, isNotEmpty);
    });

    test('unknown topic keyword defaults to explicar_tema with generic',
        () async {
      // A topic not in topic_keywords but with a tool intent keyword.
      final result =
          await dispatcher.dispatch('explica geometria');
      // Should attempt explicar_tema but with unknown topic → generic within L3.
      expect(result, isNotEmpty);
      // Should NOT fall through to L4.
      expect(result, isNot(contains('Podemos empezar con')));
    });
  });
}
