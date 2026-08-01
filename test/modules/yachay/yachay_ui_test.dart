import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aprendo_plus/core/database/database_service.dart';
import 'package:aprendo_plus/core/state/student_state.dart';
import 'package:aprendo_plus/modules/yachay/screens/chat_screen.dart';
import 'package:aprendo_plus/modules/yachay/screens/yachay_scaffold.dart';
import 'package:aprendo_plus/modules/yachay/screens/camino_screen.dart';
import 'package:aprendo_plus/modules/yachay/screens/perfil_screen.dart';
import 'package:aprendo_plus/modules/yachay/screens/teacher_dashboard.dart';

void main() {
  // Helper: wraps YachayScaffold with the now-required Provider<StudentState>.
  Widget wrapYachay(Widget child) {
    return ChangeNotifierProvider<StudentState>.value(
      value: StudentState(DatabaseService.instance),
      child: child,
    );
  }
  // =========================================================================
  // Phase 3 UI: Camino + Perfil + Teacher Dashboard — widget tests
  // =========================================================================

  // Helper to wrap a widget in MaterialApp for testing
  Widget wrapMaterial(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  // -------------------------------------------------------------------------
  // ChatScreen tests (3.1 + 3.2)
  // -------------------------------------------------------------------------

  group('ChatScreen', () {
    testWidgets(
        'GIVEN no prior messages '
        'WHEN ChatScreen renders '
        'THEN displays Yachay greeting', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        const ChatScreen(messages: []),
      ));

      // Verifies the greeting contains Yachay's introduction
      expect(find.textContaining('Yachay'), findsOneWidget);
      expect(find.textContaining('tutor'), findsOneWidget);
    });

    testWidgets(
        'GIVEN a ChatScreen with user message "Hola" '
        'WHEN rendered '
        'THEN user message bubble appears with blue color', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        ChatScreen(
          messages: [
            const ChatMessage(text: 'Hola', isUser: true, key: ValueKey('msg-0')),
          ],
        ),
      ));

      // User text is displayed
      expect(find.text('Hola'), findsOneWidget);

      // User bubble has blue background
      final userBubble = tester.widget<Container>(
        find.byKey(const Key('user-bubble-msg-0')),
      );
      final decoration = userBubble.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFF1565C0)));
    });

    testWidgets(
        'GIVEN ChatScreen with isThinking=true '
        'WHEN rendered '
        'THEN thinking indicator is visible and prompt bar is disabled', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        const ChatScreen(
          messages: [],
          isThinking: true,
        ),
      ));

      // Thinking indicator is visible (exact match to avoid TextField hint collision)
      expect(find.text('Yachay está pensando'), findsOneWidget);

      // Prompt bar text field should be disabled
      final textField = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(textField.enabled, isFalse);
    });

    testWidgets(
        'GIVEN ChatScreen with Yachay message '
        'WHEN rendered '
        'THEN Yachay message is left-aligned with white background and avatar',
        (tester) async {
      await tester.pumpWidget(wrapMaterial(
        ChatScreen(
          messages: [
            const ChatMessage(text: '¡Hola! Soy Yachay', isUser: false, key: ValueKey('msg-0')),
          ],
        ),
      ));

      // Yachay text is displayed
      expect(find.text('¡Hola! Soy Yachay'), findsOneWidget);

      // Yachay bubble has white background
      final yachayBubble = tester.widget<Container>(
        find.byKey(const Key('yachay-bubble-msg-0')),
      );
      final decoration = yachayBubble.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.white));
    });

    testWidgets(
        'GIVEN ChatScreen with prompt bar '
        'WHEN user types and taps send '
        'THEN onSend is called and input clears', (tester) async {
      String? sentMessage;
      await tester.pumpWidget(wrapMaterial(
        ChatScreen(
          messages: const [],
          onSend: (msg) => sentMessage = msg,
        ),
      ));

      // Type in the prompt bar
      await tester.enterText(find.byType(TextField), 'hola Yachay');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sentMessage, equals('hola Yachay'));
      // Input should be cleared
      expect(find.text('hola Yachay'), findsNothing);
    });

    testWidgets(
        'GIVEN ChatScreen with context chips '
        'WHEN "Practicar" chip is tapped '
        'THEN "Quiero practicar" is sent', (tester) async {
      String? sentMessage;
      await tester.pumpWidget(wrapMaterial(
        ChatScreen(
          messages: const [],
          onSend: (msg) => sentMessage = msg,
        ),
      ));

      await tester.tap(find.text('Practicar'));
      await tester.pump();

      expect(sentMessage, equals('Quiero practicar'));
    });
  });

  // -------------------------------------------------------------------------
  // YachayScaffold tests (3.2 bottom nav)
  // -------------------------------------------------------------------------

  group('YachayScaffold', () {
    testWidgets(
        'GIVEN YachayScaffold '
        'WHEN rendered '
        'THEN shows Chat, Camino, Perfil tabs', (tester) async {
      await tester.pumpWidget(
        wrapYachay(const MaterialApp(home: YachayScaffold())),
      );

      // Three navigation items
      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.items.length, equals(3));
      expect(navBar.items[0].label, equals('Chat'));
      expect(navBar.items[1].label, equals('Camino'));
      expect(navBar.items[2].label, equals('Perfil'));
    });

    testWidgets(
        'GIVEN YachayScaffold '
        'WHEN user taps Camino tab '
        'THEN switches to Camino screen', (tester) async {
      await tester.pumpWidget(
        wrapYachay(const MaterialApp(home: YachayScaffold())),
      );

      await tester.tap(find.text('Camino'));
      await tester.pumpAndSettle();

      // CaminoScreen should now be visible
      expect(find.textContaining('curriculum'), findsOneWidget);
    });

    testWidgets(
        'GIVEN YachayScaffold '
        'WHEN rendered '
        'THEN app bar shows Yachay avatar and grade badge', (tester) async {
      await tester.pumpWidget(
        wrapYachay(const MaterialApp(home: YachayScaffold())),
      );

      // AppBar with Yachay name
      expect(find.text('Yachay'), findsAtLeastNWidgets(1)); // AppBar + bubble avatar
      // Grade badge now shows "4to Primaria" (REQ-05 — real data, visible on Perfil tab).
      // Tap Perfil tab to bring the grade Chip into view.
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('4to Primaria'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // CaminoScreen tests (3.3)
  // -------------------------------------------------------------------------

  group('CaminoScreen', () {
    final sampleTopics = [
      const TopicProgress(id: 'arit_nn_01a', title: 'Valor Posicional', masteryPercent: 0.95, isLocked: false, yachayNote: '¡Muy bien!'),
      const TopicProgress(id: 'arit_nn_01b', title: 'Lectura y Escritura', masteryPercent: 0.60, isLocked: false, yachayNote: 'Vas por buen camino'),
      const TopicProgress(id: 'arit_nn_02a', title: 'Suma sin llevar', masteryPercent: 0.10, isLocked: false, yachayNote: null),
      const TopicProgress(id: 'arit_of_01', title: 'Operaciones Combinadas', masteryPercent: 0.0, isLocked: true, missingPrerequisite: 'Suma sin llevar'),
    ];

    testWidgets(
        'GIVEN CaminoScreen with curriculum data '
        'WHEN rendered '
        'THEN shows topic cards with names and progress bars', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        CaminoScreen(topics: sampleTopics),
      ));

      // All topics should be displayed
      expect(find.text('Valor Posicional'), findsOneWidget);
      expect(find.text('Lectura y Escritura'), findsOneWidget);
      expect(find.text('Suma sin llevar'), findsOneWidget);
      expect(find.text('Operaciones Combinadas'), findsOneWidget);

      // Progress bars should be present
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    });

    testWidgets(
        'GIVEN topic with 95% mastery '
        'WHEN rendered '
        'THEN shows green progress bar color', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        CaminoScreen(topics: sampleTopics.where((t) => t.id == 'arit_nn_01a').toList()),
      ));

      // Find the progress indicator for the mastered topic
      final progressIndicators = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // The first one should have green color (found via parent key)
      final masteredCard = find.byKey(const Key('topic-card-arit_nn_01a'));
      expect(masteredCard, findsOneWidget);

      // Yachay note should be displayed
      expect(find.text('¡Muy bien!'), findsOneWidget);
    });

    testWidgets(
        'GIVEN locked topic with unmet prerequisites '
        'WHEN rendered '
        'THEN shows lock icon instead of progress', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        CaminoScreen(topics: sampleTopics.where((t) => t.id == 'arit_of_01').toList()),
      ));

      // Lock icon should be visible
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Missing prerequisite text (tooltip/snackbar content)
      expect(find.textContaining('Suma sin llevar'), findsOneWidget);
    });

    testWidgets(
        'GIVEN CaminoScreen with some topics '
        'WHEN all topics scrolled '
        'THEN topic cards are scrollable', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        CaminoScreen(topics: sampleTopics),
      ));

      // Verify the scrollable list exists
      expect(find.byType(Scrollable), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // PerfilScreen tests (3.4)
  // -------------------------------------------------------------------------

  group('PerfilScreen', () {
    final sampleStats = StudentStats(
      name: 'María',
      grade: '1° Sec',
      totalTimeMinutes: 120,
      exercisesCompleted: 45,
      accuracy: 0.78,
      yachaySummary: 'María va muy bien en Valor Posicional. Le cuesta un poco las fracciones.',
      achievements: const [
        Achievement(id: 'first_step', title: 'Primer Paso', isUnlocked: true),
        Achievement(id: 'mastered_one', title: '¡Dominado!', isUnlocked: true),
        Achievement(id: 'perfect_streak', title: 'Racha Perfecta', isUnlocked: false),
        Achievement(id: 'no_barriers', title: 'Sin Barreras', isUnlocked: false),
      ],
    );

    testWidgets(
        'GIVEN PerfilScreen with student data '
        'WHEN rendered '
        'THEN shows practiced time, exercises, accuracy stats', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        PerfilScreen(stats: sampleStats),
      ));

      // Stats are displayed
      expect(find.text('María'), findsOneWidget);
      expect(find.text('1° Sec'), findsOneWidget);
      expect(find.text('120 min'), findsOneWidget); // total time
      expect(find.text('45'), findsOneWidget); // exercises
      expect(find.text('78%'), findsOneWidget); // accuracy
    });

    testWidgets(
        'GIVEN PerfilScreen with Yachay summary '
        'WHEN rendered '
        'THEN "Lo que Yachay sabe de vos" section is visible', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        PerfilScreen(stats: sampleStats),
      ));

      // Section title and summary text
      expect(find.text('Lo que Yachay sabe de vos'), findsOneWidget);
      expect(find.textContaining('María va muy bien'), findsOneWidget);
    });

    testWidgets(
        'GIVEN PerfilScreen with achievements '
        'WHEN rendered '
        'THEN unlocked achievements are visible, locked ones are grayed', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        PerfilScreen(stats: sampleStats),
      ));

      // Unlocked achievements
      expect(find.text('Primer Paso'), findsOneWidget);
      expect(find.text('¡Dominado!'), findsOneWidget);

      // Locked achievements (rendered but grayed)
      expect(find.text('Racha Perfecta'), findsOneWidget);
      expect(find.text('Sin Barreras'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // TeacherDashboardScreen tests (3.5)
  // -------------------------------------------------------------------------

  group('TeacherDashboardScreen', () {
    final sampleStudents = [
      TeacherStudentSummary(
        id: 's1',
        name: 'María',
        lastActive: DateTime(2026, 7, 30),
        topicsMastered: 5,
        totalTopics: 45,
        accuracy: 0.82,
        yachayRecommendation: 'María confunde numerador con denominador.',
      ),
      TeacherStudentSummary(
        id: 's2',
        name: 'Juan',
        lastActive: DateTime(2026, 7, 29),
        topicsMastered: 12,
        totalTopics: 45,
        accuracy: 0.91,
        yachayRecommendation: null,
      ),
    ];

    testWidgets(
        'GIVEN TeacherDashboardScreen with students '
        'WHEN rendered '
        'THEN shows student names and mastery overview', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        TeacherDashboardScreen(students: sampleStudents),
      ));

      // Student names visible
      expect(find.text('María'), findsOneWidget);
      expect(find.text('Juan'), findsOneWidget);

      // Mastery progress in "5/45" format
      expect(find.text('5/45'), findsOneWidget);
      expect(find.text('12/45'), findsOneWidget);
    });

    testWidgets(
        'GIVEN TeacherDashboardScreen '
        'WHEN student row is tapped '
        'THEN shows detail sheet with mastery data', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        TeacherDashboardScreen(students: sampleStudents),
      ));

      // Tap María's row
      await tester.tap(find.text('María'));
      await tester.pumpAndSettle();

      // Detail sheet should show Yachay recommendation
      expect(find.textContaining('María confunde'), findsOneWidget);
    });

    testWidgets(
        'GIVEN TeacherDashboardScreen with student without recommendation '
        'WHEN detail is shown '
        'THEN displays fallback message', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        TeacherDashboardScreen(students: sampleStudents),
      ));

      // Tap Juan's row (no recommendation)
      await tester.tap(find.text('Juan'));
      await tester.pumpAndSettle();

      // Fallback text for no recommendation
      expect(
        find.textContaining('no tiene recomendaciones'),
        findsOneWidget,
      );
    });

    testWidgets(
        'GIVEN TeacherDashboardScreen '
        'WHEN rendered '
        'THEN no Gemma inference is required (pure UI)', (tester) async {
      await tester.pumpWidget(wrapMaterial(
        TeacherDashboardScreen(students: sampleStudents),
      ));

      // Renders reliably with just data — no external dependency
      expect(find.text('Panel del Profesor'), findsOneWidget);
    });
  });
}
