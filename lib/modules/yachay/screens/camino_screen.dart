import 'package:flutter/material.dart';

/// Represents one curriculum subtopic's progress for the Camino screen.
@immutable
class TopicProgress {
  final String id;
  final String title;
  final double masteryPercent;
  final bool isLocked;
  final String? yachayNote;
  final String? missingPrerequisite;

  const TopicProgress({
    required this.id,
    required this.title,
    required this.masteryPercent,
    required this.isLocked,
    this.yachayNote,
    this.missingPrerequisite,
  });
}

/// Scrollable list of topic cards showing progress across the curriculum.
class CaminoScreen extends StatelessWidget {
  final List<TopicProgress> topics;

  const CaminoScreen({super.key, required this.topics});

  @override
  Widget build(BuildContext context) {
    final sorted = List<TopicProgress>.from(topics);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Recorrido del curriculum',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: Scrollable(
            viewportBuilder: (context, position) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  return _TopicCard(topic: sorted[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Individual topic card with color-coded progress bar.
class _TopicCard extends StatelessWidget {
  final TopicProgress topic;

  const _TopicCard({required this.topic});

  Color get _barColor {
    if (topic.isLocked) return Colors.grey;
    if (topic.masteryPercent >= 0.90) return Colors.green;
    if (topic.masteryPercent >= 0.40) return Colors.amber;
    return Colors.grey.shade300; // white-ish for <40%
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('topic-card-${topic.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: topic.isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Necesitás completar: ${topic.missingPrerequisite ?? "prerrequisitos"}',
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      topic.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (topic.isLocked)
                    const Icon(Icons.lock, size: 20, color: Colors.grey)
                  else
                    Text(
                      '${(topic.masteryPercent * 100).round()}%',
                      style: TextStyle(
                        color: _barColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!topic.isLocked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: topic.masteryPercent.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0,
                    minHeight: 8,
                    backgroundColor: Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
              if (topic.yachayNote != null) ...[
                const SizedBox(height: 8),
                Text(
                  topic.yachayNote!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (topic.isLocked && topic.missingPrerequisite != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Requisito: ${topic.missingPrerequisite}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
