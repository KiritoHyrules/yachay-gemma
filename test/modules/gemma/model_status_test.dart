import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;
import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/gemma/model_status.dart';

/// RED phase of task 3.1 — model status machine exposed to the UI chip
/// (REQ-01/02 gemma-model-status spec).
///
/// The controller is a plain `ValueNotifier<ModelStatusInfo>`; every assertion
/// checks the exact Spanish chip label and the machine state, never
/// implementation internals.
void main() {
  group('ModelStatusController — transiciones del chip', () {
    test(
        'GIVEN a fresh controller '
        'WHEN created '
        'THEN state is SinModelo without progress, error or backend', () {
      final controller = ModelStatusController();

      expect(controller.value.status, ModelStatus.noModel);
      expect(controller.value.progressPercent, isNull);
      expect(controller.value.errorMessage, isNull);
      expect(controller.value.label, 'Sin modelo');
    });

    test(
        'GIVEN the first-run bootstrap '
        'WHEN downloading/verifying/ready are fed '
        'THEN the chip walks SinModelo → Descargando X% → Verificando → Listo (CPU)',
        () {
      final controller = ModelStatusController();

      controller.downloading(0);
      expect(controller.value.status, ModelStatus.downloading);
      expect(controller.value.progressPercent, 0);
      expect(controller.value.label, 'Descargando 0%');

      controller.downloading(42);
      expect(controller.value.progressPercent, 42);
      expect(controller.value.label, 'Descargando 42%');

      controller.downloading(100);
      expect(controller.value.label, 'Descargando 100%');

      controller.verifying();
      expect(controller.value.status, ModelStatus.verifying);
      expect(controller.value.label, 'Verificando');

      controller.ready(PreferredBackend.cpu);
      expect(controller.value.status, ModelStatus.ready);
      expect(controller.value.backendLabel, 'CPU');
      expect(controller.value.label, 'Listo (CPU)');
    });

    test(
        'GIVEN the runtime fell back from GPU to CPU internally '
        'WHEN ready reports the effective backend '
        'THEN the chip shows Listo (CPU) and never the generic Offline', () {
      final controller = ModelStatusController();

      // The engine degrades GPU→CPU; activeBackend reports the real backend.
      controller.ready(PreferredBackend.cpu);

      expect(controller.value.status, ModelStatus.ready);
      expect(controller.value.backendLabel, 'CPU');
      expect(controller.value.label, 'Listo (CPU)');
      expect(controller.value.label, isNot(contains('Offline')));
    });

    test(
        'GIVEN the backend is reported as GPU '
        'WHEN ready is called '
        'THEN the chip labels the effective backend', () {
      final controller = ModelStatusController();

      controller.ready(PreferredBackend.gpu);

      expect(controller.value.backendLabel, 'GPU');
      expect(controller.value.label, 'Listo (GPU)');
    });

    test(
        'GIVEN both auth paths failed '
        'WHEN error is fed '
        'THEN state is Error with an actionable Spanish message', () {
      final controller = ModelStatusController();

      controller.error(
          'Para descargar el modelo necesitas autorizar tu cuenta de '
          'HuggingFace. Revisa el token en la configuración.');

      expect(controller.value.status, ModelStatus.error);
      expect(controller.value.errorMessage, contains('HuggingFace'));
      expect(controller.value.errorMessage, contains('token'));
      expect(controller.value.label, 'Error');
    });

    test(
        'GIVEN an errored controller '
        'WHEN reset is called '
        'THEN it returns to SinModelo without error or progress', () {
      final controller = ModelStatusController();

      controller.error('algo falló');
      controller.reset();

      expect(controller.value.status, ModelStatus.noModel);
      expect(controller.value.errorMessage, isNull);
      expect(controller.value.progressPercent, isNull);
      expect(controller.value.label, 'Sin modelo');
    });
  });
}
