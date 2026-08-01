import 'package:flutter/material.dart';

import '../../../modules/gemma/gemma_service.dart';
import 'chat_screen.dart';
import 'camino_screen.dart';
import 'perfil_screen.dart';

/// Root scaffold with bottom navigation: Chat | Camino | Perfil.
/// Preserves tab state via IndexedStack. Wires ChatScreen to GemmaService.
class YachayScaffold extends StatefulWidget {
  const YachayScaffold({super.key});

  @override
  State<YachayScaffold> createState() => _YachayScaffoldState();
}

class _YachayScaffoldState extends State<YachayScaffold> {
  int _currentIndex = 0;
  final _messages = <ChatMessage>[];
  bool _isThinking = false;
  final _gemmaService = GemmaService.instance;
  bool _modelLoaded = false;
  bool _modelFailed = false;
  String _loadingStatus = 'Inicializando...';
  final _debugLog = <String>[];
  bool _showDebug = false;

  void _log(String msg) {
    setState(() => _debugLog.add('[${DateTime.now().toString().substring(11, 19)}] $msg'));
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
      if (mounted) {
        setState(() {
          _modelLoaded = loaded;
          _modelFailed = !loaded;
        });
      }
    } catch (e) {
      _log('ERROR: $e');
      if (mounted) setState(() => _modelFailed = true);
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
      Achievement(id: 'perfect_streak', title: 'Racha Perfecta', isUnlocked: false),
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
                child: Text('Y', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Yachay'),
            if (!_modelLoaded && !_modelFailed) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(
                _modelLoaded ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: _modelLoaded ? Colors.green : Colors.orange,
              ),
              label: Text(_modelLoaded ? 'Gemma' : _modelFailed ? 'Offline' : 'Cargando...'),
              backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
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
      bottomSheet: _showDebug ? Container(
        height: 100,
        color: Colors.black87,
        child: ListView(
          children: _debugLog.map((l) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Text(l, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
          )).toList(),
        ),
      ) : null,
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

    // Wait for model if still loading (up to 30s).
    if (!_modelLoaded) {
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (_modelLoaded) break;
      }
    }

    try {
      _log('Enviando: "$text"');
      final response = await _gemmaService.procesarMensaje(text.trim());
      _log('Respuesta (${response.length} chars): "${response.substring(0, response.length.clamp(0, 80))}"');
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isThinking = false;
      });
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
}
