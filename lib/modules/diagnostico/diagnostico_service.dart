import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/models/diagnostic_result.dart';
import '../../core/models/student_profile.dart';
import '../gemma/tool_registry.dart';

/// Internal model for a diagnostic item loaded from JSON.
class DiagnosticItem {
  final String id;
  final String materia;
  final String area;
  final String enunciado;
  final List<String> opciones;
  final int respuestaCorrecta;
  final double dificultad; // IRT b-param, range [-3.0, +3.0]
  final double discriminacion; // IRT a-param, range [0.5, 2.5]
  final int gradoEquivalente;

  const DiagnosticItem({
    required this.id,
    required this.materia,
    required this.area,
    required this.enunciado,
    required this.opciones,
    required this.respuestaCorrecta,
    required this.dificultad,
    required this.discriminacion,
    required this.gradoEquivalente,
  });

  factory DiagnosticItem.fromJson(Map<String, dynamic> json) {
    return DiagnosticItem(
      id: json['id'] as String,
      materia: json['materia'] as String,
      area: json['area'] as String,
      enunciado: json['enunciado'] as String,
      opciones: List<String>.from(json['opciones'] as List),
      respuestaCorrecta: json['respuestaCorrecta'] as int,
      dificultad: (json['dificultad'] as num).toDouble(),
      discriminacion: (json['discriminacion'] as num).toDouble(),
      gradoEquivalente: json['gradoEquivalente'] as int,
    );
  }
}

/// Simplified Item Response Theory (IRT) adaptive diagnostic service.
///
/// Algorithm: 2PL model with proximity-based item selection.
/// - Initializes theta at 0.0
/// - Selects the unanswered item with difficulty closest to current theta
/// - Updates theta after each response using probabilistic gradient
/// - Terminates at 25 items or when standard error <= 0.3
/// - Maps final theta to a 5-level competency framework
class DiagnosticoService {
  final List<DiagnosticItem> _itemBank;

  DiagnosticoService._(this._itemBank);

  /// Loads the diagnostic item banks from bundled JSON assets.
  ///
  /// Reads [items_matematica.json] and [items_lectura.json] from
  /// [assets/diagnostic/] and returns a configured service instance.
  static Future<DiagnosticoService> cargar() async {
    final mathJson = await rootBundle.loadString(
      'assets/diagnostic/items_matematica.json',
    );
    final readingJson = await rootBundle.loadString(
      'assets/diagnostic/items_lectura.json',
    );

    final mathItems = (json.decode(mathJson) as List)
        .map((e) => DiagnosticItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final readingItems = (json.decode(readingJson) as List)
        .map((e) => DiagnosticItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return DiagnosticoService._([...mathItems, ...readingItems]);
  }

  /// Returns the full item bank (for inspection / debugging).
  List<DiagnosticItem> get itemBank => List.unmodifiable(_itemBank);

  /// Runs the adaptive diagnostic for a given subject area.
  ///
  /// [materia] — 'matematicas' or 'lectura'.
  /// [onItem] — callback invoked each step: (item, index, total).
  /// [onProgress] — callback invoked each step: (theta, itemsAdministered).
  /// Returns a [DiagnosticResult] with the final level and precision estimate.
  Future<DiagnosticResult> ejecutarDiagnostico({
    required String materia,
    required Future<bool> Function(DiagnosticItem item) onItem,
    void Function(double theta, int itemsAdminstrados)? onProgress,
  }) async {
    // Filter bank to the requested subject
    final pool = _itemBank
        .where((i) => i.materia == materia)
        .toList()
      ..shuffle(Random(DateTime.now().millisecondsSinceEpoch));

    if (pool.isEmpty) {
      return const DiagnosticResult(
        nivel: 3,
        etiqueta: 'Practicante',
        theta: 0.0,
        precision: 0.0,
        itemsAdministrados: 0,
      );
    }

    const maxItems = 25;
    const seThreshold = 0.3;

    double theta = 0.0;
    double infoSum = 0.0;
    int n = 0;
    final administrados = <String>{};

    while (n < maxItems) {
      // Select unanswered item with difficulty closest to current theta
      final item = _seleccionarItem(theta, pool, administrados);
      if (item == null) break; // no more items available

      // Present item to student
      final correcta = await onItem(item);

      // Update theta via simplified IRT gradient step
      final respuesta = correcta ? 1.0 : 0.0;
      final p = _probabilidadEsperada(theta, item);
      final stepSize = 1.0 / (1.0 + n * 0.12);
      theta += item.discriminacion * (respuesta - p) * stepSize;

      // Clamp theta to valid range
      theta = theta.clamp(-3.0, 3.0);

      // Accumulate Fisher information for SE estimation
      final info = item.discriminacion * item.discriminacion * p * (1.0 - p);
      infoSum += info;
      n++;
      administrados.add(item.id);

      onProgress?.call(theta, n);

      // Early termination: standard error low enough
      if (infoSum > 0.0) {
        final se = 1.0 / sqrt(infoSum);
        if (se <= seThreshold) break;
      }
    }

    final nivel = _mapearThetaANivel(theta);
    final precision = infoSum > 0.0 ? 1.0 / sqrt(infoSum) : 0.0;
    final etiqueta = _etiquetaNivel(nivel);

    return DiagnosticResult(
      nivel: nivel,
      etiqueta: etiqueta,
      theta: theta,
      precision: precision,
      itemsAdministrados: n,
    );
  }

  /// Selects the unanswered item whose difficulty is closest to [theta].
  DiagnosticItem? _seleccionarItem(
    double theta,
    List<DiagnosticItem> pool,
    Set<String> administrados,
  ) {
    DiagnosticItem? best;
    double bestDist = double.infinity;

    for (final item in pool) {
      if (administrados.contains(item.id)) continue;
      final dist = (item.dificultad - theta).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = item;
      }
    }

    return best;
  }

  /// Computes the probability of a correct response under the 2PL IRT model.
  ///
  /// P(correct | theta) = 1 / (1 + exp(-a * (theta - b)))
  double _probabilidadEsperada(double theta, DiagnosticItem item) {
    final exponent = -item.discriminacion * (theta - item.dificultad);
    return 1.0 / (1.0 + exp(exponent));
  }

  /// Maps the final theta estimate to a 5-level integer.
  ///
  /// Thresholds (aligned with spec diagnostico-adaptativo):
  /// - theta <= -1.5 -> nivel 1 (Explorador)
  /// - theta <= -0.5 -> nivel 2 (Aprendiz)
  /// - theta <=  0.5 -> nivel 3 (Practicante)
  /// - theta <=  1.5 -> nivel 4 (Aventurero)
  /// - theta >   1.5 -> nivel 5 (Experto)
  int _mapearThetaANivel(double theta) {
    if (theta <= -1.5) return 1;
    if (theta <= -0.5) return 2;
    if (theta <= 0.5) return 3;
    if (theta <= 1.5) return 4;
    return 5;
  }

  /// Tool-mode wrapper without UI callbacks.
  ///
  /// Returns a [ToolResult] with the student's current diagnostic level
  /// derived from [perfil] (when available) or a default starting level.
  /// Designed for use by the `ejecutar_diagnostico` tool handler in the
  /// XML dispatch loop — no item presentation or user interaction.
  ///
  /// [materia] — 'matematicas' or 'lectura'.
  /// [perfil] — optional [StudentProfile]; when null, defaults to level 3.
  Future<ToolResult> ejecutarComoHerramienta(
    String materia,
    StudentProfile? perfil,
  ) async {
    final nivel = perfil != null
        ? (materia == 'lectura' ? perfil.readingLevel : perfil.mathLevel)
        : 3;
    final etiqueta = DiagnosticResult.etiquetaParaNivel(nivel);

    return ToolResult(
      summary:
          'Diagnóstico de $materia: nivel $nivel — $etiqueta. '
          'Para un diagnóstico más preciso, usa la sección de '
          'Diagnóstico en la aplicación.',
      payload: DiagnosticResult(
        nivel: nivel,
        etiqueta: etiqueta,
        theta: 0.0,
        precision: 0.3,
        itemsAdministrados: 0,
      ),
    );
  }

  /// Returns the Spanish competency label for a given level.
  String _etiquetaNivel(int nivel) {
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
