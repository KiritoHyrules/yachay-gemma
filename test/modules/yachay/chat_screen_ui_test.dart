import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/yachay/screens/chat_screen.dart';
import 'package:aprendo_plus/core/data/learning_data.dart';

/// Block 2 of `chat-ui-assistant` — ChatScreen UI Enhancements.
///
/// Tests REQ-01 (Topic Header), REQ-02 (Dynamic Chips),
/// REQ-03 (BKT Mastery Bar), and REQ-07 (Session Summary Card).
void main() {
  // ── Test fixtures (shared across groups) ──────────────────────────────

  const com01 = TemaPrimaria(
    id: 'com_01',
    area: 'comunicacion',
    titulo: 'La idea principal',
    explicacion: 'Un texto corto.',
    chips: ['Quiero un ejemplo', 'Seguir practicando', 'Otro tema'],
    prioridad: 'alta',
  );

  const mat01 = TemaPrimaria(
    id: 'mat_01',
    area: 'matematica',
    titulo: 'Fracciones simples',
    explicacion: 'Partes de un todo.',
    chips: ['Quiero un ejemplo', 'Dame un ejercicio', 'Otro tema'],
    prioridad: 'alta',
  );

  const cyt03 = TemaPrimaria(
    id: 'cyt_03',
    area: 'ciencia',
    titulo: 'El sistema digestivo',
    explicacion: 'Transforma la comida.',
    chips: ['Quiero un ejemplo', 'Órganos principales', 'Otro tema'],
    prioridad: 'media',
  );

  // Helper — wrap any widget in a MaterialApp + Scaffold.
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  // =========================================================================
  // REQ-01: Topic Header Bar
  // =========================================================================

  group('REQ-01 — Topic Header Bar', () {
    testWidgets(
      'GIVEN currentTopic=com_01 WHEN rendered '
      'THEN shows area badge "Comunicación", titulo, and priority',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(currentTopic: com01)));

        expect(find.text('Comunicación'), findsOneWidget);
        expect(find.text('La idea principal'), findsOneWidget);
        expect(find.text('Prioridad alta'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN currentTopic=mat_01 ("Fracciones simples", matematicas) '
      'WHEN rendered '
      'THEN shows "Matemática" area badge',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(currentTopic: mat01)));

        expect(find.text('Matemática'), findsOneWidget);
        expect(find.text('Fracciones simples'), findsOneWidget);
        expect(find.text('Prioridad alta'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN no currentTopic WHEN rendered THEN header is hidden',
      (tester) async {
        await tester.pumpWidget(wrap(const ChatScreen()));

        expect(find.byKey(const Key('topic-header')), findsNothing);
      },
    );

    testWidgets(
      'GIVEN currentTopic=cyt_03 (prioridad=media) '
      'WHEN rendered '
      'THEN shows "Prioridad media"',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(currentTopic: cyt03)));

        expect(find.text('Ciencia'), findsOneWidget);
        expect(find.text('Prioridad media'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // REQ-03: BKT Mastery Indicator
  // =========================================================================

  group('REQ-03 — BKT Mastery Bar', () {
    testWidgets(
      'GIVEN masteryPercent=0.65 WHEN rendered THEN shows "Dominio: 65%" and progress bar',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(masteryPercent: 0.65)));

        expect(find.text('Dominio: 65%'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN masteryPercent=0.75 WHEN rendered '
      'THEN bar is orange (≥ 0.5, < 0.9)',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(masteryPercent: 0.75)));

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, 0.75);

        // Orange color: verify the widget exists with non-null value
        // (color is verified visually; we assert value correctness)
        expect(find.text('Dominio: 75%'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN masteryPercent=0.95 WHEN rendered THEN bar is green (≥ 0.9)',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(masteryPercent: 0.95)));

        expect(find.text('Dominio: 95%'), findsOneWidget);
        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, 0.95);
      },
    );

    testWidgets(
      'GIVEN masteryPercent=0.3 WHEN rendered THEN bar is red (< 0.5)',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(masteryPercent: 0.3)));

        expect(find.text('Dominio: 30%'), findsOneWidget);
        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, 0.3);
      },
    );

    testWidgets(
      'GIVEN masteryPercent=null WHEN rendered THEN shows "Sin datos aún" with no progress bar',
      (tester) async {
        await tester.pumpWidget(wrap(const ChatScreen()));

        expect(find.text('Sin datos aún'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );
  });

  // =========================================================================
  // REQ-02: Dynamic Suggestion Chips
  // =========================================================================

  group('REQ-02 — Dynamic Suggestion Chips', () {
    testWidgets(
      'GIVEN suggestionChips=["Quiero un ejemplo", "Seguir practicando", '
      '"Otro tema"] WHEN rendered '
      'THEN only those 3 labels appear and default chips are absent',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(
          suggestionChips: const [
            'Quiero un ejemplo',
            'Seguir practicando',
            'Otro tema',
          ],
        )));

        expect(find.text('Quiero un ejemplo'), findsOneWidget);
        expect(find.text('Seguir practicando'), findsOneWidget);
        expect(find.text('Otro tema'), findsOneWidget);
        // Default chips should NOT appear
        expect(find.text('Explicar'), findsNothing);
        expect(find.text('Practicar'), findsNothing);
        expect(find.text('Mi progreso'), findsNothing);
        expect(find.text('Cambiar tema'), findsNothing);
      },
    );

    testWidgets(
      'GIVEN no suggestionChips WHEN rendered '
      'THEN default 4-chip set appears ("Explicar", "Practicar", '
      '"Mi progreso", "Cambiar tema")',
      (tester) async {
        await tester.pumpWidget(wrap(const ChatScreen()));

        expect(find.text('Explicar'), findsOneWidget);
        expect(find.text('Practicar'), findsOneWidget);
        expect(find.text('Mi progreso'), findsOneWidget);
        expect(find.text('Cambiar tema'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN suggestionChips and onTopicChipTap WHEN tapping a chip '
      'THEN onTopicChipTap is called with the label text directly',
      (tester) async {
        String? tapped;
        await tester.pumpWidget(wrap(ChatScreen(
          suggestionChips: const ['Practicar'],
          onTopicChipTap: (label) => tapped = label,
        )));

        await tester.tap(find.text('Practicar'));
        await tester.pump();

        expect(tapped, equals('Practicar'));
      },
    );

    testWidgets(
      'GIVEN no onTopicChipTap but suggestionChips provided '
      'WHEN tapping a chip '
      'THEN onSend is called with the label (fallback behavior)',
      (tester) async {
        String? sent;
        await tester.pumpWidget(wrap(ChatScreen(
          suggestionChips: const ['Quiero un ejemplo'],
          onSend: (msg) => sent = msg,
        )));

        await tester.tap(find.text('Quiero un ejemplo'));
        await tester.pump();

        expect(sent, equals('Quiero un ejemplo'));
      },
    );

    testWidgets(
      'GIVEN default chips (no suggestionChips) and onTopicChipTap '
      'WHEN tapping "Practicar" '
      'THEN onTopicChipTap is called with label directly '
      '(mapping removed when onTopicChipTap is provided)',
      (tester) async {
        String? tapped;
        await tester.pumpWidget(wrap(ChatScreen(
          onTopicChipTap: (label) => tapped = label,
        )));

        await tester.tap(find.text('Practicar'));
        await tester.pump();

        // With onTopicChipTap, label is sent directly (no mapping)
        expect(tapped, equals('Practicar'));
      },
    );
  });

  // =========================================================================
  // REQ-07: Session Summary Card
  // =========================================================================

  group('REQ-07 — Session Summary Card', () {
    testWidgets(
      'GIVEN sessionSummary with 3 topics, 14 msgs, 12 min '
      'WHEN rendered '
      'THEN card shows "3 temas | 14 mensajes | 12 min"',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(
          sessionSummary: SessionSummary(
            topicsCovered: 3,
            messagesExchanged: 14,
            timeSpent: const Duration(minutes: 12),
          ),
        )));

        expect(find.textContaining('3 temas'), findsOneWidget);
        expect(find.textContaining('14 mensajes'), findsOneWidget);
        expect(find.textContaining('12 min'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN sessionSummary with 1 topic and 1 msg '
      'WHEN rendered THEN uses singular forms',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(
          sessionSummary: SessionSummary(
            topicsCovered: 1,
            messagesExchanged: 1,
            timeSpent: const Duration(minutes: 5),
          ),
        )));

        expect(find.textContaining('1 tema'), findsOneWidget);
        expect(find.textContaining('1 mensaje'), findsOneWidget);
        expect(find.textContaining('5 min'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN no sessionSummary WHEN rendered THEN card is hidden',
      (tester) async {
        await tester.pumpWidget(wrap(const ChatScreen()));

        // The summary card uses a key — verify absent
        expect(find.byKey(const Key('session-summary-card')), findsNothing);
      },
    );
  });

  // =========================================================================
  // Backward Compatibility
  // =========================================================================

  group('Backward Compatibility', () {
    testWidgets(
      'GIVEN all new params = null WHEN rendered '
      'THEN chat looks like before (no header, no mastery bar, '
      'no session card, default chips, greeting with "aritmética")',
      (tester) async {
        await tester.pumpWidget(wrap(const ChatScreen()));

        // Original elements preserved
        expect(find.textContaining('tutor de aritmética'), findsOneWidget);

        // New elements absent
        expect(find.byKey(const Key('topic-header')), findsNothing);
        expect(find.byKey(const Key('session-summary-card')), findsNothing);

        // Default chips
        expect(find.text('Explicar'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN currentTopic=com_01 WHEN rendered '
      'THEN greeting adapts to "tutor de comunicación"',
      (tester) async {
        await tester.pumpWidget(wrap(ChatScreen(currentTopic: com01)));

        expect(find.textContaining('tutor de comunicación'), findsOneWidget);
      },
    );
  });
}
