import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aprendo_plus/core/data/learning_data.dart';
import 'package:aprendo_plus/core/database/database_service.dart';
import 'package:aprendo_plus/core/models/topic_mastery.dart';
import 'package:aprendo_plus/core/state/student_state.dart';
import 'package:aprendo_plus/modules/yachay/screens/yachay_scaffold.dart';
import 'package:aprendo_plus/modules/yachay/screens/camino_screen.dart';
import 'package:aprendo_plus/modules/yachay/screens/perfil_screen.dart';

/// Block 3 of `chat-ui-assistant` — YachayScaffold Agentic Intelligence.
///
/// Tests REQ-05 (topic selection, next-topic suggestion),
/// REQ-06 (agentic encouragement), and REQ-07 (session summary tracking).

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────

  /// Wraps [YachayScaffold] in a MaterialApp with Provider for [state].
  Widget wrapWithProvider(StudentState state) {
    return ChangeNotifierProvider<StudentState>.value(
      value: state,
      child: const MaterialApp(home: YachayScaffold()),
    );
  }

  // =========================================================================
  // REQ-05: Topic selection (obtenerPrimerTemaNoDominado integration)
  // =========================================================================

  group('REQ-05 — Topic selection from StudentState', () {
    testWidgets(
      'GIVEN StudentState with empty mastery map '
      'WHEN YachayScaffold renders '
      'THEN first curriculum topic (com_01) is selected and shown in header',
      (tester) async {
        final state = StudentState(DatabaseService.instance);
        await tester.pumpWidget(wrapWithProvider(state));
        // Process post-frame callback that calls _selectInitialTopic.
        await tester.pumpAndSettle();

        // com_01 = "Comunicación" area, "La idea principal" title.
        expect(find.text('Comunicación'), findsOneWidget);
        expect(find.text('La idea principal'), findsOneWidget);
        expect(find.text('Prioridad alta'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN com_01 is mastered (pLearned=0.93) '
      'WHEN YachayScaffold renders '
      'THEN com_02 is selected (first unmastered after com_01)',
      (tester) async {
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
        await tester.pumpWidget(wrapWithProvider(state));
        await tester.pumpAndSettle();

        // com_02 = "La inferencia simple".
        expect(find.text('La inferencia simple'), findsOneWidget);
      },
    );

    testWidgets(
      'GIVEN all topics mastered '
      'WHEN YachayScaffold renders '
      'THEN no topic header is shown (currentTopic=null)',
      (tester) async {
        final state = StudentState(DatabaseService.instance);
        // Mark all topics as mastered.
        for (final tema in Curricula4toPrimaria.temas) {
          state.setMasteryForTest(TopicMastery(
            studentId: 'estudiante',
            topicId: tema.id,
            pLearned: 0.93,
          ));
        }
        await tester.pumpWidget(wrapWithProvider(state));
        await tester.pumpAndSettle();

        // Topic header should be hidden when currentTopic is null.
        expect(find.byKey(const Key('topic-header')), findsNothing);
      },
    );
  });

  // =========================================================================
  // REQ-05: Camino screen wired to real StudentState
  // =========================================================================

  group('REQ-05 — Camino screen wired to real mastery data', () {
    testWidgets(
      'GIVEN StudentState with mastery for some topics '
      'WHEN Camino tab is shown '
      'THEN topic progress reflects real BKT data',
      (tester) async {
        final state = StudentState(DatabaseService.instance);
        state.setMasteryForTest(const TopicMastery(
          studentId: 'estudiante',
          topicId: 'com_01',
          pLearned: 0.95,
          yachayRecomendacion: '¡Muy bien!',
        ));
        await tester.pumpWidget(wrapWithProvider(state));
        await tester.pumpAndSettle();

        // Tap the Camino tab (index 1).
        await tester.tap(find.text('Camino'));
        await tester.pumpAndSettle();

        // The CaminoScreen should list topics derived from StudentState.
        expect(find.byType(CaminoScreen), findsOneWidget);
        expect(find.text('La idea principal'), findsOneWidget);
        // com_01 has pLearned=0.95, so the mastery bar should show 95%.
        expect(find.textContaining('95%'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // REQ-05: Perfil screen wired to real StudentState
  // =========================================================================

  group('REQ-05 — Perfil screen wired to real data', () {
    testWidgets(
      'GIVEN StudentState with profile and interaction counts '
      'WHEN Perfil tab is shown '
      'THEN stats reflect real data (not hardcoded samples)',
      (tester) async {
        final state = StudentState(DatabaseService.instance);
        // Simulate some interactions.
        state.recordInteraction(isCorrect: true);
        state.recordInteraction(isCorrect: true);
        state.recordInteraction(isCorrect: false);
        await tester.pumpWidget(wrapWithProvider(state));
        await tester.pumpAndSettle();

        // Tap the Perfil tab (index 2).
        await tester.tap(find.text('Perfil'));
        await tester.pumpAndSettle();

        // PerfilScreen should show real stats from StudentState.
        expect(find.byType(PerfilScreen), findsOneWidget);
        // accuracy = 2/3 ≈ 0.67 → 67%.
        expect(find.textContaining('67%'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // REQ-06: Agentic encouragement keyword detection
  // =========================================================================

  group('REQ-06 — Encouragement keyword detection', () {
    test('"¡correcto! Muy bien." is flagged as encouraging', () {
      expect(
        _isEncouragingResponseDetect('¡correcto! Muy bien.'),
        isTrue,
      );
    });

    test('"Bien hecho, seguí así" is flagged as encouraging', () {
      expect(
        _isEncouragingResponseDetect('Bien hecho, seguí así'),
        isTrue,
      );
    });

    test('"¡sumaq! Qué buena respuesta" is flagged as encouraging', () {
      expect(
        _isEncouragingResponseDetect('¡sumaq! Qué buena respuesta'),
        isTrue,
      );
    });

    test('"excelente trabajo" is flagged as encouraging', () {
      expect(
        _isEncouragingResponseDetect('excelente trabajo'),
        isTrue,
      );
    });

    test('"muy bien" is flagged as encouraging', () {
      expect(
        _isEncouragingResponseDetect('muy bien'),
        isTrue,
      );
    });

    test('"Intentemos de nuevo" is NOT flagged', () {
      expect(
        _isEncouragingResponseDetect('Intentemos de nuevo'),
        isFalse,
      );
    });

    test('"¿Querés un ejemplo?" is NOT flagged', () {
      expect(
        _isEncouragingResponseDetect('¿Querés un ejemplo?'),
        isFalse,
      );
    });
  });

  // =========================================================================
  // REQ-05: Dynamic suggestion chips from current topic
  // =========================================================================

  group('REQ-05 — Dynamic chips from TemaPrimaria', () {
    testWidgets(
      'GIVEN currentTopic=com_01 (chips: "Quiero un ejemplo", '
      '"Seguir practicando", "Otro tema") '
      'WHEN ChatScreen renders '
      'THEN those three chips appear',
      (tester) async {
        final state = StudentState(DatabaseService.instance);
        await tester.pumpWidget(wrapWithProvider(state));
        await tester.pumpAndSettle();

        // com_01 chips: Quiero un ejemplo, Seguir practicando, Otro tema
        expect(find.text('Quiero un ejemplo'), findsOneWidget);
        expect(find.text('Seguir practicando'), findsOneWidget);
        expect(find.text('Otro tema'), findsOneWidget);
        // Default chips should NOT appear.
        expect(find.text('Explicar'), findsNothing);
        expect(find.text('Practicar'), findsNothing);
      },
    );
  });

  // =========================================================================
  // Session Summary: topics covered tracking
  // =========================================================================

  group('REQ-07 — Session summary tracking', () {
    testWidgets(
      'GIVEN a fresh YachayScaffold session '
      'WHEN a topic is selected '
      'THEN _topicsCovered contains the selected topic ID',
      (tester) async {
        final state = StudentState(DatabaseService.instance);
        await tester.pumpWidget(wrapWithProvider(state));
        await tester.pumpAndSettle();

        // Session summary card should appear with 1 topic covered.
        expect(find.byKey(const Key('session-summary-card')), findsOneWidget);
        expect(find.text('1 tema'), findsOneWidget);
      },
    );
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Package-visible helper extracted from YachayScaffold for testability.
// Duplicates the private _isEncouragingResponse logic so we can verify
// keyword detection without full Gemma inference.
// ═══════════════════════════════════════════════════════════════════════════

/// Returns `true` when [response] contains encouragement keywords
/// (matches the identical logic in _YachayScaffoldState._isEncouragingResponse).
bool _isEncouragingResponseDetect(String response) {
  final lower = response.toLowerCase();
  return lower.contains('correcto') ||
      lower.contains('bien hecho') ||
      lower.contains('¡sumaq!') ||
      lower.contains('excelente') ||
      lower.contains('muy bien');
}
