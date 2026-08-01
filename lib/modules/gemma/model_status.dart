import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;

/// Machine states of the on-device model exposed to the status chip.
///
/// Mirrors the bootstrap lifecycle of `ModelDownloadService`:
/// noModel → downloading → verifying → ready, with error reachable from
/// any step.
enum ModelStatus { noModel, downloading, verifying, ready, error }

/// Immutable snapshot of the model status at a point in time.
///
/// [label] is the learner-facing Spanish text rendered by the chip; it is
/// derived from the other fields, so the widget only ever reads a plain
/// value.
@immutable
class ModelStatusInfo {
  const ModelStatusInfo({
    required this.status,
    this.progressPercent,
    this.errorMessage,
    this.backendLabel = '',
  });

  final ModelStatus status;

  /// Download progress in 0..100 while [ModelStatus.downloading].
  final int? progressPercent;

  /// Actionable Spanish message while [ModelStatus.error].
  final String? errorMessage;

  /// Effective backend label ('CPU', 'GPU', 'NPU') once ready.
  final String backendLabel;

  /// Learner-facing chip text.
  String get label {
    switch (status) {
      case ModelStatus.noModel:
        return 'Sin modelo';
      case ModelStatus.downloading:
        return 'Descargando ${progressPercent ?? 0}%';
      case ModelStatus.verifying:
        return 'Verificando';
      case ModelStatus.ready:
        return 'Listo ($backendLabel)';
      case ModelStatus.error:
        return 'Error';
    }
  }
}

/// [ValueNotifier] feeding the status chip.
///
/// The UI never couples to the runtime: the chip listens to this notifier
/// and renders [ModelStatusInfo.label].
class ModelStatusController extends ValueNotifier<ModelStatusInfo> {
  ModelStatusController()
      : super(const ModelStatusInfo(status: ModelStatus.noModel));

  void downloading(int percent) {
    final clamped = percent.clamp(0, 100);
    value = ModelStatusInfo(
      status: ModelStatus.downloading,
      progressPercent: clamped as int,
    );
  }

  void verifying() {
    value = const ModelStatusInfo(status: ModelStatus.verifying);
  }

  /// Marks the model ready on the effective backend.
  ///
  /// The plugin degrades GPU → CPU when the GPU path is unavailable, so a
  /// null/unknown backend is reported as CPU rather than a generic
  /// "Offline".
  void ready(PreferredBackend? backend) {
    value = ModelStatusInfo(
      status: ModelStatus.ready,
      backendLabel: _backendLabel(backend),
    );
  }

  void error(String message) {
    value = ModelStatusInfo(status: ModelStatus.error, errorMessage: message);
  }

  void reset() {
    value = const ModelStatusInfo(status: ModelStatus.noModel);
  }

  static String _backendLabel(PreferredBackend? backend) {
    switch (backend) {
      case PreferredBackend.cpu:
        return 'CPU';
      case PreferredBackend.gpu:
        return 'GPU';
      case PreferredBackend.npu:
        return 'NPU';
      case null:
        return 'CPU';
    }
  }
}
