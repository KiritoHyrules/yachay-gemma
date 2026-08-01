import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/models/lesson.dart';
import '../../core/models/exercise.dart';

/// Tracks exercise progress within a single lesson session.
class LessonProgress {
  final String lessonId;
  int currentStep; // 0 = explanation, 1+ = exercise index
  final List<String> completedExerciseIds;
  final Map<ExerciseType, int> errorsByType;
  bool reinforcementTriggered;

  LessonProgress({
    required this.lessonId,
    this.currentStep = 0,
    List<String>? completedExerciseIds,
    Map<ExerciseType, int>? errorsByType,
    this.reinforcementTriggered = false,
  })  : completedExerciseIds = completedExerciseIds ?? [],
        errorsByType = errorsByType ?? {};

  int get totalCompleted => completedExerciseIds.length;

  void recordError(ExerciseType type) {
    errorsByType[type] = (errorsByType[type] ?? 0) + 1;
  }

  bool get needsReinforcement {
    return errorsByType.values.any((count) => count >= 3);
  }
}

/// Loads and parses lesson content from JSON assets.
///
/// Provides access to the 5 preloaded lessons with progress tracking
/// and error pattern detection for reinforcement triggers.
class LeccionService {
  final Map<String, Lesson> _lessons = {};
  final Map<String, LessonProgress> _progress = {};
  bool _loaded = false;

  /// Returns true once all lesson assets have been loaded.
  bool get isLoaded => _loaded;

  /// All lesson IDs in order: M001→M002→M003, L001→L002.
  static const _allLessonIds = ['M001', 'M002', 'M003', 'L001', 'L002'];

  static const _lessonFiles = {
    'M001': 'assets/lessons/lesson_M001.json',
    'M002': 'assets/lessons/lesson_M002.json',
    'M003': 'assets/lessons/lesson_M003.json',
    'L001': 'assets/lessons/lesson_L001.json',
    'L002': 'assets/lessons/lesson_L002.json',
  };

  /// Load all 5 lesson JSON files from assets into memory.
  Future<void> cargarLecciones() async {
    if (_loaded) return;

    for (final id in _allLessonIds) {
      final path = _lessonFiles[id];
      if (path == null) continue;

      try {
        final raw = await rootBundle.loadString(path);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _lessons[id] = _parseLesson(json);
      } catch (_) {
        // Asset not available or corrupt JSON — skip
      }
    }

    _loaded = true;
  }

  /// Get a lesson by its ID (e.g. 'M001').
  Lesson? obtenerLeccion(String id) {
    return _lessons[id];
  }

  /// Get all lessons in display order.
  List<Lesson> obtenerTodas() {
    return _allLessonIds
        .where((id) => _lessons.containsKey(id))
        .map((id) => _lessons[id]!)
        .toList();
  }

  /// Get lessons for a specific subject ('matematicas' or 'lectura').
  List<Lesson> obtenerPorMateria(String materia) {
    return _allLessonIds
        .where((id) => _lessons[id]?.subject == materia)
        .map((id) => _lessons[id]!)
        .toList();
  }

  /// Get prerequisite lessons for a given lesson ID.
  List<Lesson> obtenerPrerequisitos(String lessonId) {
    final lesson = _lessons[lessonId];
    if (lesson?.prerequisites == null || lesson!.prerequisites!.isEmpty) {
      return [];
    }

    return lesson.prerequisites!
        .where((id) => _lessons.containsKey(id))
        .map((id) => _lessons[id]!)
        .toList();
  }

  // --- Progress tracking ---

  /// Get or create progress tracker for a lesson.
  LessonProgress obtenerProgreso(String lessonId) {
    return _progress.putIfAbsent(
      lessonId,
      () => LessonProgress(lessonId: lessonId),
    );
  }

  /// Record a completed exercise for a lesson.
  void marcarEjercicioCompletado(
    String lessonId,
    String exerciseId,
    ExerciseType type,
    bool isCorrect,
  ) {
    final progress = obtenerProgreso(lessonId);
    if (!progress.completedExerciseIds.contains(exerciseId)) {
      progress.completedExerciseIds.add(exerciseId);
    }

    if (!isCorrect) {
      progress.recordError(type);
    }
  }

  /// Check if an exercise has been completed.
  bool isEjercicioCompletado(String lessonId, String exerciseId) {
    final progress = _progress[lessonId];
    if (progress == null) return false;
    return progress.completedExerciseIds.contains(exerciseId);
  }

  /// Move progress to the next step.
  void avanzarPaso(String lessonId, int maxSteps) {
    final progress = _progress[lessonId];
    if (progress != null && progress.currentStep < maxSteps) {
      progress.currentStep++;
    }
  }

  /// Mark a lesson as fully completed (all exercises done).
  bool isLeccionCompletada(String lessonId) {
    final lesson = _lessons[lessonId];
    final progress = _progress[lessonId];
    if (lesson == null || progress == null) return false;
    return progress.completedExerciseIds.length >= lesson.exercises.length;
  }

  /// Check whether the reinforcement flag has been triggered.
  bool necesitaRefuerzo(String lessonId) {
    return _progress[lessonId]?.needsReinforcement ?? false;
  }

  /// Reset all in-memory progress (not persisted to DB).
  void reiniciarProgreso() {
    _progress.clear();
  }

  // --- JSON parsing ---

  Lesson _parseLesson(Map<String, dynamic> json) {
    final ejerciciosRaw = json['ejercicios'] as List<dynamic>? ?? [];
    final exercises = ejerciciosRaw
        .map((e) => _parseExercise(e as Map<String, dynamic>))
        .toList();

    // Encode the full explicacion object as explanation_json string
    final explicacion = json['explicacion'] as Map<String, dynamic>?;

    return Lesson(
      id: json['id'] as String,
      subject: json['materia'] as String? ?? 'general',
      title: json['titulo'] as String? ?? '',
      difficultyLevel: json['nivelDificultad'] as int? ?? 1,
      videoPath: json['videoPath'] as String?,
      explanationJson:
          explicacion != null ? jsonEncode(explicacion) : null,
      exercises: exercises,
      prerequisites: (json['prerequisitos'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Exercise _parseExercise(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      type: ExerciseType.fromString(json['tipo'] as String),
      enunciado: json['enunciado'] as String,
      opciones: (json['opciones'] as List<dynamic>?)
          ?.map((o) => o as String)
          .toList(),
      respuestaCorrecta: json['respuestaCorrecta'] as String,
      feedbackPorError: (json['feedbackPorError'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as String)),
    );
  }
}
