import 'package:flutter_test/flutter_test.dart';

import 'package:aprendo_plus/modules/gemma/model_download_service.dart';
import 'package:aprendo_plus/modules/gemma/model_installer.dart';
import 'package:aprendo_plus/modules/gemma/model_status.dart';

import 'fakes/model_download_fakes.dart';

/// RED phase of task 3.3 — `ModelDownloadService.ensureModelReady()` across
/// the six spec requirements (REQ-01..REQ-06 of gemma-model-download).
///
/// The installer/verifier/token seams are fakes: no network, no filesystem,
/// no plugin. Every assertion checks observable behavior (status machine
/// transitions, typed results, exact install/delete counts).
void main() {
  group('ModelDownloadService — REQ-01 descarga con installModel nativo', () {
    test(
        'GIVEN a first run without a model '
        'WHEN ensureModelReady() runs '
        'THEN the model is downloaded via installModel with token and 0→100 progress '
        'is fed to the status chip', () async {
      final installer = ModelInstallerFake();
      final verifier = ModelIntegrityVerifierFake();
      final tokens = TokenProviderFake(token: 'hf_abc123');
      final status = ModelStatusController();
      final service = ModelDownloadService(
        installer: installer,
        verifier: verifier,
        tokens: tokens,
        status: status,
      );

      final result = await service.ensureModelReady();

      expect(result.success, isTrue);
      expect(result.didDownload, isTrue);
      expect(installer.installCalls, 1);
      expect(installer.installTokens.single, 'hf_abc123');
      expect(installer.installUrls.single, contains('gemma-4-E2B-it.litertlm'));
      expect(installer.progressEvents, [0, 42, 100]);
      expect(status.value.status, ModelStatus.verifying);
      expect(tokens.calls, 1);
    });

    test(
        'GIVEN the model is already installed and intact '
        'WHEN ensureModelReady() runs '
        'THEN the download is skipped (idempotent)', () async {
      final installer = ModelInstallerFake(installed: true);
      final verifier = ModelIntegrityVerifierFake();
      final tokens = TokenProviderFake();
      final service = ModelDownloadService(
        installer: installer,
        verifier: verifier,
        tokens: tokens,
        status: ModelStatusController(),
      );

      final result = await service.ensureModelReady();

      expect(result.success, isTrue);
      expect(result.didDownload, isFalse);
      expect(installer.installCalls, 0);
      expect(tokens.calls, 0);
    });
  });

  group('ModelDownloadService — REQ-02 acceso gated', () {
    test(
        'GIVEN HuggingFace rejects the download with 403 '
        'WHEN ensureModelReady() runs '
        'THEN the chip shows an actionable error and install is attempted exactly once',
        () async {
      final installer = ModelInstallerFake(
        throwOnInstall: const ModelDownloadException(
          ModelDownloadFailure.forbidden,
        ),
      );
      final status = ModelStatusController();
      final service = ModelDownloadService(
        installer: installer,
        verifier: ModelIntegrityVerifierFake(),
        tokens: TokenProviderFake(),
        status: status,
      );

      final result = await service.ensureModelReady();

      expect(result.success, isFalse);
      expect(result.failure, ModelDownloadFailure.forbidden);
      expect(installer.installCalls, 1, reason: 'no retry loop on 403');
      expect(status.value.status, ModelStatus.error);
      expect(status.value.errorMessage, contains('HuggingFace'));
      expect(status.value.errorMessage, contains('token'));
    });

    test(
        'GIVEN both OAuth and manual token failed (null token) '
        'WHEN ensureModelReady() runs '
        'THEN install proceeds with null token and surfaces the gated error',
        () async {
      final installer = ModelInstallerFake(
        throwOnInstall: const ModelDownloadException(
          ModelDownloadFailure.forbidden,
        ),
      );
      final tokens = TokenProviderFake(token: null);
      final status = ModelStatusController();
      final service = ModelDownloadService(
        installer: installer,
        verifier: ModelIntegrityVerifierFake(),
        tokens: tokens,
        status: status,
      );

      final result = await service.ensureModelReady();

      expect(result.success, isFalse);
      expect(result.failure, ModelDownloadFailure.forbidden);
      expect(installer.installTokens.single, isNull);
      expect(status.value.status, ModelStatus.error);
    });
  });

  group('ModelDownloadService — REQ-03 integridad y re-descarga acotada', () {
    test(
        'GIVEN the first download is corrupt '
        'WHEN the post-download verification fails '
        'THEN the exact file is deleted and the download is retried once, '
        'ending ready', () async {
      final installer = ModelInstallerFake();
      final verifier = ModelIntegrityVerifierFake(verifyResults: [false, true]);
      final service = ModelDownloadService(
        installer: installer,
        verifier: verifier,
        tokens: TokenProviderFake(),
        status: ModelStatusController(),
      );

      final result = await service.ensureModelReady();

      expect(result.success, isTrue);
      expect(result.didDownload, isTrue);
      expect(installer.installCalls, 2, reason: 'download + one retry');
      expect(verifier.deleteCalls, 1, reason: 'only the corrupt file, once');
      expect(verifier.verifyCalls, 2);
    });

    test(
        'GIVEN the download is corrupt twice '
        'WHEN both verification passes fail '
        'THEN the app degrades with a clear error and no third attempt',
        () async {
      final installer = ModelInstallerFake();
      final verifier = ModelIntegrityVerifierFake(verifyResults: [false, false]);
      final status = ModelStatusController();
      final service = ModelDownloadService(
        installer: installer,
        verifier: verifier,
        tokens: TokenProviderFake(),
        status: status,
      );

      final result = await service.ensureModelReady();

      expect(result.success, isFalse);
      expect(result.failure, ModelDownloadFailure.corrupt);
      expect(installer.installCalls, 2, reason: 'download + exactly one retry');
      expect(verifier.deleteCalls, 2);
      expect(status.value.status, ModelStatus.error);
      expect(status.value.errorMessage, contains('modelo'));
    });
  });

  group('ModelDownloadService — REQ-04 resiliencia de almacenamiento', () {
    test(
        'GIVEN the device has no free space '
        'WHEN the download fails with noSpace '
        'THEN the chip shows a clear storage error and the service does not crash',
        () async {
      final installer = ModelInstallerFake(
        throwOnInstall: const ModelDownloadException(
          ModelDownloadFailure.noSpace,
        ),
      );
      final status = ModelStatusController();
      final service = ModelDownloadService(
        installer: installer,
        verifier: ModelIntegrityVerifierFake(),
        tokens: TokenProviderFake(),
        status: status,
      );

      final result = await service.ensureModelReady();

      expect(result.success, isFalse);
      expect(result.failure, ModelDownloadFailure.noSpace);
      expect(status.value.status, ModelStatus.error);
      expect(status.value.errorMessage, contains('espacio'));
    });
  });

  group('ModelDownloadService — REQ-06 seguridad de datos del estudiante', () {
    test(
        'GIVEN a corrupt download recovery cycle '
        'WHEN cleanup runs '
        'THEN the only deletion is the exact model file via deleteCorruptFile, '
        'never a broader cleanup',
        () async {
      final installer = ModelInstallerFake();
      final verifier = ModelIntegrityVerifierFake(verifyResults: [false, true]);
      final service = ModelDownloadService(
        installer: installer,
        verifier: verifier,
        tokens: TokenProviderFake(),
        status: ModelStatusController(),
      );

      final result = await service.ensureModelReady();

      expect(result.success, isTrue);
      expect(verifier.deleteCalls, 1,
          reason: 'bounded: one deleteCorruptFile, nothing else');
      expect(installer.installCalls, 2);
      // The seam exposes no other deletion surface: cleanup is structurally
      // limited to the exact model file (ADR-5).
    });
  });
}
