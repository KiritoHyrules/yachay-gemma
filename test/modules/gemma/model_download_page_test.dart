import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/gemma/gemma_service.dart';
import 'package:aprendo_plus/modules/gemma/model_download_page.dart';
import 'package:aprendo_plus/modules/gemma/model_status.dart';

/// Widget tests for the model download page (gemma4-runtime).
///
/// The page is rendered with an injectable [GemmaService] whose
/// [ModelStatusController] drives the UI, so no filesystem, network or plugin
/// surface is touched.
void main() {
  Widget wrap(GemmaService service, {VoidCallback? onModelReady}) {
    return MaterialApp(
      home: ModelDownloadPage(
        gemmaService: service,
        onModelReady: onModelReady,
      ),
    );
  }

  group('ModelDownloadPage', () {
    testWidgets(
        'GIVEN no model installed '
        'WHEN the page renders '
        'THEN it shows the Sin modelo state with direct download action',
        (tester) async {
      final service = GemmaService.forTest();

      await tester.pumpWidget(wrap(service));

      expect(find.text('Sin modelo'), findsOneWidget);
      expect(find.text('Conecta Yachay'), findsOneWidget);
      expect(find.text('Descargar modelo'), findsOneWidget);
      expect(find.text('Usar token de HuggingFace (opcional)'), findsOneWidget);
    });

    testWidgets(
        'GIVEN the download is in progress '
        'WHEN the page renders '
        'THEN it shows the live progress and disables the actions',
        (tester) async {
      final service = GemmaService.forTest();
      service.statusController.downloading(42);

      await tester.pumpWidget(wrap(service));

      expect(find.text('Descargando 42%'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final downloadButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Descargando...'),
      );
      expect(downloadButton.onPressed, isNull);
    });

    testWidgets(
        'GIVEN the model is ready '
        'WHEN the page renders '
        'THEN it shows the ready state and the Continuar action navigates',
        (tester) async {
      final service = GemmaService.forTest();
      service.statusController.ready(null);
      var continued = false;

      await tester.pumpWidget(
        wrap(service, onModelReady: () => continued = true),
      );

      expect(find.text('Listo (CPU)'), findsOneWidget);
      expect(find.text('¡Modelo listo!'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(continued, isTrue);
    });

    testWidgets(
        'GIVEN a download failure '
        'WHEN the page renders '
        'THEN it shows an actionable Spanish error', (tester) async {
      final service = GemmaService.forTest();
      service.statusController.error(
        'No hay suficiente espacio de almacenamiento para el modelo '
        '(2.59 GB). Libera espacio e inténtalo de nuevo.',
      );

      await tester.pumpWidget(wrap(service));

      expect(find.text('No se pudo preparar el modelo'), findsOneWidget);
      expect(find.textContaining('Libera espacio'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Usar token de HuggingFace (opcional)'), findsOneWidget);
    });
  });
}
