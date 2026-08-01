import 'package:aprendo_plus/modules/gemma/model_installer.dart';

/// In-memory [ModelInstaller] for download-service tests.
///
/// Records every call (URL, token, progress events) and can be configured to
/// throw a typed [ModelDownloadException] (403 / no space / network) exactly
/// like the real plugin seam — no network involved.
class ModelInstallerFake implements ModelInstaller {
  ModelInstallerFake({
    this.installed = false,
    this.throwOnInstall,
  });

  /// What [isModelInstalled] reports.
  bool installed;

  /// When set, [install] throws this typed exception instead of emitting
  /// progress.
  ModelDownloadException? throwOnInstall;

  int installCalls = 0;
  final List<String> installUrls = [];
  final List<String?> installTokens = [];
  final List<int> progressEvents = [];

  @override
  Future<bool> isModelInstalled() async => installed;

  @override
  Future<void> install({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
  }) async {
    installCalls++;
    installUrls.add(url);
    installTokens.add(token);
    final error = throwOnInstall;
    if (error != null) {
      throw error;
    }
    if (onProgress != null) {
      for (final percent in [0, 42, 100]) {
        progressEvents.add(percent);
        onProgress(percent);
      }
    }
  }
}

/// In-memory [ModelIntegrityVerifier] for download-service tests.
///
/// [verifyResults] is consumed in order; the last value repeats. Recording
/// [deleteCalls] lets tests assert the cleanup is bounded to the exact model
/// file (REQ-06) and happens at most once per corrupt detection.
class ModelIntegrityVerifierFake implements ModelIntegrityVerifier {
  ModelIntegrityVerifierFake({List<bool>? verifyResults})
      : verifyResults = verifyResults ?? const [true];

  final List<bool> verifyResults;
  int verifyCalls = 0;
  int deleteCalls = 0;

  @override
  Future<bool> verify({bool fullCheck = false}) async {
    final index =
        verifyCalls < verifyResults.length ? verifyCalls : verifyResults.length - 1;
    verifyCalls++;
    return verifyResults[index];
  }

  @override
  Future<void> deleteCorruptFile() async {
    deleteCalls++;
  }
}

/// In-memory [TokenProvider]; returns the configured token (or null when
/// both OAuth and manual fallback failed).
class TokenProviderFake implements TokenProvider {
  TokenProviderFake({this.token = 'hf_test_token'});

  String? token;
  int calls = 0;

  @override
  Future<String?> getAccessToken() async {
    calls++;
    return token;
  }
}
