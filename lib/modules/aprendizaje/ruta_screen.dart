import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/student_state.dart';
import 'leccion_service.dart';
import 'leccion_screen.dart';

/// Learning path screen.
///
/// Displays the 5 available lessons as an ordered list with:
///   - Title, difficulty stars, and completion status
///   - Sequential unlock: lesson N only available after completing N-1
///   - Student level badge at top
///   - Tap → navigate to LeccionScreen
class RutaScreen extends StatefulWidget {
  const RutaScreen({super.key});

  @override
  State<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends State<RutaScreen> {
  late final LeccionService _service;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = context.read<LeccionService>();
    _cargar();
  }

  Future<void> _cargar() async {
    await _service.cargarLecciones();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _abrirLeccion(String lessonId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeccionScreen(lessonId: lessonId),
      ),
    );
  }

  String _badgeLabel(StudentState state) {
    final nivel = state.diagnosticResult?.nivel ?? 1;

    final etiquetas = {
      1: 'Explorador',
      2: 'Aprendiz',
      3: 'Practicante',
      4: 'Aventurero',
      5: 'Experto',
    };

    final materia =
        state.diagnosticResult?.nivel == null ? 'en general' : _materiaActual(state);

    return 'Eres ${etiquetas[nivel] ?? 'Estudiante'} $materia';
  }

  String _materiaActual(StudentState state) {
    final profile = state.profile;
    if (profile == null) return 'en general';
    if (profile.mathLevel >= profile.readingLevel) {
      return 'en Matematica';
    }
    return 'en Lectura';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentState = context.watch<StudentState>();

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruta de aprendizaje')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lessons = _service.obtenerTodas();
    final completedIds = studentState.completedLessons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta de aprendizaje'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Level badge card
            _buildBadgeCard(theme, studentState),
            const SizedBox(height: 24),

            // Section header
            Text(
              'Tus lecciones',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completa cada leccion para desbloquear la siguiente.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Lesson list
            if (lessons.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No hay lecciones disponibles. Completa el diagnostico '
                    'para recibir tu ruta personalizada.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...lessons.asMap().entries.map((entry) {
                final idx = entry.key;
                final lesson = entry.value;
                return _buildLessonCard(
                  theme,
                  lesson: lesson,
                  index: idx,
                  isLocked: _isLocked(idx, lessons, completedIds),
                  isCompleted: completedIds.contains(lesson.id),
                  isInProgress: _isInProgress(idx, lessons, completedIds),
                  onTap: () => _abrirLeccion(lesson.id),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(ThemeData theme, StudentState state) {
    final nivel = state.diagnosticResult?.nivel ?? 1;

    final iconos = {
      1: Icons.explore,
      2: Icons.school,
      3: Icons.engineering,
      4: Icons.rocket_launch,
      5: Icons.auto_awesome,
    };

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              iconos[nivel] ?? Icons.school,
              size: 44,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _badgeLabel(state),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nivel ${nivel} de 5',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(
    ThemeData theme, {
    required dynamic lesson,
    required int index,
    required bool isLocked,
    required bool isCompleted,
    required bool isInProgress,
    required VoidCallback onTap,
  }) {
    final materia = lesson.subject == 'matematicas' ? 'Matematica' : 'Lectura';
    final materiaIcon =
        lesson.subject == 'matematicas' ? Icons.calculate : Icons.menu_book;

    // Status
    final (statusLabel, statusColor, statusIcon) = isCompleted
        ? ('Completada', Colors.green, Icons.check_circle)
        : isInProgress
            ? ('En progreso', Colors.orange, Icons.play_circle)
            : isLocked
                ? ('Bloqueada', theme.colorScheme.outline, Icons.lock)
                : ('Pendiente', theme.colorScheme.onSurfaceVariant, Icons.radio_button_unchecked);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isLocked ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  // Number badge
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isCompleted
                        ? Colors.green.shade100
                        : isInProgress
                            ? Colors.orange.shade100
                            : isLocked
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.primaryContainer,
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: Colors.green.shade700)
                        : isLocked
                            ? Icon(Icons.lock, size: 16, color: theme.colorScheme.outline)
                            : Text(
                                '${index + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isInProgress
                                      ? Colors.orange.shade700
                                      : theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lesson.title as String,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isLocked
                            ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Metadata row
              Row(
                children: [
                  // Subject chip
                  Chip(
                    avatar: Icon(materiaIcon, size: 16),
                    label: Text(
                      materia,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),

                  // Difficulty stars
                  ...List.generate(5, (i) {
                    return Icon(
                      i < (lesson.difficultyLevel as int)
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: i < (lesson.difficultyLevel as int)
                          ? Colors.amber
                          : theme.colorScheme.outline.withOpacity(0.4),
                    );
                  }),

                  const Spacer(),

                  // Status
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Lesson ordering / unlock logic ---

  /// Lesson N is locked if any previous lesson is not completed.
  bool _isLocked(int index, List lessons, List<String> completedIds) {
    if (index == 0) return false; // first lesson is always unlocked
    for (int i = 0; i < index; i++) {
      final prevId = (lessons[i] as dynamic).id as String;
      if (!completedIds.contains(prevId)) return true;
    }
    return false;
  }

  /// Lesson is "in progress" if it's unlocked and not completed.
  bool _isInProgress(int index, List lessons, List<String> completedIds) {
    if (completedIds.contains((lessons[index] as dynamic).id as String)) {
      return false;
    }
    return !_isLocked(index, lessons, completedIds);
  }
}
