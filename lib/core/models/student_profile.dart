import 'package:flutter/foundation.dart';

@immutable
class StudentProfile {
  final String id;
  final String alias;
  final DateTime diagnosticDate;
  final int mathLevel;
  final int readingLevel;
  final String? currentLesson;
  final int totalTimeMin;
  final DateTime? lastSyncTs;

  const StudentProfile({
    required this.id,
    required this.alias,
    required this.diagnosticDate,
    this.mathLevel = 1,
    this.readingLevel = 1,
    this.currentLesson,
    this.totalTimeMin = 0,
    this.lastSyncTs,
  });

  StudentProfile copyWith({
    String? id,
    String? alias,
    DateTime? diagnosticDate,
    int? mathLevel,
    int? readingLevel,
    String? currentLesson,
    int? totalTimeMin,
    DateTime? lastSyncTs,
  }) {
    return StudentProfile(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      diagnosticDate: diagnosticDate ?? this.diagnosticDate,
      mathLevel: mathLevel ?? this.mathLevel,
      readingLevel: readingLevel ?? this.readingLevel,
      currentLesson: currentLesson ?? this.currentLesson,
      totalTimeMin: totalTimeMin ?? this.totalTimeMin,
      lastSyncTs: lastSyncTs ?? this.lastSyncTs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alias': alias,
      'diagnostic_date': diagnosticDate.toIso8601String(),
      'math_level': mathLevel,
      'reading_level': readingLevel,
      'current_lesson': currentLesson,
      'total_time_min': totalTimeMin,
      'last_sync_ts': lastSyncTs?.toIso8601String(),
    };
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      alias: json['alias'] as String? ?? 'Estudiante',
      diagnosticDate: DateTime.parse(json['diagnostic_date'] as String),
      mathLevel: json['math_level'] as int? ?? 1,
      readingLevel: json['reading_level'] as int? ?? 1,
      currentLesson: json['current_lesson'] as String?,
      totalTimeMin: json['total_time_min'] as int? ?? 0,
      lastSyncTs: json['last_sync_ts'] != null
          ? DateTime.parse(json['last_sync_ts'] as String)
          : null,
    );
  }

  static StudentProfile defaultProfile(String id, String alias) {
    return StudentProfile(
      id: id,
      alias: alias,
      diagnosticDate: DateTime.now(),
    );
  }
}
