import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/learning_data.dart';
import '../../../core/state/student_state.dart';
import '../../../modules/gemma/gemma_service.dart';
import '../../../modules/gemma/model_status.dart';
import '../topic_matcher.dart';
import 'chat_screen.dart';
import 'camino_screen.dart';
import 'perfil_screen.dart';

/// Root scaffold with bottom navigation: Chat | Camino | Perfil.
/// Preserves tab state via IndexedStack. Wires ChatScreen to GemmaService.
///
/// The model status chip listens to [ModelStatusController] (fed by
/// [GemmaService]) and renders the five bootstrap states; it never shows the
/// generic "Offline" text.
///
/// Block 3: Wires [StudentState] via Provider for real topic selection,
/// BKT mastery display, agentic encouragement, off-topic redirection,
/// next-topic suggestion, and session summary tracking.
class YachayScaffold extends StatefulWidget {
  const YachayScaffold({super.key, this.gemmaService});

  /// Injectable for widget tests; production uses [GemmaService.instance].
  final GemmaService? gemmaService;

  @override
  State<YachayScaffold> createState() => _YachayScaffoldState();
}

class _YachayScaffoldState extends State<YachayScaffold> {
  int _currentIndex = 0;
  final _messages = <ChatMessage>[];
  bool _isThinking = false;
  late final GemmaService _gemmaService =
      widget.gemmaService ?? GemmaService.instance;
  late final ModelStatusController _statusController =
      _gemmaService.statusController;
  final _debugLog = <String>[];
  bool _showDebug = false;

  // ── REQ-05: Topic selection ────────────────────────────────────────────
  TemaPrimaria? _currentTopic;
  double? _masteryPercent;
  List<String>? _suggestionChips;

  // ── REQ-06: Agentic encouragement ──────────────────────────────────────
  int _consecutiveCorrect = 0;
  bool _celebrated = false;

  // ── REQ-05: Next-topic suggestion tracking ────────────────────────────
  final _masteryCelebratedFor = <String>{};

  // ── REQ-07: Session summary tracking ───────────────────────────────────
  int _messagesExchanged = 0;
  final _topicsCovered = <String>{};
  final _sessionStartTime = DateTime.now();
  SessionSummary? _sessionSummary;

  /// Cached student ID derived from [StudentState.profile].
  String get _studentId =>
      context.read<StudentState>().profile?.id ?? 'estudiante';

  void _log(String msg) {
    setState(() =>
        _debugLog.add('[${DateTime.now().toString().substring(11, 19)}] $msg'));
  }

  @override
  void initState() {
    super.initState();
    _initGemma();
    // Select the initial topic after the first frame so Provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectInitialTopic();
    });
  }

  Future<void> _initGemma() async {
    _log('Iniciando carga de Gemma...');
    try {
      final loaded = await _gemmaService.cargarModelo();
      _log('cargarModelo() retornó: $loaded');
    } catch (e) {
      _log('ERROR: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQ-05: Topic selection — first unmastered from curriculum
  // ═══════════════════════════════════════════════════════════════════════

  void _selectInitialTopic() {
    final state = context.read<StudentState>();
    final sid = state.profile?.id ?? 'estudiante';

    _currentTopic = Curricula4toPrimaria.obtenerPrimerTemaNoDominado(
      state.masteryMap,
      sid,
    );

    if (_currentTopic != null) {
      _topicsCovered.add(_currentTopic!.id);
      final key = '$sid|${_currentTopic!.id}';
      final mastery = state.masteryMap[key];
      _masteryPercent = mastery?.pLearned ?? 0.0;
      _consecutiveCorrect = mastery?.consecutiveCorrect ?? 0;
      _suggestionChips = List<String>.from(_currentTopic!.chips);
      _updateSessionSummary();
    }

    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQ-05: Chip tap handler — detects next-topic chips vs regular chips
  // ═══════════════════════════════════════════════════════════════════════

  void _handleChipTap(String label) {
    // Detect next-topic suggestion: "¿Seguimos con [titulo]?"
    final match = RegExp(r'^¿Seguimos con (.+)\?$').firstMatch(label);
    if (match != null) {
      final nextTitulo = match.group(1)!;
      final nextTopic = Curricula4toPrimaria.temas
          .where((t) => t.titulo == nextTitulo)
          .firstOrNull;
      if (nextTopic != null) {
        _switchTopic(nextTopic.id);
        return;
      }
    }
    // Regular chip — send label as a message.
    _sendMessage(label);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQ-05: Switch to a different topic (next-topic chip handler)
  // ═══════════════════════════════════════════════════════════════════════

  void _switchTopic(String topicId) {
    final next = Curricula4toPrimaria.buscarPorId(topicId);
    if (next == null) return;

    setState(() {
      _currentTopic = next;
      _topicsCovered.add(next.id);
      _consecutiveCorrect = 0;
      _celebrated = false;
      _suggestionChips = List<String>.from(next.chips);

      // Re-read mastery for the new topic
      final state = context.read<StudentState>();
      final sid = _studentId;
      final key = '$sid|${next.id}';
      final mastery = state.masteryMap[key];
      _masteryPercent = mastery?.pLearned ?? 0.0;
      _consecutiveCorrect = mastery?.consecutiveCorrect ?? 0;

      _updateSessionSummary();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final studentState = context.watch<StudentState>();
    final sid = studentState.profile?.id ?? 'estudiante';

    // Build real topic progress list from StudentState mastery data.
    final topicProgress = Curricula4toPrimaria.temas.map((t) {
      final key = '$sid|${t.id}';
      final mastery = studentState.masteryMap[key];
      return TopicProgress(
        id: t.id,
        title: t.titulo,
        masteryPercent: mastery?.pLearned ?? 0.0,
        isLocked: false,
        yachayNote: mastery?.yachayRecomendacion,
      );
    }).toList();

    // Build real student stats from StudentState.
    final profile = studentState.profile;
    final stats = StudentStats(
      name: profile?.alias ?? 'Estudiante',
      grade: '4to Primaria',
      totalTimeMinutes: profile?.totalTimeMin ?? 0,
      exercisesCompleted: studentState.totalInteractionCount,
      accuracy: studentState.accuracyRate,
      achievements: _buildAchievements(studentState),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onLongPress: () => setState(() => _showDebug = !_showDebug),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF1565C0),
                child: Text('Y',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Yachay'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ValueListenableBuilder<ModelStatusInfo>(
              valueListenable: _statusController,
              builder: (context, info, _) {
                return Chip(
                  avatar: Icon(
                    _statusIcon(info.status),
                    size: 16,
                    color: _statusColor(info.status),
                  ),
                  label: Text(info.label),
                  backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                );
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatScreen(
            messages: _messages,
            isThinking: _isThinking,
            onSend: _sendMessage,
            currentTopic: _currentTopic,
            masteryPercent: _masteryPercent,
            suggestionChips: _suggestionChips,
            sessionSummary: _sessionSummary,
            onTopicChipTap: _handleChipTap,
          ),
          CaminoScreen(topics: topicProgress),
          PerfilScreen(stats: stats),
        ],
      ),
      bottomSheet: _showDebug
          ? Container(
              height: 100,
              color: Colors.black87,
              child: ListView(
                children: _debugLog
                    .map((l) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 1),
                          child: Text(l,
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontFamily: 'monospace')),
                        ))
                    .toList(),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Camino',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // _sendMessage — wired with encouragement, off-topic, mastery tracking
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isThinking = true;
      _messagesExchanged++;
    });

    // Bootstrap: ensure the model is ready before chatting.
    if (!_gemmaService.modeloCargado) {
      await _bootstrapModel();
    }

    try {
      _log('Enviando: "$text"');
      final response = await _gemmaService.procesarMensaje(text.trim());
      _log('Respuesta (${response.length} chars): '
          '"${response.substring(0, response.length.clamp(0, 80))}"');

      // REQ-06: Check if Gemma's response indicates student got it right.
      final wasCorrect = _isEncouragingResponse(response);
      if (wasCorrect) {
        _consecutiveCorrect++;
      }

      // REQ-06: Agentic encouragement — inject celebratory prefix on streak.
      String finalResponse = response;
      if (_consecutiveCorrect >= 5 && !_celebrated) {
        final tema = _currentTopic?.titulo ?? 'el tema';
        finalResponse =
            '¡Vas muy bien! ¡$_consecutiveCorrect aciertos seguidos en '
            '$tema! 🎉\n\n$response';
        _celebrated = true;
      }

      setState(() {
        _messages.add(ChatMessage(text: finalResponse, isUser: false));
        _isThinking = false;
        _messagesExchanged++;
      });

      // REQ-05: After updating BKT in StudentState, check if topic is mastered.
      _checkMasteryCelebration();

      // Off-topic gentle redirect (REQ-04 integration).
      _checkOffTopic(text.trim());

      // REQ-07: Update session summary.
      _updateSessionSummary();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Lo siento, hubo un error. ¿Intentamos de nuevo?',
          isUser: false,
        ));
        _isThinking = false;
        _messagesExchanged++;
      });
    }
  }

  Future<void> _bootstrapModel() async {
    try {
      final ready = await _gemmaService.bootstrapModelReady();
      _log('bootstrapModelReady() retornó: $ready');
    } catch (e) {
      _log('ERROR en bootstrap: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQ-06: Encouragement detection
  // ═══════════════════════════════════════════════════════════════════════

  /// Returns `true` when the assistant's [response] contains encouragement
  /// keywords signalling the student answered correctly.
  bool _isEncouragingResponse(String response) {
    final lower = response.toLowerCase();
    return lower.contains('correcto') ||
        lower.contains('bien hecho') ||
        lower.contains('¡sumaq!') ||
        lower.contains('excelente') ||
        lower.contains('muy bien');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQ-05: Mastery celebration + next-topic suggestion
  // ═══════════════════════════════════════════════════════════════════════

  void _checkMasteryCelebration() {
    if (_currentTopic == null) return;
    if (_masteryCelebratedFor.contains(_currentTopic!.id)) return;

    final state = context.read<StudentState>();
    final sid = _studentId;
    final key = '$sid|${_currentTopic!.id}';
    final mastery = state.masteryMap[key];

    // Update displayed mastery percent.
    if (mastery != null) {
      _masteryPercent = mastery.pLearned;
    }

    if (mastery != null && mastery.pLearned >= 0.90) {
      _masteryCelebratedFor.add(_currentTopic!.id);

      final nextTopic = Curricula4toPrimaria.encontrarSiguienteTema(
        _currentTopic!.id,
      );

      if (nextTopic != null && mounted) {
        // Inject congratulatory message.
        setState(() {
          _messages.add(ChatMessage(
            text: '¡Dominaste ${_currentTopic!.titulo}! ¿Seguimos con '
                '${nextTopic.titulo}?',
            isUser: false,
          ));
          _messagesExchanged++;

          // Add the next-topic chip to suggestion chips.
          _suggestionChips = [
            ..._currentTopic!.chips,
            '¿Seguimos con ${nextTopic.titulo}?',
          ];
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Off-topic gentle redirect (REQ-04 integration)
  // ═══════════════════════════════════════════════════════════════════════

  /// Checks if [text] is off-topic and shows a gentle SnackBar redirect.
  /// Does NOT block the message — Gemma inference already completed.
  void _checkOffTopic(String text) {
    if (TopicMatcher.isOffTopic(text, Curricula4toPrimaria.temas) && mounted) {
      final currentTitle = _currentTopic?.titulo ?? 'tu estudio';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¿Seguimos practicando $currentTitle?'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Ok',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQ-07: Session summary
  // ═══════════════════════════════════════════════════════════════════════

  void _updateSessionSummary() {
    _sessionSummary = SessionSummary(
      topicsCovered: _topicsCovered.length,
      messagesExchanged: _messagesExchanged,
      timeSpent: DateTime.now().difference(_sessionStartTime),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Achievements derived from StudentState
  // ═══════════════════════════════════════════════════════════════════════

  List<Achievement> _buildAchievements(StudentState state) {
    final sid = _studentId;

    return [
      const Achievement(
          id: 'first_step', title: 'Primer Paso', isUnlocked: true),
      Achievement(
        id: 'mastered_one',
        title: '¡Dominado!',
        isUnlocked: state.masteryMap.entries
            .any((e) => e.key.startsWith('$sid|') && e.value.pLearned >= 0.90),
      ),
      Achievement(
        id: 'perfect_streak',
        title: 'Racha Perfecta',
        isUnlocked: _consecutiveCorrect >= 5,
      ),
      const Achievement(
          id: 'no_barriers', title: 'Sin Barreras', isUnlocked: false),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Status icon helpers
  // ═══════════════════════════════════════════════════════════════════════

  IconData _statusIcon(ModelStatus status) {
    switch (status) {
      case ModelStatus.ready:
        return Icons.check_circle;
      case ModelStatus.error:
        return Icons.error_outline;
      case ModelStatus.downloading:
        return Icons.downloading;
      case ModelStatus.verifying:
        return Icons.verified_outlined;
      case ModelStatus.noModel:
        return Icons.info_outline;
    }
  }

  Color _statusColor(ModelStatus status) {
    switch (status) {
      case ModelStatus.ready:
        return Colors.green;
      case ModelStatus.error:
        return Colors.red;
      case ModelStatus.downloading:
      case ModelStatus.verifying:
      case ModelStatus.noModel:
        return Colors.orange;
    }
  }
}
