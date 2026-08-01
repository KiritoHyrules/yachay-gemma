import 'package:flutter/foundation.dart';

enum ExerciseType {
  opcionMultiple,
  verdaderoFalso,
  respuestaCorta;

  String get label {
    switch (this) {
      case ExerciseType.opcionMultiple:
        return 'opcion_multiple';
      case ExerciseType.verdaderoFalso:
        return 'verdadero_falso';
      case ExerciseType.respuestaCorta:
        return 'respuesta_corta';
    }
  }

  static ExerciseType fromString(String value) {
    switch (value) {
      case 'opcion_multiple':
        return ExerciseType.opcionMultiple;
      case 'verdadero_falso':
        return ExerciseType.verdaderoFalso;
      case 'respuesta_corta':
        return ExerciseType.respuestaCorta;
      default:
        return ExerciseType.opcionMultiple;
    }
  }
}

@immutable
class Exercise {
  final String id;
  final ExerciseType type;
  final String enunciado;
  final List<String>? opciones;
  final String respuestaCorrecta;
  final Map<String, String>? feedbackPorError;

  const Exercise({
    required this.id,
    required this.type,
    required this.enunciado,
    this.opciones,
    required this.respuestaCorrecta,
    this.feedbackPorError,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.label,
      'enunciado': enunciado,
      'opciones': opciones,
      'respuesta_correcta': respuestaCorrecta,
      'feedback_por_error': feedbackPorError,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      type: ExerciseType.fromString(json['type'] as String),
      enunciado: json['enunciado'] as String,
      opciones: (json['opciones'] as List<dynamic>?)
          ?.map((o) => o as String)
          .toList(),
      respuestaCorrecta: json['respuesta_correcta'] as String,
      feedbackPorError:
          (json['feedback_por_error'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)),
    );
  }
}
