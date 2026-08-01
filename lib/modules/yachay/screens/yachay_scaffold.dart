import 'package:flutter/material.dart';

import '../../../core/data/learning_data.dart';
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

  /// Curriculum topics for off-topic detection.
  /// Placeholder first topic used until Block 3 wires dynamic topic selection.
  static const _curriculumTopics = Curricula4toPrimaria.temas;
  static final _placeholderTopic =
      _curriculumTopics.isNotEmpty ? _curriculumTopics.first : null;

  void _log(String msg) {
    setState(() =>
        _debugLog.add('[${DateTime.now().toString().substring(11, 19)}] $msg'));
  }

  @override
  void initState() {
    super.initState();
    _initGemma();
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

  // Sample curriculum data for the Camino screen.
  static final _sampleTopics = [
    const TopicProgress(
      id: 'arit_nn_01a',
      title: 'Valor Posicional',
      masteryPercent: 0.95,
      isLocked: false,
      yachayNote: '¡Muy bien!',
    ),
    const TopicProgress(
      id: 'arit_nn_01b',
      title: 'Lectura y Escritura',
      masteryPercent: 0.60,
      isLocked: false,
      yachayNote: 'Vas por buen camino',
    ),
    const TopicProgress(
      id: 'arit_nn_02a',
      title: 'Suma sin llevar',
      masteryPercent: 0.10,
      isLocked: false,
      yachayNote: null,
    ),
    const TopicProgress(
      id: 'arit_of_01',
      title: 'Operaciones Combinadas',
      masteryPercent: 0.0,
      isLocked: true,
      missingPrerequisite: 'Suma sin llevar',
    ),
  ];

  // Sample student stats for the Perfil screen.
  static final _sampleStats = StudentStats(
    name: 'Estudiante',
    grade: '1° Sec',
    totalTimeMinutes: 45,
    exercisesCompleted: 20,
    accuracy: 0.75,
    yachaySummary: null,
    achievements: const [
      Achievement(id: 'first_step', title: 'Primer Paso', isUnlocked: true),
      Achievement(id: 'mastered_one', title: '¡Dominado!', isUnlocked: false),
      Achievement(
          id: 'perfect_streak', title: 'Racha Perfecta', isUnlocked: false),
      Achievement(id: 'no_barriers', title: 'Sin Barreras', isUnlocked: false),
    ],
  );

  @override
  Widget build(BuildContext context) {
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
          ),
          CaminoScreen(topics: _sampleTopics),
          PerfilScreen(stats: _sampleStats),
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isThinking = true;
    });

    // Bootstrap: ensure the model is ready before chatting. The whole flow is
    // bounded by a timeout inside GemmaService so a missing or blocked
    // download can never deadlock the UI; on failure the app keeps operating
    // in degraded (no-AI) mode via FallbackDispatcher.
    if (!_gemmaService.modeloCargado) {
      await _bootstrapModel();
    }

    try {
      _log('Enviando: "$text"');
      final response = await _gemmaService.procesarMensaje(text.trim());
      _log(
          'Respuesta (${response.length} chars): "${response.substring(0, response.length.clamp(0, 80))}"');
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isThinking = false;
      });

      // Off-topic detection: show a gentle redirect hint if the message
      // doesn't match any curriculum topic. Does NOT block the message.
      _checkOffTopic(text.trim());
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Lo siento, hubo un error. ¿Intentamos de nuevo?',
          isUser: false,
        ));
        _isThinking = false;
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

  /// Checks if [text] is off-topic and shows a gentle SnackBar redirect.
  /// Does NOT block the message — Gemma inference already completed.
  void _checkOffTopic(String text) {
    if (TopicMatcher.isOffTopic(text, _curriculumTopics) && mounted) {
      final currentTitle = _placeholderTopic?.titulo ?? 'tu estudio';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¿Seguimos con $currentTitle?'),
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
