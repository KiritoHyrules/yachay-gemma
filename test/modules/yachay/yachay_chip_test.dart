import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;
import 'package:provider/provider.dart';

import 'package:aprendo_plus/core/database/database_service.dart';
import 'package:aprendo_plus/core/state/student_state.dart';
import 'package:aprendo_plus/modules/gemma/gemma_service.dart';
import 'package:aprendo_plus/modules/gemma/model_status.dart';
import 'package:aprendo_plus/modules/yachay/screens/yachay_scaffold.dart';

import '../gemma/fakes/gemma_inference_adapter_fake.dart';

/// RED phase of task 4.1 — status chip of YachayScaffold
/// (REQ-01/02 gemma-model-status spec).
///
/// The chip MUST show exactly one of the five bootstrap states and NEVER the
/// generic "Offline" text. When the model is ready, the chip reflects the
/// effective backend from `activeBackend` (e.g. `Listo (CPU)`).
void main() {
  Widget buildScaffold(GemmaService service) {
    return ChangeNotifierProvider<StudentState>.value(
      value: StudentState(DatabaseService.instance),
      child: MaterialApp(home: YachayScaffold(gemmaService: service)),
    );
  }

  /// Polls with plain pumps until [condition] holds. The fallback data is
  /// pre-injected via the test seam, so the whole bootstrap chain stays in
  /// the fake-async zone (microtasks + timers) — no runAsync, no platform
  /// mocks, deterministic regardless of execution order.
  Future<void> waitForPump(
    WidgetTester tester,
    bool Function() condition, {
    int attempts = 30,
  }) async {
    for (var i = 0; i < attempts && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('YachayScaffold status chip — 5 estados', () {
    testWidgets(
        'GIVEN no model installed '
        'WHEN the scaffold renders '
        'THEN the chip shows "Sin modelo" and never the generic "Offline"',
        (tester) async {
      final service = GemmaService.forTest(
        adapter: GemmaInferenceAdapterFake(loadModelResult: false),
      );
      service.setFallbackDataForTest({});

      await tester.pumpWidget(buildScaffold(service));
      await tester.pump();

      expect(find.text('Sin modelo'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
      expect(find.text('Listo (CPU)'), findsNothing);
    });

    testWidgets(
        'GIVEN the first-run download '
        'WHEN downloading/verifying are fed '
        'THEN the chip walks "Descargando X%" then "Verificando"',
        (tester) async {
      final service = GemmaService.forTest(
        adapter: GemmaInferenceAdapterFake(loadModelResult: false),
      );
      service.setFallbackDataForTest({});
      final controller = service.statusController;

      await tester.pumpWidget(buildScaffold(service));
      await tester.pump();

      controller.downloading(0);
      await tester.pump();
      expect(find.text('Descargando 0%'), findsOneWidget);

      controller.downloading(42);
      await tester.pump();
      expect(find.text('Descargando 42%'), findsOneWidget);

      controller.downloading(100);
      await tester.pump();
      expect(find.text('Descargando 100%'), findsOneWidget);

      controller.verifying();
      await tester.pump();
      expect(find.text('Verificando'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets(
        'GIVEN the model loaded on the CPU backend '
        'WHEN activeBackend reports cpu '
        'THEN the chip shows "Listo (CPU)" (REQ-02)',
        (tester) async {
      // The engine degraded GPU→CPU internally; activeBackend reports the
      // effective backend, which the scaffold must surface in the chip.
      final service = GemmaService.forTest(
        adapter: GemmaInferenceAdapterFake(loadModelResult: true),
      );
      service.setFallbackDataForTest({});

      await tester.pumpWidget(buildScaffold(service));
      // initState's cargarModelo runs entirely in the fake-async zone
      // (fallback pre-injected, fake adapter) — a couple of pumps flush it.
      await waitForPump(
        tester,
        () => service.statusController.value.status == ModelStatus.ready,
      );
      await tester.pump();

      expect(service.statusController.value.status, ModelStatus.ready);
      expect(find.text('Listo (CPU)'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets(
        'GIVEN the model reports the GPU backend '
        'WHEN ready is fed '
        'THEN the chip labels the effective backend',
        (tester) async {
      final service = GemmaService.forTest(
        adapter: GemmaInferenceAdapterFake(loadModelResult: false),
      );
      service.setFallbackDataForTest({});
      final controller = service.statusController;

      await tester.pumpWidget(buildScaffold(service));
      await tester.pump();

      controller.ready(PreferredBackend.gpu);
      await tester.pump();
      expect(find.text('Listo (GPU)'), findsOneWidget);
    });

    testWidgets(
        'GIVEN an install/auth failure '
        'WHEN error is fed '
        'THEN the chip shows "Error" without crashing',
        (tester) async {
      final service = GemmaService.forTest(
        adapter: GemmaInferenceAdapterFake(loadModelResult: false),
      );
      service.setFallbackDataForTest({});
      final controller = service.statusController;

      await tester.pumpWidget(buildScaffold(service));
      await tester.pump();

      controller.error(
          'Acceso denegado por HuggingFace. Revisa tu token o acepta la '
          'licencia del modelo en huggingface.co.');
      await tester.pump();

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
