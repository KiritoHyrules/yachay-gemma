import 'package:flutter/foundation.dart';

@immutable
class DiagnosticResult {
  final int nivel;
  final String etiqueta;
  final double theta;
  final double precision;
  final int itemsAdministrados;

  const DiagnosticResult({
    required this.nivel,
    required this.etiqueta,
    required this.theta,
    required this.precision,
    required this.itemsAdministrados,
  });

  Map<String, dynamic> toJson() {
    return {
      'nivel': nivel,
      'etiqueta': etiqueta,
      'theta': theta,
      'precision': precision,
      'items_administrados': itemsAdministrados,
    };
  }

  factory DiagnosticResult.fromJson(Map<String, dynamic> json) {
    return DiagnosticResult(
      nivel: json['nivel'] as int,
      etiqueta: json['etiqueta'] as String,
      theta: (json['theta'] as num).toDouble(),
      precision: (json['precision'] as num).toDouble(),
      itemsAdministrados: json['items_administrados'] as int,
    );
  }

  /// Canonical level labels used across all screens and services.
  /// Single source of truth — do NOT duplicate elsewhere.
  static String etiquetaParaNivel(int nivel) {
    switch (nivel) {
      case 1:
        return 'Explorador';
      case 2:
        return 'Aprendiz';
      case 3:
        return 'Practicante';
      case 4:
        return 'Aventurero';
      case 5:
        return 'Experto';
      default:
        return 'Practicante';
    }
  }
}
