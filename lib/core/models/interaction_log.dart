import 'package:flutter/foundation.dart';

enum SyncStatus { pending, synced }

@immutable
class InteractionLog {
  final int? id;
  final String lessonId;
  final String exerciseId;
  final String response;
  final bool isCorrect;
  final String? errorType;
  final int timeSpentSec;
  final bool gemmaUsed;
  final DateTime timestamp;
  final SyncStatus syncStatus;

  const InteractionLog({
    this.id,
    required this.lessonId,
    required this.exerciseId,
    required this.response,
    required this.isCorrect,
    this.errorType,
    required this.timeSpentSec,
    this.gemmaUsed = false,
    required this.timestamp,
    this.syncStatus = SyncStatus.pending,
  });

  InteractionLog copyWith({
    int? id,
    String? lessonId,
    String? exerciseId,
    String? response,
    bool? isCorrect,
    String? errorType,
    int? timeSpentSec,
    bool? gemmaUsed,
    DateTime? timestamp,
    SyncStatus? syncStatus,
  }) {
    return InteractionLog(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      exerciseId: exerciseId ?? this.exerciseId,
      response: response ?? this.response,
      isCorrect: isCorrect ?? this.isCorrect,
      errorType: errorType ?? this.errorType,
      timeSpentSec: timeSpentSec ?? this.timeSpentSec,
      gemmaUsed: gemmaUsed ?? this.gemmaUsed,
      timestamp: timestamp ?? this.timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'lesson_id': lessonId,
      'exercise_id': exerciseId,
      'response': response,
      'is_correct': isCorrect ? 1 : 0,
      'error_type': errorType,
      'time_spent_sec': timeSpentSec,
      'gemma_used': gemmaUsed ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory InteractionLog.fromJson(Map<String, dynamic> json) {
    return InteractionLog(
      id: json['id'] as int?,
      lessonId: json['lesson_id'] as String,
      exerciseId: json['exercise_id'] as String,
      response: json['response'] as String,
      isCorrect: (json['is_correct'] as int) == 1,
      errorType: json['error_type'] as String?,
      timeSpentSec: json['time_spent_sec'] as int,
      gemmaUsed: (json['gemma_used'] as int?) == 1,
      timestamp: DateTime.parse(json['timestamp'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
