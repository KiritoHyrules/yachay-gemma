import 'package:flutter/material.dart';

/// Student statistics for the profile screen.
@immutable
class StudentStats {
  final String name;
  final String grade;
  final int totalTimeMinutes;
  final int exercisesCompleted;
  final double accuracy;
  final String? yachaySummary;
  final List<Achievement> achievements;

  const StudentStats({
    required this.name,
    required this.grade,
    required this.totalTimeMinutes,
    required this.exercisesCompleted,
    required this.accuracy,
    this.yachaySummary,
    this.achievements = const [],
  });
}

/// A single achievement — unlocked or locked.
@immutable
class Achievement {
  final String id;
  final String title;
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.isUnlocked,
  });
}

/// Student profile screen showing stats, Yachay insights, and achievements.
class PerfilScreen extends StatelessWidget {
  final StudentStats stats;

  const PerfilScreen({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar + name + grade
          _AvatarCard(stats: stats),
          const SizedBox(height: 16),
          // Stats grid
          _StatsGrid(stats: stats),
          const SizedBox(height: 16),
          // Yachay insight card
          _YachayInsightCard(summary: stats.yachaySummary),
          const SizedBox(height: 16),
          // Achievements
          _AchievementsSection(achievements: stats.achievements),
        ],
      ),
    );
  }
}

/// Top card with avatar, name, and grade.
class _AvatarCard extends StatelessWidget {
  final StudentStats stats;

  const _AvatarCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF1565C0),
              child: Text(
                stats.name.isNotEmpty ? stats.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              stats.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Chip(
              avatar: const Icon(Icons.school, size: 16),
              label: Text(stats.grade),
              backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-card grid: total time, exercises, accuracy.
class _StatsGrid extends StatelessWidget {
  final StudentStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final accuracyPercent = '${(stats.accuracy * 100).round()}%';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer,
            label: 'Tiempo total',
            value: '${stats.totalTimeMinutes} min',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.assignment,
            label: 'Ejercicios',
            value: '${stats.exercisesCompleted}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Precisión',
            value: accuracyPercent,
          ),
        ),
      ],
    );
  }
}

/// Individual stat card.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1565C0), size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Lo que Yachay sabe de vos" insight card.
class _YachayInsightCard extends StatelessWidget {
  final String? summary;

  const _YachayInsightCard({this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1565C0).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology,
                    color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Lo que Yachay sabe de vos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary ?? 'Yachay aún te está conociendo. ¡Seguí practicando!',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Achievements section: grid of achievement cards.
class _AchievementsSection extends StatelessWidget {
  final List<Achievement> achievements;

  const _AchievementsSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logros',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            final achievement = achievements[index];
            return Card(
              color: achievement.isUnlocked
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      achievement.isUnlocked
                          ? Icons.emoji_events
                          : Icons.lock_outline,
                      size: 22,
                      color: achievement.isUnlocked
                          ? Colors.amber.shade700
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: achievement.isUnlocked
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
