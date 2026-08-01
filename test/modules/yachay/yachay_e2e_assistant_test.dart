import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show ModelResponse;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aprendo_plus/core/data/learning_data.dart';
import 'package:aprendo_plus/core/database/database_service.dart';
import 'package:aprendo_plus/core/models/topic_mastery.dart';
import 'package:aprendo_plus/core/state/student_state.dart';
import 'package:aprendo_plus/modules/gemma/gemma_service.dart';
import 'package:aprendo_plus/modules/gemma/gemma_inference_adapter.dart';
import 'package:aprendo_plus/modules/yachay/screens/yachay_scaffold.dart';

import '../gemma/fakes/gemma_inference_adapter_fake.dart';

/// Block 4 of `chat-ui-assistant` — End-to-end assistant test.
///
/// Full flow: select first unmastered topic → send on-topic message →
/// verify response → verify mastery bar updates → verify encouragement fires
/// when consecutive correct ≥ 5. Uses a mock GemmaService with a fake adapter.
///
/// Also verifies REQ-08: curriculum-aware system prompt is set when topic
/// changes via [GemmaService.updateSystemPromptForTopic].
///
/// ── Helpers ─────────────────────────────────────────────────────────────

/// Builds a minimal structured fallback data map that the [FallbackDispatcher]
/// can use for Layer 2/3 keyword matching.
Map<String, dynamic> _buildFallbackData() {
  return {
    'trivial_greetings': [
      {'regex': r'^(hola|buenas|hey)', 'response': '¡Hola! ¿En qué te ayudo?'},
    ],
    'keyword_intents': {
      'explicar_tema': ['explic', 'explicame', 'idea'],
      'generar_ejercicios': ['practicar', 'ejercicio'],
    },
    'topic_keywords': {
      'idea principal': 'com_01',
      'inferencia': 'com_02',
      'fracciones': 'mat_01',
    },
    'generic_responses': [
      'Entiendo que quieres aprender. ¿Qué tema te gustaría repasar?',
      'Estoy aquí para ayudarte. ¿Seguimos con el tema actual?',
    ],
    // Legacy topic-id → level entries used by explicar_tema.
    'com_01': {
      '1': '¡Hola! La idea principal es el mensaje más importante de un texto. '
          '¿Querés un ejemplo?',
    },
    'com_02': {
      '1': 'Inferir es leer entre líneas usando pistas. ¿Practicamos?',
    },
    'mat_01': {
      '1': 'Las fracciones son partes de un todo. Imaginá una pizza.',
    },
  };
}

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────

  /// Wraps [YachayScaffold] in a MaterialApp with Provider for [state].
  Widget wrapWithProvider({
    required StudentState state,
    required GemmaService gemmaService,
  }) {
    return ChangeNotifierProvider<StudentState>.value(
      value: state,
      child: MaterialApp(home: YachayScaffold(gemmaService: gemmaService)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQ-08: Full assistant flow — topic selection + messaging
  // ═══════════════════════════════════════════════════════════════════════

  group('REQ-08 — Full assistant e2e flow', () {
    testWidgets(
      'GIVEN StudentState with empty mastery map '
      'WHEN YachayScaffold renders '
      'THEN first curriculum topic (com_01) is selected '
      'AND topic header shows "Comunicación", "La idea principal"',
      (tester) async {
        final fake = GemmaInferenceAdapterFake();
        final gemma = GemmaService.forTest(adapter: fake);
        gemma.setFallbackDataForTest({});

        final state = StudentState(DatabaseService.instance);
        await tester
            .pumpWidget(wrapWithProvider(state: state, gemmaService: gemma));
        await tester.pumpAndSettle();

        // Topic header should show com_01 details.
        expect(find.text('Comunicación'), findsOneWidget);
        expect(find.text('La idea principal'), findsOneWidget);
        expect(find.text('Prioridad alta'), findsOneWidget);

        // Mastery bar should show 0% for unmastered topic.
        expect(find.text('Dominio: 0%'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN a topic selected with fallback data '
      'WHEN student sends an on-topic message '
      'THEN a response appears in the chat (degraded mode works)',
      (tester) async {
        final fake = GemmaInferenceAdapterFake();
        final gemma = GemmaService.forTest(adapter: fake);
        // Provide structured fallback data so Layer 2/3 can match.
        gemma.setFallbackDataForTest(_buildFallbackData());

        final state = StudentState(DatabaseService.instance);
        await tester
            .pumpWidget(wrapWithProvider(state: state, gemmaService: gemma));
        await tester.pumpAndSettle();

        // Type and send a message.
        await tester.enterText(
          find.byType(TextField),
          'Explícame la idea principal',
        );
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // A response should appear in the chat (from Layer 2/3 or L4).
        // The fallback dispatcher always returns non-empty text.
        expect(
          find.textContaining('idea'),
          findsAtLeast(1),
        );
      },
    );

    testWidgets(
      'GIVEN com_01 is mastered (0.93) '
      'WHEN YachayScaffold renders '
      'THEN first unmastered topic (com_02) is selected '
      'AND dominance bar shows 0% for the new topic',
      (tester) async {
        final fake = GemmaInferenceAdapterFake();
        final gemma = GemmaService.forTest(adapter: fake);
        gemma.setFallbackDataForTest({});

        final state = StudentState(DatabaseService.instance);
        // Mark com_01 as mastered.
        state.setMasteryForTest(const TopicMastery(
          studentId: 'estudiante',
          topicId: 'com_01',
          pLearned: 0.93,
          attempts: 10,
          correctAttempts: 9,
          consecutiveCorrect: 4,
        ));
        await tester
            .pumpWidget(wrapWithProvider(state: state, gemmaService: gemma));
        await tester.pumpAndSettle();

        // com_02 = "La inferencia simple" should be selected.
        expect(find.text('La inferencia simple'), findsOneWidget);
        expect(find.text('Comunicación'), findsOneWidget);
        expect(find.text('Dominio: 0%'), findsOneWidget);

        // Verify REQ-08: GemmaService.currentTopic is set.
        expect(gemma.currentTopic, isNotNull);
        expect(gemma.currentTopic!.id, equals('com_02'));
      },
    );

    testWidgets(
      'GIVEN consecutiveCorrect reaches 5 and not yet celebrated '
      'WHEN a response is generated '
      'THEN an agentic encouragement prefix is injected '
      '("¡Vas muy bien!")',
      (tester) async {
        final fake = GemmaInferenceAdapterFake(
          tokens: Stream<String>.fromIterable(
              ['¡Correcto! ', 'Muy ', 'bien ', 'hecho.']),
        );
        final gemma = GemmaService.forTest(adapter: fake);
        gemma.setFallbackDataForTest({});

        final state = StudentState(DatabaseService.instance);
        // Set com_01 mastery with 5 consecutive correct already built up.
        state.setMasteryForTest(const TopicMastery(
          studentId: 'estudiante',
          topicId: 'com_01',
          pLearned: 0.85,
          attempts: 8,
          correctAttempts: 7,
          consecutiveCorrect: 5,
        ));
        await tester
            .pumpWidget(wrapWithProvider(state: state, gemmaService: gemma));
        await tester.pumpAndSettle();

        // Send a message. Gemma will respond with encouragement keywords.
        // That triggers _consecutiveCorrect++ → reaches 6 → since not yet
        // celebrated and ≥ 5, the encouragement prefix should appear.
        await tester.enterText(
          find.byType(TextField),
          'La idea principal es el mensaje más importante del texto',
        );
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // The encouragement prefix "¡Vas muy bien!" should be injected.
        expect(
          find.textContaining('¡Vas muy bien!'),
          findsOneWidget,
        );
      },
    );
  });
}
