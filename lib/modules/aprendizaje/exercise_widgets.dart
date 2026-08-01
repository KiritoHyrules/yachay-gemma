import 'package:flutter/material.dart';

import '../../core/models/exercise.dart';

/// Result of a student's attempt on an exercise.
enum AnswerResult {
  correct,
  incorrect,
}

/// Callback signature for when a student submits an answer.
typedef OnAnswerCallback = void Function(AnswerResult result, String? selectedAnswer);

// --------------------------------------------------------------------------
// Factory
// --------------------------------------------------------------------------

/// Creates the appropriate exercise widget based on [Exercise.type].
Widget buildExerciseWidget({
  required Exercise exercise,
  required OnAnswerCallback onAnswer,
  bool showFeedback = false,
  AnswerResult? lastResult,
  String? lastSelectedAnswer,
}) {
  switch (exercise.type) {
    case ExerciseType.opcionMultiple:
      return OpcionMultipleWidget(
        exercise: exercise,
        onAnswer: onAnswer,
        showFeedback: showFeedback,
        lastResult: lastResult,
        lastSelectedAnswer: lastSelectedAnswer,
      );
    case ExerciseType.verdaderoFalso:
      return VerdaderoFalsoWidget(
        exercise: exercise,
        onAnswer: onAnswer,
        showFeedback: showFeedback,
        lastResult: lastResult,
        lastSelectedAnswer: lastSelectedAnswer,
      );
    case ExerciseType.respuestaCorta:
      return RespuestaCortaWidget(
        exercise: exercise,
        onAnswer: onAnswer,
        showFeedback: showFeedback,
        lastResult: lastResult,
        lastSelectedAnswer: lastSelectedAnswer,
      );
  }
}

// --------------------------------------------------------------------------
// OpcionMultipleWidget
// --------------------------------------------------------------------------

class OpcionMultipleWidget extends StatefulWidget {
  final Exercise exercise;
  final OnAnswerCallback onAnswer;
  final bool showFeedback;
  final AnswerResult? lastResult;
  final String? lastSelectedAnswer;

  const OpcionMultipleWidget({
    super.key,
    required this.exercise,
    required this.onAnswer,
    this.showFeedback = false,
    this.lastResult,
    this.lastSelectedAnswer,
  });

  @override
  State<OpcionMultipleWidget> createState() => _OpcionMultipleWidgetState();
}

class _OpcionMultipleWidgetState extends State<OpcionMultipleWidget> {
  String? _selected;
  bool _submitted = false;

  bool get _isCorrect =>
      _selected == widget.exercise.respuestaCorrecta;

  void _onSelect(String option) {
    if (_submitted) return;
    setState(() => _selected = option);
  }

  void _onSubmit() {
    if (_selected == null) return;
    setState(() => _submitted = true);
    widget.onAnswer(
      _isCorrect ? AnswerResult.correct : AnswerResult.incorrect,
      _selected,
    );
  }

  void _onRetry() {
    setState(() {
      _submitted = false;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = widget.exercise;
    final options = exercise.opciones ?? [];
    final correctAnswer = exercise.respuestaCorrecta;
    final feedbackMap = exercise.feedbackPorError ?? {};
    final showResult = _submitted || widget.showFeedback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Enunciado
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              exercise.enunciado,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Option buttons
        ...options.asMap().entries.map((entry) {
          final idx = entry.key;
          final option = entry.value;
          final letra = String.fromCharCode(65 + idx); // A, B, C, D
          final isSelected = _selected == option;
          final isSubmittedCorrect = showResult && option == correctAnswer;
          final isSubmittedWrong =
              showResult && isSelected && option != correctAnswer;

          Color? bgColor;
          if (isSubmittedCorrect) {
            bgColor = Colors.green.shade50;
          } else if (isSubmittedWrong) {
            bgColor = Colors.red.shade50;
          }

          IconData? trailingIcon;
          Color? iconColor;
          if (isSubmittedCorrect) {
            trailingIcon = Icons.check_circle;
            iconColor = Colors.green;
          } else if (isSubmittedWrong) {
            trailingIcon = Icons.cancel;
            iconColor = Colors.red;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: showResult ? null : () => _onSelect(option),
              style: OutlinedButton.styleFrom(
                backgroundColor: bgColor,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                alignment: Alignment.centerLeft,
                side: BorderSide(
                  color: isSelected && !showResult
                      ? theme.colorScheme.primary
                      : isSubmittedCorrect
                          ? Colors.green
                          : isSubmittedWrong
                              ? Colors.red
                              : theme.colorScheme.outline,
                  width: isSelected && !showResult ? 2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected || isSubmittedCorrect || isSubmittedWrong
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      letra,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, color: iconColor, size: 22),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        // Feedback message (only after submitting)
        if (showResult && _selected != null)
          _FeedbackCard(
            isCorrect: _isCorrect,
            selectedAnswer: _selected!,
            correctAnswer: correctAnswer,
            errorFeedback: _isCorrect ? null : feedbackMap[_selected],
            onRetry: _onRetry,
          ),

        // Submit button (only before submitting)
        if (!showResult)
          FilledButton(
            onPressed: _selected != null ? _onSubmit : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Comprobar respuesta'),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// VerdaderoFalsoWidget
// --------------------------------------------------------------------------

class VerdaderoFalsoWidget extends StatefulWidget {
  final Exercise exercise;
  final OnAnswerCallback onAnswer;
  final bool showFeedback;
  final AnswerResult? lastResult;
  final String? lastSelectedAnswer;

  const VerdaderoFalsoWidget({
    super.key,
    required this.exercise,
    required this.onAnswer,
    this.showFeedback = false,
    this.lastResult,
    this.lastSelectedAnswer,
  });

  @override
  State<VerdaderoFalsoWidget> createState() => _VerdaderoFalsoWidgetState();
}

class _VerdaderoFalsoWidgetState extends State<VerdaderoFalsoWidget> {
  String? _selected;
  bool _submitted = false;

  bool get _isCorrect =>
      _selected == widget.exercise.respuestaCorrecta;

  void _onTap(String option) {
    if (_submitted) return;
    setState(() {
      _selected = option;
      _submitted = true;
    });
    widget.onAnswer(
      _isCorrect ? AnswerResult.correct : AnswerResult.incorrect,
      _selected,
    );
  }

  void _onRetry() {
    setState(() {
      _submitted = false;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = widget.exercise;
    final feedbackMap = exercise.feedbackPorError ?? {};
    final showResult = _submitted || widget.showFeedback;
    final options = exercise.opciones ?? ['Verdadero', 'Falso'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Enunciado
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              exercise.enunciado,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Two buttons side by side
        Row(
          children: options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isSelected = _selected == option;
            final isCorrectOption = option == exercise.respuestaCorrecta;
            final isSubmittedCorrect = showResult && isCorrectOption;
            final isSubmittedWrong =
                showResult && isSelected && !isCorrectOption;

            Color? bgColor;
            Color? fgColor;
            if (isSubmittedCorrect) {
              bgColor = Colors.green.shade50;
              fgColor = Colors.green.shade700;
            } else if (isSubmittedWrong) {
              bgColor = Colors.red.shade50;
              fgColor = Colors.red.shade700;
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: idx == 0 ? 0 : 8,
                  right: idx == options.length - 1 ? 0 : 8,
                ),
                child: OutlinedButton(
                  onPressed: showResult ? null : () => _onTap(option),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: bgColor,
                    foregroundColor: fgColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    side: BorderSide(
                      color: isSelected && !showResult
                          ? theme.colorScheme.primary
                          : isSubmittedCorrect
                              ? Colors.green
                              : isSubmittedWrong
                                  ? Colors.red
                                  : theme.colorScheme.outline,
                      width: isSelected && !showResult ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isSubmittedCorrect
                            ? Icons.check_circle
                            : isSubmittedWrong
                                ? Icons.cancel
                                : option == 'Verdadero'
                                    ? Icons.check
                                    : Icons.close,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // Feedback message
        if (showResult && _selected != null)
          _FeedbackCard(
            isCorrect: _isCorrect,
            selectedAnswer: _selected!,
            correctAnswer: exercise.respuestaCorrecta,
            errorFeedback: _isCorrect ? null : feedbackMap[_selected],
            onRetry: _onRetry,
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// RespuestaCortaWidget
// --------------------------------------------------------------------------

class RespuestaCortaWidget extends StatefulWidget {
  final Exercise exercise;
  final OnAnswerCallback onAnswer;
  final bool showFeedback;
  final AnswerResult? lastResult;
  final String? lastSelectedAnswer;

  const RespuestaCortaWidget({
    super.key,
    required this.exercise,
    required this.onAnswer,
    this.showFeedback = false,
    this.lastResult,
    this.lastSelectedAnswer,
  });

  @override
  State<RespuestaCortaWidget> createState() => _RespuestaCortaWidgetState();
}

class _RespuestaCortaWidgetState extends State<RespuestaCortaWidget> {
  final _controller = TextEditingController();
  bool _submitted = false;
  String? _userAnswer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isCorrect {
    if (_userAnswer == null) return false;
    return _userAnswer!
        .trim()
        .toLowerCase()
        .contains(widget.exercise.respuestaCorrecta.trim().toLowerCase());
  }

  void _onSubmit() {
    final answer = _controller.text.trim();
    if (answer.isEmpty) return;

    setState(() {
      _submitted = true;
      _userAnswer = answer;
    });
    widget.onAnswer(
      _isCorrect ? AnswerResult.correct : AnswerResult.incorrect,
      answer,
    );
  }

  void _onRetry() {
    setState(() {
      _submitted = false;
      _userAnswer = null;
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = widget.exercise;
    final feedbackMap = exercise.feedbackPorError ?? {};
    final showResult = _submitted || widget.showFeedback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Enunciado
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              exercise.enunciado,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Text input
        TextField(
          controller: _controller,
          enabled: !showResult,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Escribe tu respuesta aqui',
            suffixIcon: showResult
                ? Icon(
                    _isCorrect ? Icons.check_circle : Icons.cancel,
                    color: _isCorrect ? Colors.green : Colors.red,
                  )
                : null,
          ),
          onSubmitted: showResult ? null : (_) => _onSubmit(),
        ),
        const SizedBox(height: 12),

        // Submit button
        if (!showResult)
          FilledButton(
            onPressed: _controller.text.trim().isNotEmpty ? _onSubmit : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Comprobar respuesta'),
          ),

        // Feedback message
        if (showResult && _userAnswer != null)
          _FeedbackCard(
            isCorrect: _isCorrect,
            selectedAnswer: _userAnswer!,
            correctAnswer: exercise.respuestaCorrecta,
            errorFeedback: _isCorrect ? null : _findBestFeedback(_userAnswer!, feedbackMap),
            onRetry: _onRetry,
          ),
      ],
    );
  }

  String? _findBestFeedback(String answer, Map<String, String> feedbackMap) {
    // Direct match first
    if (feedbackMap.containsKey(answer)) return feedbackMap[answer];
    // Try normalized
    final normalized = answer.trim().toLowerCase();
    for (final entry in feedbackMap.entries) {
      if (entry.key.trim().toLowerCase() == normalized) return entry.value;
    }
    // Return first available (generic)
    if (feedbackMap.isNotEmpty) return feedbackMap.values.first;
    return null;
  }
}

// --------------------------------------------------------------------------
// _FeedbackCard — shared between all exercise widgets
// --------------------------------------------------------------------------

class _FeedbackCard extends StatelessWidget {
  final bool isCorrect;
  final String selectedAnswer;
  final String correctAnswer;
  final String? errorFeedback;
  final VoidCallback onRetry;

  const _FeedbackCard({
    required this.isCorrect,
    required this.selectedAnswer,
    required this.correctAnswer,
    this.errorFeedback,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.info_outline,
                  color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCorrect
                        ? 'Correcto'
                        : 'Sigue intentando',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isCorrect
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (!isCorrect && errorFeedback != null) ...[
              const SizedBox(height: 8),
              Text(
                errorFeedback!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.red.shade800,
                  height: 1.4,
                ),
              ),
            ],
            if (isCorrect) ...[
              const SizedBox(height: 4),
              Text(
                'Sigue asi, vas muy bien.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Intentar de nuevo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
