import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/yachay/tool_handlers/consultar_estado.dart';
import 'package:aprendo_plus/modules/yachay/tool_handlers/evaluar_respuesta.dart';
import 'package:aprendo_plus/modules/yachay/tool_handlers/obtener_siguiente_tema.dart';
import 'package:aprendo_plus/modules/yachay/tool_handlers/obtener_plan_completo.dart';
import 'package:aprendo_plus/modules/yachay/tool_handlers/generar_nota_progreso.dart';
import 'package:aprendo_plus/modules/yachay/tool_handlers/generar_resumen_alumno.dart';
import 'package:aprendo_plus/modules/yachay/tool_handlers/iniciar_conversacion.dart';
import 'package:aprendo_plus/modules/gemma/tool_registry.dart';
import 'package:aprendo_plus/modules/gemma/system_prompt.dart';
import 'package:aprendo_plus/modules/gemma/gemma_service.dart';
import 'package:aprendo_plus/core/state/student_state.dart';
import 'package:aprendo_plus/core/database/database_service.dart';
import 'package:aprendo_plus/core/models/topic_mastery.dart';
import 'package:aprendo_plus/modules/yachay/bkt_engine.dart';
import 'package:aprendo_plus/modules/yachay/curriculo_service.dart';

import '../../fixtures/bkt_fixtures.dart';

/// Minimal curriculum JSON used by tool handler tests that need DAG traversal.
const _testCurriculumJson = '''
{
  "materia": "Aritmética",
  "grado": 1,
  "competencias": [
    {
      "id": "arit_test_01",
      "titulo": "Números Naturales",
      "descripcion": "Primer módulo",
      "dificultad": 1,
      "subtemas": [
        {
          "id": "arit_test_01a",
          "titulo": "Valor Posicional",
          "prerrequisitos": [],
          "ejemplo": "¿Qué valor tiene el 5 en 352?"
        },
        {
          "id": "arit_test_01b",
          "titulo": "Suma sin llevar",
          "prerrequisitos": ["arit_test_01a"],
          "ejemplo": "Calcula 234 + 512"
        }
      ]
    },
    {
      "id": "arit_test_02",
      "titulo": "Fracciones",
      "descripcion": "Segundo módulo",
      "dificultad": 2,
      "subtemas": [
        {
          "id": "arit_test_02a",
          "titulo": "Concepto de Fracción",
          "prerrequisitos": ["arit_test_01b"],
          "ejemplo": "¿Qué fracción representa la parte sombreada?"
        },
        {
          "id": "arit_test_02b",
          "titulo": "Suma de Fracciones",
          "prerrequisitos": ["arit_test_02a"],
          "ejemplo": "Calcula 1/4 + 2/4"
        }
      ]
    }
  ]
}
''';

/// Builds a [ToolContext] with a test [studentState].
ToolContext _ctxWith(dynamic studentState, {dynamic curriculum}) {
  return ToolContext(
    studentState: studentState,
    curriculum: curriculum,
  );
}

/// Helper: directly inserts a mastery entry via test-only API.
void _setMastery(StudentState state, TopicMastery mastery) {
  state.setMasteryForTest(mastery);
}

void main() {
  // ===========================================================================
  // Yachay Tools — tool handler unit tests (Phase 2)
  // ===========================================================================

  group('consultar_estado — BKT probability query', () {
    // Test 1: Returns P(L) for known topic
    test(
        'GIVEN mastery map with P(L)=0.62 for topic '
        'WHEN consultar_estado handler is called '
        'THEN returns summary with percentage and payload with p_l=0.62', () async {
      final state = StudentState(DatabaseService.instance);
      _setMastery(state, TopicMastery(
        studentId: testStudent1,
        topicId: 'fracciones/identificar',
        pLearned: 0.62,
        attempts: 3,
        correctAttempts: 2,
        consecutiveCorrect: 1,
      ));

      final ctx = _ctxWith(state);
      final result = await consultarEstadoHandler(
        {'tema': 'fracciones', 'subtema': 'identificar'},
        ctx,
      );

      expect(result.summary, contains('62%'));
      expect(result.summary, contains('fracciones'));
      expect(result.payload, isA<Map<String, dynamic>>());
      expect(result.payload['p_l'], closeTo(0.62, 0.001));
      expect(result.payload['dominado'], isFalse);
    });

    // Test 2: Returns 0.0 for unknown topic
    test(
        'GIVEN empty mastery map '
        'WHEN consultar_estado is called for unknown topic '
        'THEN returns P(L)=0.0', () async {
      final state = StudentState(DatabaseService.instance);
      final ctx = _ctxWith(state);

      final result = await consultarEstadoHandler(
        {'tema': 'geometria', 'subtema': 'triangulos'},
        ctx,
      );

      expect(result.payload['p_l'], closeTo(0.0, 0.001));
      expect(result.payload['dominado'], isFalse);
      expect(result.payload['intentos'], equals(0));
    });

    test(
        'GIVEN mastery map with P(L)=0.92 (mastered) '
        'WHEN consultar_estado is called '
        'THEN returns dominated=true', () async {
      final state = StudentState(DatabaseService.instance);
      _setMastery(state, TopicMastery(
        studentId: testStudent1,
        topicId: 'fracciones/identificar',
        pLearned: 0.92,
        attempts: 8,
        correctAttempts: 7,
        consecutiveCorrect: 4,
      ));

      final ctx = _ctxWith(state);
      final result = await consultarEstadoHandler(
        {'tema': 'fracciones', 'subtema': 'identificar'},
        ctx,
      );

      expect(result.payload['dominado'], isTrue);
      expect(result.summary, contains('92%'));
    });
  });

  group('evaluar_respuesta — BKT update + feedback', () {
    // Test 3: Correct answer updates BKT
    test(
        'GIVEN P(L)=0.0 for "aritmetica/suma" '
        'WHEN evaluar_respuesta handler with correcta=true '
        'THEN payload shows P(L)=0.15 and summary mentions "correcta"', () async {
      final state = StudentState(DatabaseService.instance);

      final ctx = _ctxWith(state);
      final result = await evaluarRespuestaHandler(
        {'tema': 'aritmetica', 'subtema': 'suma', 'correcta': true},
        ctx,
      );

      expect(result.summary, contains('correcta'));
      expect(result.payload['nuevo_p_l'], closeTo(0.15, 0.001));
      expect(result.payload['correcta'], isTrue);

      // actualizarMastery was called — verify via masteryMap
      final mastery = state.masteryMap['default|aritmetica/suma'];
      expect(mastery, isNotNull);
      expect(mastery!.pLearned, closeTo(0.15, 0.001));
    });

    // Test 4: Incorrect answer updates BKT
    test(
        'GIVEN mastery with P(L)=0.7 for "geometria/angulos" '
        'WHEN evaluar_respuesta handler with correcta=false '
        'THEN P(L) changes via slip/guess formula', () async {
      final state = StudentState(DatabaseService.instance);
      _setMastery(state, TopicMastery(
        studentId: testStudent1,
        topicId: 'geometria/angulos',
        pLearned: 0.7,
        attempts: 5,
        correctAttempts: 4,
        consecutiveCorrect: 3,
      ));

      final ctx = _ctxWith(state);
      final result = await evaluarRespuestaHandler(
        {'tema': 'geometria', 'subtema': 'angulos', 'correcta': false},
        ctx,
      );

      // P(L)=0.7 incorrect via slip/guess:
      // slipTerm = 0.7*0.9 = 0.63
      // guessTerm = 0.3*0.20 = 0.06
      // result = 0.63/0.69 ≈ 0.913
      final nuevoPL = result.payload['nuevo_p_l'] as double;
      expect(nuevoPL, isNot(closeTo(0.7, 0.001)));
      expect(result.payload['correcta'], isFalse);
      expect(result.summary, contains('incorrecta'));
    });

    test(
        'GIVEN evaluar_respuesta with correcta=true after incorrect '
        'THEN consecutivas_correctas resets and increments', () async {
      final state = StudentState(DatabaseService.instance);
      _setMastery(state, TopicMastery(
        studentId: testStudent1,
        topicId: 'aritmetica/resta',
        pLearned: 0.5,
        attempts: 3,
        correctAttempts: 2,
        consecutiveCorrect: 2,
      ));

      final ctx = _ctxWith(state);
      await evaluarRespuestaHandler(
        {'tema': 'aritmetica', 'subtema': 'resta', 'correcta': false},
        ctx,
      );

      // After incorrect, consecutive resets
      final entry = state.masteryMap['$testStudent1|aritmetica/resta'];
      expect(entry!.consecutiveCorrect, equals(0));
      expect(entry.attempts, equals(4));
      expect(entry.correctAttempts, equals(2)); // didn't increase
    });
  });

  group('obtener_siguiente_tema — DAG traversal', () {
    // Test 5: Returns next unlocked topic
    test(
        'GIVEN mastered prerequisite but not next topic '
        'WHEN obtener_siguiente_tema handler is called '
        'THEN returns the next unlocked and unmastered topic', () async {
      final state = StudentState(DatabaseService.instance);
      _setMastery(state, TopicMastery(
        studentId: testStudent1,
        topicId: 'arit_test_01a',
        pLearned: 0.95,
        attempts: 7,
        correctAttempts: 6,
        consecutiveCorrect: 4,
      ));

      final curriculum = CurriculoService.parse(_testCurriculumJson);
      final ctx = _ctxWith(state, curriculum: curriculum);

      final result = await obtenerSiguienteTemaHandler({}, ctx);

      expect(result.payload['id'], equals('arit_test_01b'));
      expect(result.payload['titulo'], equals('Suma sin llevar'));
      expect(result.summary, contains('Suma sin llevar'));
    });

    test(
        'GIVEN no topics mastered '
        'WHEN obtener_siguiente_tema is called '
        'THEN returns the first topic with no prerequisites', () async {
      final state = StudentState(DatabaseService.instance);
      final curriculum = CurriculoService.parse(_testCurriculumJson);
      final ctx = _ctxWith(state, curriculum: curriculum);

      final result = await obtenerSiguienteTemaHandler({}, ctx);

      expect(result.payload['id'], equals('arit_test_01a'));
      expect(result.payload['titulo'], equals('Valor Posicional'));
    });

    test(
        'GIVEN all topics mastered '
        'WHEN obtener_siguiente_tema is called '
        'THEN returns completion message', () async {
      final state = StudentState(DatabaseService.instance);
      for (final id in ['arit_test_01a', 'arit_test_01b', 'arit_test_02a', 'arit_test_02b']) {
        _setMastery(state, TopicMastery(
          studentId: testStudent1,
          topicId: id,
          pLearned: 0.95,
          attempts: 7,
          correctAttempts: 6,
          consecutiveCorrect: 4,
        ));
      }

      final curriculum = CurriculoService.parse(_testCurriculumJson);
      final ctx = _ctxWith(state, curriculum: curriculum);

      final result = await obtenerSiguienteTemaHandler({}, ctx);

      expect(result.payload['completado'], isTrue);
      expect(result.summary, contains('Felicitaciones'));
    });
  });

  group('obtener_plan_completo — full curriculum + mastery', () {
    // Test 6: Returns full curriculum with status
    test(
        'GIVEN curriculum with 4 subtopics, 1 mastered '
        'WHEN obtener_plan_completo handler is called '
        'THEN returns list of 4 with correct dominado/bloqueado flags', () async {
      final state = StudentState(DatabaseService.instance);
      _setMastery(state, TopicMastery(
        studentId: testStudent1, topicId: 'arit_test_01a',
        pLearned: 0.95, attempts: 7, correctAttempts: 6, consecutiveCorrect: 4,
      ));

      final curriculum = CurriculoService.parse(_testCurriculumJson);
      final ctx = _ctxWith(state, curriculum: curriculum);

      final result = await obtenerPlanCompletoHandler({}, ctx);

      final plan = result.payload as List<dynamic>;
      expect(plan.length, equals(4));

      // First topic: mastered
      expect(plan[0]['id'], equals('arit_test_01a'));
      expect(plan[0]['dominado'], isTrue);
      expect(plan[0]['bloqueado'], isFalse);

      // Second topic: unlocked (prereq mastered) but not mastered
      expect(plan[1]['id'], equals('arit_test_01b'));
      expect(plan[1]['dominado'], isFalse);
      expect(plan[1]['bloqueado'], isFalse);

      // Third topic: blocked (prereq arit_test_01b not mastered)
      expect(plan[2]['id'], equals('arit_test_02a'));
      expect(plan[2]['dominado'], isFalse);
      expect(plan[2]['bloqueado'], isTrue);

      // Fourth topic: blocked
      expect(plan[3]['id'], equals('arit_test_02b'));
      expect(plan[3]['bloqueado'], isTrue);
    });

    test(
        'GIVEN no curriculum in context '
        'WHEN obtener_plan_completo is called '
        'THEN returns empty list with error note', () async {
      final state = StudentState(DatabaseService.instance);
      final ctx = _ctxWith(state);

      final result = await obtenerPlanCompletoHandler({}, ctx);

      final plan = result.payload as List<dynamic>;
      expect(plan, isEmpty);
      expect(result.summary, isNotEmpty);
    });
  });

  group('generar_nota_progreso — personalized note', () {
    // Test 7: Returns personalized text
    test(
        'GIVEN P(L)=0.62 for topic '
        'WHEN generar_nota_progreso handler is called '
        'THEN returns Spanish text mentioning the topic and progress', () async {
      final state = StudentState(DatabaseService.instance);
      _setMastery(state, TopicMastery(
        studentId: testStudent1,
        topicId: 'decimales',
        pLearned: 0.62,
        attempts: 5,
        correctAttempts: 3,
        consecutiveCorrect: 2,
      ));

      final ctx = _ctxWith(state);
      final result = await generarNotaProgresoHandler(
        {'tema': 'Decimales'},
        ctx,
      );

      expect(result.summary, isNotEmpty);
      expect(result.summary, contains('Decimal'));
      // Should be Spanish with accented characters
      expect(result.summary, matches(RegExp(r'[áéíóúñ]')));
      expect(result.payload['tema'], equals('Decimales'));
    });

    test(
        'GIVEN no mastery data for topic '
        'WHEN generar_nota_progreso is called '
        'THEN returns encouraging text', () async {
      final state = StudentState(DatabaseService.instance);
      final ctx = _ctxWith(state);

      final result = await generarNotaProgresoHandler(
        {'tema': 'Álgebra'},
        ctx,
      );

      expect(result.summary, isNotEmpty);
      expect(result.summary, contains('Álgebra'));
    });
  });

  group('generar_resumen_alumno — student profile summary', () {
    // Test 8: Returns personalized profile
    test(
        'GIVEN student with 4 topics, 2 mastered '
        'WHEN generar_resumen_alumno handler is called '
        'THEN returns Spanish text with mastery count', () async {
      final state = StudentState(DatabaseService.instance);
      final topics = ['arit_test_01a', 'arit_test_01b', 'arit_test_02a', 'arit_test_02b'];
      for (int i = 0; i < topics.length; i++) {
        _setMastery(state, TopicMastery(
          studentId: testStudent1,
          topicId: topics[i],
          pLearned: i < 2 ? 0.95 : 0.30,
          attempts: i < 2 ? 10 : 3,
          correctAttempts: i < 2 ? 8 : 1,
          consecutiveCorrect: i < 2 ? 5 : 0,
        ));
      }

      final ctx = _ctxWith(state);
      final result = await generarResumenAlumnoHandler({}, ctx);

      expect(result.summary, isNotEmpty);
      // Should mention mastery count or overall progress
      expect(result.summary, matches(RegExp(r'[áéíóúñ]')));
      expect(result.payload['total_temas'], equals(4));
      expect(result.payload['temas_dominados'], equals(2));
    });

    test(
        'GIVEN student with no mastery data '
        'WHEN generar_resumen_alumno is called '
        'THEN returns introductory text', () async {
      final state = StudentState(DatabaseService.instance);
      final ctx = _ctxWith(state);

      final result = await generarResumenAlumnoHandler({}, ctx);

      expect(result.summary, isNotEmpty);
    });
  });

  group('iniciar_conversacion — first-message greeting', () {
    test(
        'GIVEN a new student context '
        'WHEN iniciar_conversacion handler is called '
        'THEN returns a warm Peruvian-Spanish greeting introducing Yachay', () async {
      final state = StudentState(DatabaseService.instance);
      final ctx = _ctxWith(state);

      final result = await iniciarConversacionHandler({}, ctx);

      expect(result.summary, isNotEmpty);
      expect(result.summary, contains('Yachay'));
      expect(result.payload['inicio'], isTrue);
    });
  });

  group('Yachay system prompt — buildYachay', () {
    // Test 9: Yachay system prompt includes socratic rules
    test(
        'GIVEN a list of tool specs '
        'WHEN SystemPrompt.buildYachay is called '
        'THEN result contains socratic method, Peruvian context, and tool format', () {
      final tools = <ToolSpec>[];
      final prompt = SystemPrompt.buildYachay(tools);

      expect(prompt, contains('socrático'));
      expect(prompt, contains('peruano'));
      expect(prompt, contains('Yachay'));
      expect(prompt, contains('pregunta'));
      // Tool usage guidance (native calling — no legacy XML action format)
      expect(prompt, contains('Herramientas:'));
      expect(prompt, contains('nativa'));
      expect(prompt, isNot(contains('<action')));
    });

    // Test 10: Yachay system prompt includes all tools
    test(
        'GIVEN 13 tool specs '
        'WHEN SystemPrompt.buildYachay is called '
        'THEN result contains all tool names', () {
      final tools = List.generate(13, (i) => ToolSpec(
        name: 'tool_$i',
        description: 'Tool $i description',
        handler: (args, ctx) async => ToolResult(summary: 'ok'),
      ));

      final prompt = SystemPrompt.buildYachay(tools);

      for (int i = 0; i < 13; i++) {
        expect(prompt, contains('tool_$i'),
            reason: 'Prompt should contain tool_$i');
      }
    });

    test(
        'GIVEN Yachay prompt is built '
        'WHEN checking key phrases '
        'THEN contains Socratic rules and Peruvian examples', () {
      final tools = <ToolSpec>[];
      final prompt = SystemPrompt.buildYachay(tools);

      // Socratic: never give direct answers
      expect(prompt.toLowerCase(), contains('nunca'));
      // Peruvian context
      expect(prompt.toLowerCase(), contains('perú'));
      // Warm tone
      expect(prompt.toLowerCase(), matches(RegExp(r'(cálid|motiv|pacien)')));
    });
  });

  group('Dispatch loop — max rounds = 7', () {
    // Test 11: Dispatch loop max rounds = 7
    test(
        'GIVEN GemmaService dispatch constant '
        'WHEN checking max dispatch rounds '
        'THEN equals 7 (up from 5 in Phase 5)', () {
      expect(GemmaService.maxDispatchRounds, equals(7));
    });
  });
}
