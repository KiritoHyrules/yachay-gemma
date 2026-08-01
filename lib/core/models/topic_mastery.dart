import 'package:flutter/foundation.dart';

/// Per-subtopic mastery state tracked by the BKT engine.
///
/// Maps 1:1 to rows in the `student_mastery` SQLite table.
/// Serialised keys use snake_case to match DB column names.
@immutable
class TopicMastery {
  final String studentId;
  final String topicId;
  final double pLearned;
  final int attempts;
  final int correctAttempts;
  final int consecutiveCorrect;
  final DateTime? lastInteraction;
  final String? yachayRecomendacion;

  const TopicMastery({
    required this.studentId,
    required this.topicId,
    this.pLearned = 0.0,
    this.attempts = 0,
    this.correctAttempts = 0,
    this.consecutiveCorrect = 0,
    this.lastInteraction,
    this.yachayRecomendacion,
  });

  TopicMastery copyWith({
    String? studentId,
    String? topicId,
    double? pLearned,
    int? attempts,
    int? correctAttempts,
    int? consecutiveCorrect,
    DateTime? lastInteraction,
    String? yachayRecomendacion,
  }) {
    return TopicMastery(
      studentId: studentId ?? this.studentId,
      topicId: topicId ?? this.topicId,
      pLearned: pLearned ?? this.pLearned,
      attempts: attempts ?? this.attempts,
      correctAttempts: correctAttempts ?? this.correctAttempts,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      yachayRecomendacion:
          yachayRecomendacion ?? this.yachayRecomendacion,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'student_id': studentId,
      'topic_id': topicId,
      'p_learned': pLearned,
      'attempts': attempts,
      'correct_attempts': correctAttempts,
      'consecutive_correct': consecutiveCorrect,
    };

    if (lastInteraction != null) {
      map['last_interaction'] = lastInteraction!.toIso8601String();
    }
    if (yachayRecomendacion != null) {
      map['yachay_recomendacion'] = yachayRecomendacion;
    }

    return map;
  }

  factory TopicMastery.fromJson(Map<String, dynamic> json) {
    return TopicMastery(
      studentId: json['student_id'] as String,
      topicId: json['topic_id'] as String,
      pLearned: (json['p_learned'] as num?)?.toDouble() ?? 0.0,
      attempts: json['attempts'] as int? ?? 0,
      correctAttempts: json['correct_attempts'] as int? ?? 0,
      consecutiveCorrect: json['consecutive_correct'] as int? ?? 0,
      lastInteraction: json['last_interaction'] != null
          ? DateTime.parse(json['last_interaction'] as String)
          : null,
      yachayRecomendacion: json['yachay_recomendacion'] as String?,
    );
  }
}
