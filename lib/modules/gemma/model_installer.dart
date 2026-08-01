import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Known model file: `gemma-4-E2B-it.litertlm` (≈2.59 GB), installed by the
/// flutter_gemma plugin into the app documents directory. The model is
/// external and never versioned in the repo (ADR-6).
const String kGemmaModelFileName = 'gemma-4-E2B-it.litertlm';

/// Gated HuggingFace download URL (litert-community model zoo).
const String kGemmaModelDownloadUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
    'resolve/main/gemma-4-E2B-it.litertlm?download=true';

/// Expected model size in bytes (≈ 2.59 GB).
const int kGemmaModelExpectedBytes = 2590000000;

/// Minimum acceptable size: 90% of the expected size. A file below this gate
/// is truncated and treated as corrupt regardless of checksum.
const int kGemmaModelMinBytes = 2331000000; // 0.9 × expected

/// Typed download failures surfaced to the status chip and the degraded
/// mode (REQ-02 / REQ-04 of gemma-model-download).
enum ModelDownloadFailure {
  forbidden,
  unauthorized,
  noSpace,
  network,
  corrupt,
  unknown,
}

/// Thrown by [ModelInstaller.install] with a typed [failure].
class ModelDownloadException implements Exception {
  const ModelDownloadException(this.failure, [this.detail]);

  final ModelDownloadFailure failure;
  final String? detail;

  @override
  String toString() =>
      'ModelDownloadException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Seam: model installation through the flutter_gemma plugin, testable
/// without network (an in-memory fake covers the service tests).
abstract class ModelInstaller {
  Future<bool> isModelInstalled();

  /// Downloads and activates the model. Throws [ModelDownloadException].
  Future<void> install({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
  });
}

/// Seam: integrity verification of the downloaded model.
///
/// Cleanup is BOUNDED to the exact model file (ADR-5): there is no nuclear
/// cleanup and the student DB is never touched (REQ-06).
abstract class ModelIntegrityVerifier {
  /// Size gate always; SHA256 when [fullCheck] (post-download).
  Future<bool> verify({bool fullCheck = false});

  /// Deletes ONLY the exact model file (known name), never more.
  Future<void> deleteCorruptFile();
}

/// Seam: OAuth PKCE or manual token. Reduced to "give me a token or null".
abstract class TokenProvider {
  Future<String?> getAccessToken();
}

/// Real [ModelInstaller] backed by `FlutterGemma.installModel(...)` (1.4.2).
///
/// Maps the plugin's sealed [DownloadError] onto the app's typed
/// [ModelDownloadFailure] so the chip can render actionable Spanish messages.
class FlutterGemmaModelInstaller implements ModelInstaller {
  @override
  Future<bool> isModelInstalled() async {
    final file = File(await _modelFilePath());
    return file.exists();
  }

  @override
  Future<void> install({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
  }) async {
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(url, token: token, foreground: true)
          .withProgress((percent) => onProgress?.call(percent))
          .install();
    } on DownloadException catch (e) {
      throw ModelDownloadException(_mapFailure(e.error));
    } on Exception catch (e) {
      throw ModelDownloadException(_mapUnexpected(e));
    }
  }

  Future<String> _modelFilePath() async {
    // The flutter_gemma plugin resolves model storage to the app documents
    // directory on Android/iOS via path_provider; mirror the same call so the
    // verifier/installer agree with the plugin on where the file lives.
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, kGemmaModelFileName);
  }

  static ModelDownloadFailure _mapFailure(DownloadError error) {
    return switch (error) {
      UnauthorizedError() => ModelDownloadFailure.unauthorized,
      ForbiddenError() => ModelDownloadFailure.forbidden,
      NotFoundError() ||
      RateLimitedError() ||
      ServerError() ||
      NetworkError() =>
        ModelDownloadFailure.network,
      CanceledError() || UnknownError() => ModelDownloadFailure.unknown,
    };
  }

  static ModelDownloadFailure _mapUnexpected(Exception error) {
    final message = error.toString().toLowerCase();
    const storageMarkers = [
      'no space',
      'enospc',
      'disk full',
      'insufficient storage',
    ];
    if (storageMarkers.any(message.contains)) {
      return ModelDownloadFailure.noSpace;
    }
    return ModelDownloadFailure.network;
  }
}

/// Real [ModelIntegrityVerifier]: size gate always, SHA256 after download.
class GemmaModelIntegrityVerifier implements ModelIntegrityVerifier {
  const GemmaModelIntegrityVerifier({this.minBytes = kGemmaModelMinBytes});

  final int minBytes;

  @override
  Future<bool> verify({bool fullCheck = false}) async {
    final file = File(await _modelFilePath());
    if (!await file.exists()) return false;
    if (await file.length() < minBytes) return false; // size gate always
    if (!fullCheck) return true; // fast path: size only
    return _sha256Matches(file);
  }

  @override
  Future<void> deleteCorruptFile() async {
    final file = File(await _modelFilePath());
    if (await file.exists()) {
      await file.delete();
    }
    // Bounded: ONLY the exact model file is deleted (ADR-5 / REQ-06). The
    // persisted SHA256 sidecar is intentionally kept as the reference for
    // the next download.
  }

  Future<String> _modelFilePath() async {
    // The flutter_gemma plugin resolves model storage to the app documents
    // directory on Android/iOS via path_provider; mirror the same call so the
    // verifier/installer agree with the plugin on where the file lives.
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, kGemmaModelFileName);
  }

  /// SHA256 full check. The reference hash is not published for this build,
  /// so it is calibrated on the first verified download and persisted in a
  /// sidecar next to the model; later downloads are compared against it.
  Future<bool> _sha256Matches(File file) async {
    final reference = await _referenceHash();
    final actual = await _sha256(file);
    if (reference == null) {
      await _persistHash(actual);
      return true;
    }
    return reference == actual;
  }

  Future<String?> _referenceHash() async {
    final sidecar = File('${await _modelFilePath()}.sha256');
    if (!await sidecar.exists()) return null;
    final content = await sidecar.readAsString();
    return content.trim().isEmpty ? null : content.trim();
  }

  Future<void> _persistHash(String hash) async {
    final sidecar = File('${await _modelFilePath()}.sha256');
    await sidecar.writeAsString(hash, flush: true);
  }

  /// Hashes a multi-GB file off the UI isolate.
  Future<String> _sha256(File file) {
    final path = file.path;
    return Isolate.run(() async {
      final digest = sha256.bind(File(path).openRead());
      return (await digest.first).toString();
    });
  }
}
