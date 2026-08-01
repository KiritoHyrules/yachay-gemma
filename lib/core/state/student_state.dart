import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/student_profile.dart';
import '../models/diagnostic_result.dart';
import '../models/lesson.dart';
import '../models/topic_mastery.dart';
import '../database/database_service.dart';
import '../database/repositories/student_repository.dart';
import '../database/repositories/lesson_repository.dart';
import '../../modules/yachay/bkt_engine.dart';

class StudentState extends ChangeNotifier {
  final DatabaseService _dbService;

  StudentProfile? _profile;
  DiagnosticResult? _diagnosticResult;
  Lesson? _currentLesson;
  double _overallProgress = 0.0;
  List<String> _completedLessons = [];
  int _totalInteractionCount = 0;
  int _correctInteractionCount = 0;

  final Map<String, TopicMastery> _masteryMap = {};

  StudentState(this._dbService);

  // Getters
  StudentProfile? get profile => _profile;
  DiagnosticResult? get diagnosticResult => _diagnosticResult;
  Lesson? get currentLesson => _currentLesson;
  double get overallProgress => _overallProgress;
  List<String> get completedLessons => List.unmodifiable(_completedLessons);
  int get totalInteractionCount => _totalInteractionCount;
  int get correctInteractionCount => _correctInteractionCount;

  /// Per-topic mastery state keyed by `$studentId|$topicId`.
  Map<String, TopicMastery> get masteryMap =>
      Map.unmodifiable(_masteryMap);

  /// TEST ONLY: directly set a mastery entry for testing purposes.
  /// Do NOT use in production code — use [actualizarMastery] instead.
  @visibleForTesting
  void setMasteryForTest(TopicMastery mastery) {
    final key = '${mastery.studentId}|${mastery.topicId}';
    _masteryMap[key] = mastery;
  }

  double get accuracyRate {
    if (_totalInteractionCount == 0) return 0.0;
    return _correctInteractionCount / _totalInteractionCount;
  }

  bool get hasCompletedDiagnostic => _profile != null && _diagnosticResult != null;

  late final StudentRepository studentRepo = StudentRepository(_dbService);
  late final LessonRepository lessonRepo = LessonRepository(_dbService);

  Future<void> initialize(String studentId, String alias) async {
    await _dbService.initialize();

    var profile = await studentRepo.loadProfile(studentId);
    profile ??= StudentProfile.defaultProfile(studentId, alias);

    await studentRepo.saveProfile(profile);
    _profile = profile;

    if (profile.mathLevel > 1 || profile.readingLevel > 1) {
      final nivel = (profile.mathLevel + profile.readingLevel) ~/ 2;
      _diagnosticResult = DiagnosticResult(
        nivel: nivel,
        etiqueta: DiagnosticResult.etiquetaParaNivel(nivel),
        theta: 0.0,
        precision: 0.3,
        itemsAdministrados: 0,
      );
    }

    await _loadProgress();
    notifyListeners();
  }

  Future<void> updateDiagnostic(DiagnosticResult result) async {
    _diagnosticResult = result;

    if (_profile != null) {
      await studentRepo.updateDiagnosticResult(_profile!.id, result);
      await studentRepo.updateMathLevel(_profile!.id, result.nivel);
      await studentRepo.updateReadingLevel(_profile!.id, result.nivel);
    }

    notifyListeners();
  }

  Future<void> setCurrentLesson(Lesson lesson) async {
    _currentLesson = lesson;

    if (_profile != null) {
      await studentRepo.updateCurrentLesson(_profile!.id, lesson.id);
    }

    notifyListeners();
  }

  Future<void> markLessonCompleted(String lessonId) async {
    if (!_completedLessons.contains(lessonId)) {
      _completedLessons.add(lessonId);
      await _recalculateProgress();
      notifyListeners();
    }
  }

  void recordInteraction({required bool isCorrect}) {
    _totalInteractionCount++;
    if (isCorrect) {
      _correctInteractionCount++;
    }
    notifyListeners();
  }

  Future<void> addTimeSpent(int minutes) async {
    if (_profile != null) {
      await studentRepo.updateTotalTime(_profile!.id, minutes);
      _profile = _profile!.copyWith(
        totalTimeMin: _profile!.totalTimeMin + minutes,
      );
      notifyListeners();
    }
  }

  Future<void> _loadProgress() async {
    final lessons = await lessonRepo.getAllLessons();
    final totalLessons = lessons.length;

    _overallProgress = totalLessons > 0
        ? _completedLessons.length / totalLessons
        : 0.0;
  }

  Future<void> _recalculateProgress() async {
    final lessons = await lessonRepo.getAllLessons();
    final totalLessons = lessons.length;

    _overallProgress = totalLessons > 0
        ? _completedLessons.length / totalLessons
        : 0.0;
  }

  void updateProfile({String? alias}) {
    if (_profile != null && alias != null) {
      _profile = _profile!.copyWith(alias: alias);
      studentRepo.saveProfile(_profile!);
      notifyListeners();
    }
  }

  /// Loads persisted mastery state from `student_mastery` for [studentId].
  ///
  /// Populates the in-memory [_masteryMap]. Gracefully handles the case
  /// where the database is not yet initialised.
  Future<void> cargarMastery(String studentId) async {
    final db = _dbService.database;
    if (db == null) return;

    final rows = await db.query(
      'student_mastery',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );

    _masteryMap.clear();
    for (final row in rows) {
      final mastery = TopicMastery.fromJson(row);
      final key = '${mastery.studentId}|${mastery.topicId}';
      _masteryMap[key] = mastery;
    }
    notifyListeners();
  }

  /// Updates mastery for [topicId] after [correct] answer, persists to DB,
  /// and notifies listeners.
  ///
  /// Uses [BktEngine] to compute the new P(L). The map key is
  /// `$studentId|$topicId`.
  Future<void> actualizarMastery(
    String studentId,
    String topicId,
    bool correct,
  ) async {
    final key = '$studentId|$topicId';
    final existing = _masteryMap[key];

    final currentPL = existing?.pLearned ?? BktEngine.pLearn0;
    final newPL = BktEngine.updatePLearned(currentPL, correct);

    final mastery = TopicMastery(
      studentId: studentId,
      topicId: topicId,
      pLearned: newPL,
      attempts: (existing?.attempts ?? 0) + 1,
      correctAttempts:
          (existing?.correctAttempts ?? 0) + (correct ? 1 : 0),
      consecutiveCorrect:
          correct ? (existing?.consecutiveCorrect ?? 0) + 1 : 0,
      lastInteraction: DateTime.now(),
      yachayRecomendacion: existing?.yachayRecomendacion,
    );

    _masteryMap[key] = mastery;

    // Persist to DB
    final db = _dbService.database;
    if (db != null) {
      await db.insert(
        'student_mastery',
        mastery.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    notifyListeners();
  }
}
