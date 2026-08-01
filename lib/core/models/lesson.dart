import 'package:flutter/foundation.dart';
import 'exercise.dart';

@immutable
class Lesson {
  final String id;
  final String subject;
  final String title;
  final int difficultyLevel;
  final String? videoPath;
  final String? explanationJson;
  final List<Exercise> exercises;
  final List<String>? prerequisites;

  const Lesson({
    required this.id,
    required this.subject,
    required this.title,
    this.difficultyLevel = 1,
    this.videoPath,
    this.explanationJson,
    this.exercises = const [],
    this.prerequisites,
  });

  Lesson copyWith({
    String? id,
    String? subject,
    String? title,
    int? difficultyLevel,
    String? videoPath,
    String? explanationJson,
    List<Exercise>? exercises,
    List<String>? prerequisites,
  }) {
    return Lesson(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      videoPath: videoPath ?? this.videoPath,
      explanationJson: explanationJson ?? this.explanationJson,
      exercises: exercises ?? this.exercises,
      prerequisites: prerequisites ?? this.prerequisites,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'title': title,
      'difficulty_level': difficultyLevel,
      'video_path': videoPath,
      'explanation_json': explanationJson,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'prerequisites': prerequisites,
    };
  }

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      subject: json['subject'] as String,
      title: json['title'] as String,
      difficultyLevel: json['difficulty_level'] as int? ?? 1,
      videoPath: json['video_path'] as String?,
      explanationJson: json['explanation_json'] as String?,
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      prerequisites: (json['prerequisites'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }
}
