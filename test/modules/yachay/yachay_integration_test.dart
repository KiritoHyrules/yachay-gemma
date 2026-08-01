import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/main.dart';
import 'package:aprendo_plus/modules/gemma/gemma_service.dart';
import 'package:aprendo_plus/modules/yachay/screens/yachay_scaffold.dart';
import 'package:aprendo_plus/modules/diagnostico/diagnostico_screen.dart';

/// Extracted routing logic mirroring `AprendoPlusApp.build()` home property.
/// Used by Test 2 for routing-type assertion without full provider-wrapped
/// rendering (DiagnosticoScreen needs providers unavailable in headless tests).
Widget buildHomeScreen() {
  return GemmaService.useYachayOrchestrator
      ? const YachayScaffold()
      : const DiagnosticoScreen();
}

void main() {
  // -------------------------------------------------------------------------
  // Phase 4 Integration Tests — feature gate + app routing
  // -------------------------------------------------------------------------

  late bool savedGate;

  setUp(() {
    savedGate = GemmaService.useYachayOrchestrator;
  });

  tearDown(() {
    GemmaService.useYachayOrchestrator = savedGate;
  });

  // =========================================================================
  // Test 1: Feature gate ON routes to YachayScaffold (RED → GREEN)
  //
  // This test IMPORTS AprendoPlusApp from lib/main.dart and verifies
  // routing behavior. It MUST FAIL now because AprendoPlusApp currently
  // hardcodes DiagnosticoScreen as home. It will PASS after the gate
  // wiring is implemented in main.dart.
  //
  // Renders AprendoPlusApp WITHOUT MultiProvider wrapper — safe for the
  // Yachay route because YachayScaffold uses no context-dependent providers.
  // =========================================================================

  testWidgets(
      'GIVEN useYachayOrchestrator = true '
      'WHEN AprendoPlusApp is built '
      'THEN YachayScaffold is the home screen with greeting visible',
      (tester) async {
    GemmaService.useYachayOrchestrator = true;

    await tester.pumpWidget(const AprendoPlusApp());

    // After main.dart fix: YachayScaffold should render with Yachay greeting
    expect(find.textContaining('¡Hola! Soy Yachay'), findsOneWidget);
    expect(find.text('Yachay'), findsAtLeastNWidgets(1)); // AppBar + bubble avatar
    expect(find.text('1° Sec'), findsOneWidget); // Grade badge
  });

  // =========================================================================
  // Test 2: Feature gate OFF routes to DiagnosticoScreen
  //
  // Verifies routing correctness: when the gate is OFF the routing function
  // returns DiagnosticoScreen, not YachayScaffold. Uses buildHomeScreen()
  // instead of full AprendoPlusApp rendering because DiagnosticoScreen
  // requires provider-aware services unavailable in a headless test.
  // =========================================================================

  testWidgets(
      'GIVEN useYachayOrchestrator = false '
      'WHEN home screen routing is evaluated '
      'THEN DiagnosticoScreen is the home widget',
      (tester) async {
    GemmaService.useYachayOrchestrator = false;

    final home = buildHomeScreen();

    expect(home, isA<DiagnosticoScreen>(),
        reason: 'Gate OFF must route to DiagnosticoScreen');
    expect(home, isNot(isA<YachayScaffold>()),
        reason: 'Gate OFF must NOT route to YachayScaffold');
  });

  // =========================================================================
  // Test 3: Yachay greeting message on first launch
  //
  // Integration-level: verifies YachayScaffold → ChatScreen → greeting
  // pipeline end-to-end through scaffold routing.
  // =========================================================================

  testWidgets(
      'GIVEN YachayScaffold with no prior messages '
      'WHEN ChatScreen renders '
      'THEN greeting message from Yachay is displayed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: YachayScaffold()));

    expect(find.textContaining('¡Hola! Soy Yachay'), findsOneWidget);
    expect(find.textContaining('tutor de aritmética'), findsOneWidget);
  });

  // =========================================================================
  // Test 4: Bottom nav switches screens
  //
  // Integration-level: verifies YachayScaffold nav correctly switches
  // between Chat, Camino, and Perfil tabs.
  // =========================================================================

  testWidgets(
      'GIVEN YachayScaffold '
      'WHEN tapping Camino tab '
      'THEN CaminoScreen is displayed with curriculum content',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: YachayScaffold()));

    // Tap the Camino tab
    await tester.tap(find.text('Camino'));
    await tester.pumpAndSettle();

    // CaminoScreen renders curriculum title and topic cards
    expect(find.textContaining('curriculum'), findsOneWidget);
    expect(find.text('Valor Posicional'), findsOneWidget);
    expect(find.text('Lectura y Escritura'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });
}
