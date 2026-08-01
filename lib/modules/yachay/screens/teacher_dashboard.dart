import 'package:flutter/material.dart';

/// Summary of a student for the teacher dashboard.
@immutable
class TeacherStudentSummary {
  final String id;
  final String name;
  final DateTime lastActive;
  final int topicsMastered;
  final int totalTopics;
  final double accuracy;
  final String? yachayRecommendation;

  const TeacherStudentSummary({
    required this.id,
    required this.name,
    required this.lastActive,
    required this.topicsMastered,
    required this.totalTopics,
    required this.accuracy,
    this.yachayRecommendation,
  });
}

/// Teacher dashboard — read-only view of student progress from SQLite.
/// Pure presentational widget: receives data, no Gemma inference.
class TeacherDashboardScreen extends StatelessWidget {
  final List<TeacherStudentSummary> students;

  const TeacherDashboardScreen({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1565C0).withOpacity(0.05),
          child: const Text(
            'Panel del Profesor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return _StudentRow(
                student: student,
                onTap: () => _showDetailSheet(context, student),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetailSheet(BuildContext context, TeacherStudentSummary student) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _StudentDetailSheet(student: student),
    );
  }
}

/// Single row in the student list.
class _StudentRow extends StatelessWidget {
  final TeacherStudentSummary student;
  final VoidCallback onTap;

  const _StudentRow({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accuracyPercent = '${(student.accuracy * 100).round()}%';
    final masteryLabel = '${student.topicsMastered}/${student.totalTopics}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1565C0),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Activo: ${_formatDate(student.lastActive)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              masteryLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              accuracyPercent,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Bottom sheet with detailed per-student information.
class _StudentDetailSheet extends StatelessWidget {
  final TeacherStudentSummary student;

  const _StudentDetailSheet({required this.student});

  @override
  Widget build(BuildContext context) {
    final accuracyPercent = '${(student.accuracy * 100).round()}%';
    final masteryLabel = '${student.topicsMastered}/${student.totalTopics}';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF1565C0),
                child: Text('?',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$masteryLabel temas dominados · $accuracyPercent precisión',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Recomendación de Yachay',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              student.yachayRecommendation ??
                  'Yachay aún no tiene recomendaciones para este estudiante.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
