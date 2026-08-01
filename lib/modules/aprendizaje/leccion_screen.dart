import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/lesson.dart';
import '../../core/models/exercise.dart';
import '../../core/state/student_state.dart';
import '../gemma/gemma_service.dart';
import 'leccion_service.dart';
import 'exercise_widgets.dart';

/// Interactive lesson screen.
///
/// Renders a scrollable sequence of:
///   1. Video placeholder card
///   2. Collapsible explanation steps
///   3. Interactive exercise widgets with feedback
///   4. Progress indicator (ejercicio X/Y)
///   5. "?" help button (stub → GemmaService in Phase 4)
class LeccionScreen extends StatefulWidget {
  final String lessonId;

  const LeccionScreen({super.key, required this.lessonId});

  @override
  State<LeccionScreen> createState() => _LeccionScreenState();
}

class _LeccionScreenState extends State<LeccionScreen> {
  late final LeccionService _service;

  Lesson? _lesson;
  LessonProgress? _progress;
  bool _loading = true;

  // Current exercise index within the lesson's exercise list (-1 → explanation)
  int _currentExerciseIndex = -1;

  // Feedback state for the current exercise
  AnswerResult? _lastResult;
  String? _lastSelectedAnswer;
  bool _canRetry = false;

  // Collapsible explanation state
  final Set<int> _expandedSteps = {};

  // Reinforcement state
  bool _showReinforcement = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<LeccionService>();
    _cargar();
  }

  Future<void> _cargar() async {
    final lesson = _service.obtenerLeccion(widget.lessonId);

    if (mounted) {
      setState(() {
        _lesson = lesson;
        _loading = lesson == null;
      });

      if (lesson != null) {
        _progress = _service.obtenerProgreso(widget.lessonId);
        final studentState = context.read<StudentState>();
        studentState.setCurrentLesson(lesson);

        // Resume from last completed exercise
        final completedCount = _progress!.completedExerciseIds.length;
        _currentExerciseIndex = completedCount > 0 ? completedCount - 1 : -1;

        // Check reinforcement
        _showReinforcement = _service.necesitaRefuerzo(widget.lessonId);

        setState(() {});
      }
    }
  }

  int get _totalSteps {
    if (_lesson == null) return 0;
    // 1 (explanation) + exercises
    return 1 + _lesson!.exercises.length;
  }

  int get _currentStepDisplay {
    // -1 = explanation step, otherwise exercise index
    if (_currentExerciseIndex < 0) return 0;
    return _currentExerciseIndex + 1;
  }

  Exercise? get _currentExercise {
    if (_lesson == null || _currentExerciseIndex < 0) return null;
    if (_currentExerciseIndex >= _lesson!.exercises.length) return null;
    return _lesson!.exercises[_currentExerciseIndex];
  }

  void _onAnswer(AnswerResult result, String? selectedAnswer) {
    final exercise = _currentExercise;
    if (exercise == null) return;

    setState(() {
      _lastResult = result;
      _lastSelectedAnswer = selectedAnswer;
      _canRetry = true;
    });

    // Track in service
    _service.marcarEjercicioCompletado(
      widget.lessonId,
      exercise.id,
      exercise.type,
      result == AnswerResult.correct,
    );

    // Record interaction in state
    context.read<StudentState>().recordInteraction(
          isCorrect: result == AnswerResult.correct,
        );

    // Check reinforcement trigger
    if (_service.necesitaRefuerzo(widget.lessonId)) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showReinforcement = true);
        }
      });
    }
  }

  void _goToNext() {
    final lesson = _lesson;
    if (lesson == null) return;

    if (_currentExerciseIndex + 1 >= lesson.exercises.length) {
      _showCompletion();
      return;
    }

    setState(() {
      _currentExerciseIndex++;
      _lastResult = null;
      _lastSelectedAnswer = null;
      _canRetry = false;
    });
    _service.avanzarPaso(widget.lessonId, lesson.exercises.length);
  }

  void _showCompletion() {
    final studentState = context.read<StudentState>();
    studentState.markLessonCompleted(widget.lessonId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Leccion completada'),
        content: const Text(
          'Has terminado todos los ejercicios de esta leccion. '
          'Sigue practicando para reforzar lo aprendido.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // back to ruta
            },
            child: const Text('Volver a la ruta'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelp() async {
    final lesson = _lesson;
    if (lesson == null) return;

    // Map lesson ID to Gemma topic key
    final tema = '${lesson.id}_${lesson.subject}_${_topicKeyForId(lesson.id)}';

    // Show loading bottom sheet first
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _buildLoadingSheet(ctx),
    );

    // Attempt to get explanation from GemmaService
    final gemmaService = context.read<GemmaService>();
    final nivel = lesson.difficultyLevel.toString();

    String explanation;
    try {
      explanation = await gemmaService.generarExplicacion(
        tema,
        nivel: nivel,
        explicacionOriginal: _extractLessonSummary(),
      );
    } catch (_) {
      explanation = 'Vamos a repasar juntos. '
          'Lee la explicacion de la leccion con calma. '
          'Identifica la parte que no entendiste y vuelve a preguntar. '
          'Equivocarse es parte del aprendizaje. Sigue practicando.';
    }

    // Close loading sheet
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Show result in a new bottom sheet
    if (mounted) {
      _showHelpResult(explanation);
    }
  }

  Widget _buildLoadingSheet(BuildContext ctx) {
    final theme = Theme.of(ctx);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Preparando tu ayuda...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Un momento, tu tutor virtual esta buscando '
            'la mejor forma de explicarte.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showHelpResult(String explanation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        size: 28,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ayuda personalizada',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Explanation content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Card(
                        color: theme.colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            explanation,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          // Allow re-tapping help
                        },
                        child: const Text('Cerrar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          // Request reinforcement exercises
                          final gemmaService = context.read<GemmaService>();
                          final lesson = _lesson;
                          if (lesson == null) return;

                          final tema = '${lesson.id}_${lesson.subject}_${_topicKeyForId(lesson.id)}';
                          final ejercicios =
                              await gemmaService.generarEjerciciosRefuerzo(
                            tema,
                            nivel: lesson.difficultyLevel.toString(),
                          );

                          if (mounted) {
                            _showReinforcementExercises(ejercicios);
                          }
                        },
                        icon: const Icon(Icons.fitness_center, size: 18),
                        label: const Text('Practicar mas'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReinforcementExercises(List<Map<String, dynamic>> ejercicios) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 28,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ejercicios de refuerzo',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: ejercicios.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final ej = ejercicios[index];
                        final enunciado = ej['enunciado'] as String? ?? '';
                        final opciones =
                            (ej['opciones'] as List<dynamic>?)?.cast<String>() ??
                                [];
                        final correcta =
                            ej['respuestaCorrecta'] as String? ?? '';

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${index + 1}. $enunciado',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                if (opciones.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ...opciones.map((op) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                              op == correcta
                                                  ? Icons.check_circle_outline
                                                  : Icons.radio_button_unchecked,
                                              size: 20,
                                              color: op == correcta
                                                  ? Colors.green.shade600
                                                  : theme.colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                op,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontWeight: op == correcta
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: op == correcta
                                                      ? Colors.green.shade700
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Listo'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Maps a lesson ID like "M001" to a human-readable topic key
  /// for the fallback responses JSON.
  String _topicKeyForId(String id) {
    switch (id) {
      case 'M001':
        return 'fracciones';
      case 'M002':
        return 'ecuaciones';
      case 'M003':
        return 'porcentajes';
      case 'L001':
        return 'comprension';
      case 'L002':
        return 'inferencias';
      default:
        return id.toLowerCase();
    }
  }

  /// Extracts a short text summary of the lesson explanation for
  /// the AI prompt context.
  String _extractLessonSummary() {
    if (_lesson?.explanationJson == null) return '';
    try {
      final data = jsonDecode(_lesson!.explanationJson!) as Map<String, dynamic>;
      return data['resumen'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leccion')),
        body: const Center(child: Text('Leccion no encontrada')),
      );
    }

    final lesson = _lesson!;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ayuda con IA',
            onPressed: _showHelp,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar at top
          if (_totalSteps > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_currentStepDisplay + 1) / _totalSteps,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentStepDisplay + 1} de $_totalSteps',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Video placeholder
                  _buildVideoPlaceholder(theme, lesson),

                  const SizedBox(height: 20),

                  // Explanation section (collapsible)
                  _buildExplanation(theme, lesson),

                  const SizedBox(height: 24),

                  // Reinforcement card (if triggered)
                  if (_showReinforcement) ...[
                    _buildReinforcementCard(theme),
                    const SizedBox(height: 16),
                  ],

                  // Divider before exercises
                  const Divider(),
                  const SizedBox(height: 12),

                  // Section header for exercises
                  Text(
                    'Ejercicio ${_currentExerciseIndex + 2} de ${lesson.exercises.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Current exercise
                  if (_currentExercise != null)
                    _buildCurrentExercise(theme, _currentExercise!)
                  else
                    _buildStartExercisesButton(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder(ThemeData theme, Lesson lesson) {
    return Card(
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 56,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Video explicativo',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Disponible en la proxima actualizacion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanation(ThemeData theme, Lesson lesson) {
    Map<String, dynamic>? explicacion;
    if (lesson.explanationJson != null) {
      try {
        explicacion = jsonDecode(lesson.explanationJson!)
            as Map<String, dynamic>;
      } catch (_) {}
    }

    if (explicacion == null) {
      return const SizedBox.shrink();
    }

    final resumen = explicacion['resumen'] as String? ?? '';
    final pasos =
        (explicacion['pasos'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    final ejemploResuelto =
        explicacion['ejemploResuelto'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          'Explicacion',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Resumen
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              resumen,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Collapsible steps
        ...pasos.asMap().entries.map((entry) {
          final idx = entry.key;
          final paso = entry.value;
          final isExpanded = _expandedSteps.contains(idx);
          final titulo = paso['titulo'] as String? ?? 'Paso ${idx + 1}';
          final contenido = paso['contenido'] as String? ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedSteps.remove(idx);
                      } else {
                        _expandedSteps.add(idx);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${idx + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            titulo,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      contenido,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),

        // Ejemplo resuelto
        if (ejemploResuelto != null) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ejemplo resuelto',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (ejemploResuelto['enunciado'] != null)
                    Text(
                      ejemploResuelto['enunciado'] as String,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (ejemploResuelto['solucion'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      ejemploResuelto['solucion'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReinforcementCard(ThemeData theme) {
    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Refuerzo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Has encontrado algunas dificultades con este tipo de ejercicios. '
              'No te preocupes, es parte del aprendizaje. Aqui tienes un recordatorio '
              'para ayudarte a seguir avanzando.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.amber.shade900,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentExercise(ThemeData theme, Exercise exercise) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildExerciseWidget(
          exercise: exercise,
          onAnswer: _onAnswer,
          showFeedback: _canRetry,
          lastResult: _lastResult,
          lastSelectedAnswer: _lastSelectedAnswer,
        ),
        const SizedBox(height: 20),

        // Next / back buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_currentExerciseIndex > 0)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentExerciseIndex--;
                    _lastResult = null;
                    _lastSelectedAnswer = null;
                    _canRetry = false;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Anterior'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _canRetry ? _goToNext : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                _currentExerciseIndex + 1 >= (_lesson?.exercises.length ?? 0)
                    ? 'Finalizar'
                    : 'Siguiente',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartExercisesButton(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.edit_note,
            size: 48,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Revisa la explicacion y cuando estes listo, empieza los ejercicios.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _currentExerciseIndex = 0;
                _lastResult = null;
                _lastSelectedAnswer = null;
                _canRetry = false;
              });
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Empezar ejercicios'),
          ),
        ],
      ),
    );
  }
}
