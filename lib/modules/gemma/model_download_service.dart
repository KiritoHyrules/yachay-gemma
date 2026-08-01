import 'package:flutter/foundation.dart';

import 'model_installer.dart';
import 'model_status.dart';

/// Outcome of a [ModelDownloadService.ensureModelReady] run.
@immutable
class ModelDownloadResult {
  const ModelDownloadResult({
    required this.success,
    this.failure,
    this.didDownload = false,
  });

  /// True when the model is installed, verified and ready for createModel.
  final bool success;

  /// Typed failure when [success] is false (403 / no space / corrupt / ...).
  final ModelDownloadFailure? failure;

  /// True when this run actually downloaded the model file.
  final bool didDownload;
}

/// Orchestrates the model bootstrap: verify → download → verify, idempotent,
/// with exactly one bounded re-download on corruption and zero retries on
/// auth/storage failures (REQ-01..REQ-06 of gemma-model-download).
class ModelDownloadService {
  ModelDownloadService({
    required ModelInstaller installer,
    required ModelIntegrityVerifier verifier,
    required TokenProvider tokens,
    required ModelStatusController status,
  })  : _installer = installer,
        _verifier = verifier,
        _tokens = tokens,
        _status = status;

  final ModelInstaller _installer;
  final ModelIntegrityVerifier _verifier;
  final TokenProvider _tokens;
  final ModelStatusController _status;

  /// Ensures the model is downloaded, verified and ready.
  ///
  /// - Already installed and size-intact → skip download (idempotent).
  /// - Installed but corrupt → delete the exact file, then download.
  /// - Download fails with 403 / no space → terminal error, no retry loop.
  /// - Downloaded file fails verification → delete exact file + one retry;
  ///   a second corruption degrades with a clear error.
  Future<ModelDownloadResult> ensureModelReady() async {
    // Idempotent fast path: installed and intact.
    if (await _installer.isModelInstalled()) {
      _status.verifying();
      if (await _verifier.verify()) {
        return const ModelDownloadResult(success: true);
      }
      // Installed but corrupt: remove the exact file and fall through to a
      // fresh download (REQ-03).
      await _verifier.deleteCorruptFile();
    }

    final token = await _tokens.getAccessToken();
    var downloaded = false;

    // Exactly two attempts: initial download + one bounded re-download.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _installer.install(
          url: kGemmaModelDownloadUrl,
          token: token,
          onProgress: (percent) => _status.downloading(percent),
        );
        downloaded = true;
      } on ModelDownloadException catch (e) {
        // Auth/storage failures are terminal: actionable error, no retry
        // loop (REQ-02, REQ-04).
        _status.error(_messageFor(e.failure));
        return ModelDownloadResult(
          success: false,
          failure: e.failure,
          didDownload: downloaded,
        );
      }

      _status.verifying();
      if (await _verifier.verify(fullCheck: true)) {
        return ModelDownloadResult(success: true, didDownload: downloaded);
      }

      // Corrupt download: delete ONLY the exact model file, then retry once.
      await _verifier.deleteCorruptFile();
    }

    _status.error(_messageFor(ModelDownloadFailure.corrupt));
    return const ModelDownloadResult(
      success: false,
      failure: ModelDownloadFailure.corrupt,
      didDownload: true,
    );
  }

  /// Actionable Spanish messages rendered by the status chip.
  static String _messageFor(ModelDownloadFailure failure) {
    switch (failure) {
      case ModelDownloadFailure.forbidden:
        return 'Acceso denegado por HuggingFace. Revisa tu token o acepta la '
            'licencia del modelo en huggingface.co.';
      case ModelDownloadFailure.unauthorized:
        return 'No autorizado por HuggingFace. Revisa tu token en la '
            'configuración.';
      case ModelDownloadFailure.noSpace:
        return 'No hay suficiente espacio de almacenamiento para el modelo '
            '(2.59 GB). Libera espacio e inténtalo de nuevo.';
      case ModelDownloadFailure.network:
        return 'Error de red al descargar el modelo. Revisa tu conexión e '
            'inténtalo de nuevo.';
      case ModelDownloadFailure.corrupt:
        return 'El modelo descargado está dañado. Se reintentará la descarga '
            'en la próxima ejecución.';
      case ModelDownloadFailure.unknown:
        return 'No se pudo preparar el modelo. Inténtalo de nuevo.';
    }
  }
}
