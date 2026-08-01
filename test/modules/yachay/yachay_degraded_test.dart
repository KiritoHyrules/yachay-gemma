import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aprendo_plus/core/database/database_service.dart';
import 'package:aprendo_plus/core/state/student_state.dart';
import 'package:aprendo_plus/modules/gemma/gemma_service.dart';
import 'package:aprendo_plus/modules/yachay/screens/yachay_scaffold.dart';

import '../gemma/fakes/gemma_inference_adapter_fake.dart';

/// RED phase of task 4.2 — degraded (no-AI) mode of YachayScaffold
/// (REQ-03/04 gemma-model-status spec).
///
/// With state `Sin modelo` or `Error` the app MUST keep answering through
/// `FallbackDispatcher` without crashing, and the chip MUST keep reflecting
/// the real state — never `Listo` while the model is not operational.
void main() {
  // Helper: wraps a widget with the now-required Provider<StudentState>.
  Widget wrapWithState(Widget child) {
    return ChangeNotifierProvider<StudentState>.value(
      value: StudentState(DatabaseService.instance),
      child: child,
    );
  }
  /// Polls with plain pumps until [condition] holds. The fallback data is
  /// pre-injected via the test seam and path_provider is mocked, so the
  /// whole bootstrap chain stays in the fake-async zone — no runAsync,
  /// deterministic regardless of execution order.
  Future<void> waitForPump(
    WidgetTester tester,
    bool Function() condition, {
    int attempts = 30,
  }) async {
    for (var i = 0; i < attempts && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUp(() {
    // The bootstrap probes the installer, which resolves the app documents
    // directory through path_provider. Without a device the plugin is
    // unavailable; make that failure immediate (microtask) so the degraded
    // path is exercised without real IO.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => throw MissingPluginException('no implementation'),
    );
  });

  group('YachayScaffold — modo degradado sin modelo', () {
    testWidgets(
        'GIVEN no model installed '
        'WHEN the student sends a message '
        'THEN FallbackDispatcher answers, the app does not crash '
        'and the chip keeps showing "Sin modelo"',
        (tester) async {
      final service = GemmaService.forTest(
        adapter: GemmaInferenceAdapterFake(loadModelResult: false),
      );
      service.setFallbackDataForTest({});

      await tester.pumpWidget(
        wrapWithState(MaterialApp(home: YachayScaffold(gemmaService: service))),
      );
      await tester.pump();

      // Chip reflects the real state before interacting.
      expect(find.text('Sin modelo'), findsOneWidget);

      // Send a message that Layer 2 routes to generar_ejercicios.
      await tester.enterText(
          find.byType(TextField), 'quiero practicar ejercicios de álgebra');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await waitForPump(
        tester,
        () => find.byKey(const Key('yachay-bubble-msg-1')).evaluate().isNotEmpty,
      );
      await tester.pump();

      // A Yachay bubble with the degraded response appeared (no crash).
      final bubble = find.byKey(const Key('yachay-bubble-msg-1'));
      expect(bubble, findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(of: bubble, matching: find.byType(Text)),
      );
      expect(text.data, isNotEmpty);
      expect(tester.takeException(), isNull);

      // Chat remains usable: prompt bar is enabled again.
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      // The chip still shows the real state — never a false "Listo".
      expect(find.text('Sin modelo'), findsOneWidget);
      expect(find.text('Listo (CPU)'), findsNothing);
    });

    testWidgets(
        'GIVEN an error state (both auth paths failed) '
        'WHEN the student interacts '
        'THEN tutoring keeps working without crash '
        'and the chip keeps showing "Error"',
        (tester) async {
      final service = GemmaService.forTest(
        adapter: GemmaInferenceAdapterFake(loadModelResult: false),
      );
      service.setFallbackDataForTest({});
      service.statusController.error(
          'Para descargar el modelo necesitas autorizar tu cuenta de '
          'HuggingFace. Revisa el token en la configuración.');

      await tester.pumpWidget(
        wrapWithState(MaterialApp(home: YachayScaffold(gemmaService: service))),
      );
      await tester.pump();
      expect(find.text('Error'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'explicame fracciones');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await waitForPump(
        tester,
        () => find.byKey(const Key('yachay-bubble-msg-1')).evaluate().isNotEmpty,
      );
      await tester.pump();

      final bubble = find.byKey(const Key('yachay-bubble-msg-1'));
      expect(bubble, findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(of: bubble, matching: find.byType(Text)),
      );
      expect(text.data, isNotEmpty);
      expect(tester.takeException(), isNull);

      // Chip keeps reflecting the real error state.
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Listo (CPU)'), findsNothing);
    });
  });
}
