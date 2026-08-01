import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/diagnostic_result.dart';
import '../../core/state/student_state.dart';
import '../aprendizaje/ruta_screen.dart';
import 'diagnostico_service.dart';

/// Full diagnostic flow screen.
///
/// Displays one item at a time with four option buttons and a progress bar.
/// After completion, shows the result screen with the student's competency
/// level label — no numeric scores, no grade comparisons, positive language only.
class DiagnosticoScreen extends StatefulWidget {
  const DiagnosticoScreen({super.key});

  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen> {
  DiagnosticoService? _service;
  DiagnosticResult? _result;

  DiagnosticItem? _currentItem;
  int _itemsAdmin = 0;
  int _totalItems = 25;
  bool _loading = true;
  bool _respondiendo = false;

  /// Subject order: matemáticas first, then lectura.
  static const _materias = ['matematicas', 'lectura'];
  int _materiaIndex = 0;
  DiagnosticResult? _mathResult;
  DiagnosticResult? _readingResult;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      _service = await DiagnosticoService.cargar();
      if (mounted) {
        setState(() => _loading = false);
        _iniciarDiagnostico();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los materiales: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _iniciarDiagnostico() async {
    if (_service == null) return;

    final materia = _materias[_materiaIndex];
    _itemsAdmin = 0;

    setState(() {
      _loading = true;
      _currentItem = null;
      _result = null;
    });

    final result = await _service!.ejecutarDiagnostico(
      materia: materia,
      onItem: (item) async {
        if (!mounted) return false;
        setState(() {
          _currentItem = item;
          _loading = false;
          _respondiendo = false;
        });

        // Wait for user to tap an option
        final respuesta = await _esperarRespuesta();
        return respuesta;
      },
      onProgress: (theta, n) {
        if (mounted) {
          setState(() {
            _itemsAdmin = n;
          });
        }
      },
    );

    if (!mounted) return;

    // Store per-subject result
    if (materia == 'matematicas') {
      _mathResult = result;
    } else {
      _readingResult = result;
    }

    // Move to next subject or finish
    _materiaIndex++;
    if (_materiaIndex < _materias.length) {
      _iniciarDiagnostico();
    } else {
      // Both subjects completed — persist combined result
      final combinedLevel = ((_mathResult?.nivel ?? 3) + (_readingResult?.nivel ?? 3)) ~/ 2;
      final combinedResult = DiagnosticResult(
        nivel: combinedLevel,
        etiqueta: _etiquetaNivelGlobal(combinedLevel),
        theta: ((_mathResult?.theta ?? 0.0) + (_readingResult?.theta ?? 0.0)) / 2.0,
        precision: ((_mathResult?.precision ?? 0.3) + (_readingResult?.precision ?? 0.3)) / 2.0,
        itemsAdministrados:
            (_mathResult?.itemsAdministrados ?? 0) + (_readingResult?.itemsAdministrados ?? 0),
      );

      // Persist to student state + database
      final studentState = context.read<StudentState>();
      await studentState.updateDiagnostic(combinedResult);

      if (mounted) {
        setState(() {
          _result = combinedResult;
          _loading = false;
          _currentItem = null;
        });
      }
    }
  }

  /// Shows the option buttons and waits for the user to tap one.
  /// Returns true if the selected option is correct.
  Future<bool> _esperarRespuesta() async {
    _respondiendo = true;
    final completer = Completer<bool>();

    setState(() {}); // rebuild to show options

    // Store the completer so option taps can resolve it
    _respuestaCompleter = completer;
    return completer.future;
  }

  Completer<bool>? _respuestaCompleter;

  void _onOpcionTap(int index) {
    if (!_respondiendo || _respuestaCompleter == null || _currentItem == null) return;

    final correcta = index == _currentItem!.respuestaCorrecta;

    // Record interaction (neutral feedback — no negative language)
    context.read<StudentState>().recordInteraction(isCorrect: correcta);

    _respuestaCompleter!.complete(correcta);
    _respuestaCompleter = null;
    _respondiendo = false;
  }

  String _etiquetaNivelGlobal(int nivel) {
    switch (nivel) {
      case 1:
        return 'Explorador';
      case 2:
        return 'Aprendiz';
      case 3:
        return 'Practicante';
      case 4:
        return 'Aventurero';
      case 5:
        return 'Experto';
      default:
        return 'Practicante';
    }
  }

  void _irRutaAprendizaje() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const RutaScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprendo+'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _result != null
              ? _buildResultado(theme)
              : _buildItem(theme),
    );
  }

  Widget _buildItem(ThemeData theme) {
    if (_currentItem == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final item = _currentItem!;
    final materia = _materias[_materiaIndex > 0 ? 1 : 0];
    final materiaLabel = materia == 'matematicas' ? 'Matematicas' : 'Lectura';

    // Build a shuffled index list so option order varies per item (but keep mapping)
    final indices = List<int>.generate(4, (i) => i)..shuffle();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subject label and progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                avatar: Icon(
                  materia == 'matematicas' ? Icons.calculate : Icons.menu_book,
                  size: 18,
                ),
                label: Text(materiaLabel),
              ),
              Text(
                '$_itemsAdmin de $_totalItems',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _itemsAdmin / _totalItems,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 32),

          // Item enunciado
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                item.enunciado,
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Option buttons
          ...indices.map((i) {
            final letra = ['A', 'B', 'C', 'D'][i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: _respondiendo ? () => _onOpcionTap(i) : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        letra,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item.opciones[i],
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultado(ThemeData theme) {
    final result = _result!;
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon for the level
          Icon(
            _iconoNivel(result.nivel),
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),

          // Level label
          Text(
            'Tu nivel es',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.etiqueta,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Positive message (no numeric scores, no grades, no comparisons)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _mensajeResultado(result.nivel),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Route description
          Text(
            _descripcionRuta(result.nivel),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Proceed button
          FilledButton.icon(
            onPressed: _irRutaAprendizaje,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Ver mi ruta de aprendizaje'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconoNivel(int nivel) {
    switch (nivel) {
      case 1:
        return Icons.explore;
      case 2:
        return Icons.school;
      case 3:
        return Icons.engineering;
      case 4:
        return Icons.rocket_launch;
      case 5:
        return Icons.auto_awesome;
      default:
        return Icons.school;
    }
  }

  String _mensajeResultado(int nivel) {
    switch (nivel) {
      case 1:
        return 'Estas comenzando tu camino. Cada paso que des te hara mas fuerte. '
            'Hemos preparado una ruta especial para ti.';
      case 2:
        return 'Ya tienes una base solida. Con practica y dedicacion, '
            'seguiras avanzando a tu ritmo. Vas por buen camino.';
      case 3:
        return 'Tienes un buen dominio de los temas. Sigue practicando '
            'para alcanzar todo tu potencial. Lo estas haciendo muy bien.';
      case 4:
        return 'Has demostrado un gran nivel. Estas listo para desafios '
            'mas avanzados. Sigue asi, vas a llegar lejos.';
      case 5:
        return 'Tu nivel es sobresaliente. Dominas los temas con seguridad. '
            'Ahora puedes profundizar y ayudar a otros a aprender.';
      default:
        return 'Sigue aprendiendo a tu ritmo. Cada dia es una oportunidad para mejorar.';
    }
  }

  String _descripcionRuta(int nivel) {
    switch (nivel) {
      case 1:
        return 'Tu ruta comienza con los fundamentos. Avanzaras paso a paso, '
            'sin presion y a tu propio ritmo.';
      case 2:
        return 'Tu ruta refuerza lo que ya sabes y te lleva al siguiente nivel '
            'con ejercicios practicos.';
      case 3:
        return 'Tu ruta esta disenada para consolidar tus conocimientos '
            'y explorar temas mas complejos.';
      case 4:
        return 'Tu ruta incluye desafios avanzados que pondran a prueba '
            'tus habilidades y te prepararan para lo que sigue.';
      case 5:
        return 'Tu ruta te lleva mas alla: proyectos, problemas complejos '
            'y la oportunidad de compartir lo que sabes.';
      default:
        return 'Tu ruta personalizada te espera.';
    }
  }
}

