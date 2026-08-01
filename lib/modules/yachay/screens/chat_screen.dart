import 'package:flutter/material.dart';

import '../../../core/data/learning_data.dart';

/// A single message in the Yachay chat.
@immutable
class ChatMessage {
  final String text;
  final bool isUser;
  final Key? key;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.key,
  });
}

/// Summarises the current study session — topics touched, messages sent,
/// and elapsed time. Used by REQ-07 (Session Summary Card).
@immutable
class SessionSummary {
  final int topicsCovered;
  final int messagesExchanged;
  final Duration timeSpent;

  const SessionSummary({
    required this.topicsCovered,
    required this.messagesExchanged,
    required this.timeSpent,
  });
}

/// Maps internal area keys to display-friendly Spanish names.
const _areaNames = {
  'comunicacion': 'Comunicación',
  'matematica': 'Matemática',
  'ciencia': 'Ciencia',
};

/// Maps internal priority keys to display labels with the "Prioridad" prefix.
const _prioridadLabels = {
  'alta': 'Prioridad alta',
  'media': 'Prioridad media',
  'baja': 'Prioridad baja',
};

/// Chat-first screen with message list, thinking indicator, context chips,
/// and prompt bar. Pure presentational — accepts data as parameters.
class ChatScreen extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isThinking;
  final ValueChanged<String>? onSend;

  /// Current curriculum topic driving the header, greeting, and chips.
  final TemaPrimaria? currentTopic;

  /// BKT P(learned) for current topic (0.0–1.0).  null → "Sin datos aún".
  final double? masteryPercent;

  /// Dynamic suggestion chips. null → default 4-chip set.
  final List<String>? suggestionChips;

  /// Session summary shown at top. null → hidden.
  final SessionSummary? sessionSummary;

  /// Called when a context chip is tapped. When provided the label is sent
  /// directly (no hardcoded mapping). When null, falls back to [onSend]
  /// with the legacy `label → message` map.
  final ValueChanged<String>? onTopicChipTap;

  const ChatScreen({
    super.key,
    this.messages = const [],
    this.isThinking = false,
    this.onSend,
    this.currentTopic,
    this.masteryPercent,
    this.suggestionChips,
    this.sessionSummary,
    this.onTopicChipTap,
  });

  static const _greetingText =
      '¡Hola! Soy Yachay, tu tutor de aritmética. ¿Qué querés aprender hoy?';

  /// Builds the greeting, adapting the area when [currentTopic] is set.
  static String _greetingFor(TemaPrimaria? topic) {
    if (topic == null) return _greetingText;
    final area = (_areaNames[topic.area] ?? topic.area).toLowerCase();
    return '¡Hola! Soy Yachay, tu tutor de $area. ¿Qué querés aprender hoy?';
  }

  @override
  Widget build(BuildContext context) {
    final displayMessages = messages.isEmpty && !isThinking
        ? [ChatMessage(text: _greetingFor(currentTopic), isUser: false)]
        : messages;

    final headerWidgets = <Widget>[];

    // REQ-07: Session Summary Card (above messages, below topic header)
    if (sessionSummary != null) {
      headerWidgets.add(_SessionSummaryCard(summary: sessionSummary!));
    }

    // REQ-01: Topic Header Bar
    if (currentTopic != null) {
      headerWidgets.add(_TopicHeader(topic: currentTopic!));
    }

    // REQ-03: BKT Mastery Indicator
    headerWidgets.add(_MasteryBar(masteryPercent: masteryPercent));

    return Column(
      children: [
        if (headerWidgets.isNotEmpty) ...headerWidgets,
        Expanded(
          child: ListView.builder(
            reverse: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: displayMessages.length + (isThinking ? 1 : 0),
            itemBuilder: (context, index) {
              // Thinking indicator as last item
              if (isThinking && index == displayMessages.length) {
                return const _ThinkingIndicator();
              }
              final msg = displayMessages[index];
              return _MessageBubble(message: msg, index: index);
            },
          ),
        ),
        _ContextChipRow(
          chips: suggestionChips ?? _ContextChipRow.defaultChips,
          onChipTapped: _handleChip,
        ),
        _PromptBar(
          enabled: !isThinking,
          onSend: onSend,
        ),
      ],
    );
  }

  void _handleChip(String chipLabel) {
    // When onTopicChipTap is provided, forward the label directly
    // (no mapping — design intent for curriculum-driven chips).
    if (onTopicChipTap != null) {
      onTopicChipTap!(chipLabel);
      return;
    }

    // Legacy fallback: translate label → message via hardcoded map.
    final chipMessages = <String, String>{
      'Explicar': 'Quiero explicar',
      'Practicar': 'Quiero practicar',
      'Mi progreso': 'Mi progreso',
      'Cambiar tema': 'Cambiar tema',
    };
    final text = chipMessages[chipLabel] ?? chipLabel;
    onSend?.call(text);
  }
}

// =============================================================================
// REQ-01: Topic Header Bar
// =============================================================================

/// Shows current topic area badge, title, and priority chip.
class _TopicHeader extends StatelessWidget {
  final TemaPrimaria topic;

  const _TopicHeader({required this.topic});

  /// Picks a colour per area so the badge is visually distinct.
  static Color _colorForArea(String area) {
    switch (area) {
      case 'comunicacion':
        return const Color(0xFFE65100); // deep orange
      case 'matematica':
        return const Color(0xFF1565C0); // blue
      case 'ciencia':
        return const Color(0xFF2E7D32); // green
      default:
        return Colors.grey;
    }
  }

  static Color _colorForPrioridad(String prioridad) {
    switch (prioridad) {
      case 'alta':
        return const Color(0xFFC62828);
      case 'media':
        return const Color(0xFFEF6C00);
      case 'baja':
        return const Color(0xFF757575);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaLabel = _areaNames[topic.area] ?? topic.area;
    final prioridadLabel = _prioridadLabels[topic.prioridad] ?? topic.prioridad;

    return Container(
      key: const Key('topic-header'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Area badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _colorForArea(topic.area).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _colorForArea(topic.area).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              areaLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _colorForArea(topic.area),
              ),
            ),
          ),
          // Topic title
          Expanded(
            child: Text(
              topic.titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Priority badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  _colorForPrioridad(topic.prioridad).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _colorForPrioridad(topic.prioridad).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              prioridadLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _colorForPrioridad(topic.prioridad),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REQ-03: BKT Mastery Indicator
// =============================================================================

/// Thin progress bar + "Dominio: X%" label. Shows "Sin datos aún" when null.
class _MasteryBar extends StatelessWidget {
  final double? masteryPercent;

  const _MasteryBar({required this.masteryPercent});

  @override
  Widget build(BuildContext context) {
    final hasData = masteryPercent != null;
    final value = (masteryPercent ?? 0.0).clamp(0.0, 1.0);
    final percentText = hasData ? '${(value * 100).round()}%' : '';

    Color barColor() {
      if (!hasData) return Colors.grey.shade300;
      if (value >= 0.9) return Colors.green;
      if (value >= 0.5) return Colors.orange;
      return Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: hasData
                ? LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor()),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  )
                : const SizedBox.shrink(),
          ),
          if (hasData) const SizedBox(width: 10),
          Text(
            hasData ? 'Dominio: $percentText' : 'Sin datos aún',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REQ-07: Session Summary Card
// =============================================================================

/// Subtle card above the message list summarising the session.
class _SessionSummaryCard extends StatelessWidget {
  final SessionSummary summary;

  const _SessionSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final min = summary.timeSpent.inMinutes;
    final tLabel =
        '${summary.topicsCovered} ${summary.topicsCovered == 1 ? 'tema' : 'temas'}';
    final mLabel =
        '${summary.messagesExchanged} ${summary.messagesExchanged == 1 ? 'mensaje' : 'mensajes'}';

    return Container(
      key: const Key('session-summary-card'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('\u{1F4DA} ', style: TextStyle(fontSize: 14)),
          Text(tLabel,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          const Text('\u{1F4AC} ', style: TextStyle(fontSize: 14)),
          Text(mLabel,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          const Text('\u{23F1} ', style: TextStyle(fontSize: 14)),
          Text('$min min',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// =============================================================================
// Message bubbles, thinking indicator, chips, and prompt bar
// =============================================================================

/// Renders a single chat bubble — user (right, blue) or Yachay (left, white).
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int index;

  const _MessageBubble({required this.message, required this.index});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleKey = isUser
        ? Key('user-bubble-msg-$index')
        : Key('yachay-bubble-msg-$index');
    final color = isUser ? const Color(0xFF1565C0) : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF1565C0),
                    child: Text('Y',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              Flexible(
                child: Container(
                  key: bubbleKey,
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border:
                        isUser ? null : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated "Yachay está pensando..." indicator shown during inference.
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF1565C0),
            child:
                Text('Y', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yachay está pensando',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(width: 4),
                _AnimatedDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three animated dots to indicate activity.
class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dots = <Widget>[];
        for (var i = 0; i < 3; i++) {
          final opacity = ((_controller.value * 3 - i) % 1.0).clamp(0.0, 1.0);
          dots.add(
            Opacity(
              opacity: opacity < 0.3 ? 0.3 : opacity,
              child: const Text('.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          );
        }
        return Row(mainAxisSize: MainAxisSize.min, children: dots);
      },
    );
  }
}

/// Row of quick-action chips — dynamic or default fallback.
class _ContextChipRow extends StatelessWidget {
  final List<String> chips;
  final ValueChanged<String>? onChipTapped;

  const _ContextChipRow({required this.chips, this.onChipTapped});

  static const defaultChips = [
    'Explicar',
    'Practicar',
    'Mi progreso',
    'Cambiar tema'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((label) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 13)),
                onPressed: () => onChipTapped?.call(label),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Fixed prompt bar with text input, send button, and mic placeholder.
class _PromptBar extends StatefulWidget {
  final bool enabled;
  final ValueChanged<String>? onSend;

  const _PromptBar({required this.enabled, this.onSend});

  @override
  State<_PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends State<_PromptBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.onSend != null) {
      widget.onSend!(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const IconButton(
              icon: Icon(Icons.mic, color: Colors.grey),
              onPressed: null,
              tooltip: 'Micrófono (próximamente)',
            ),
            Expanded(
              child: TextField(
                enabled: widget.enabled,
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? 'Escribí tu mensaje...'
                      : 'Yachay está pensando...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send),
              color: const Color(0xFF1565C0),
              onPressed: widget.enabled ? _handleSend : null,
            ),
          ],
        ),
      ),
    );
  }
}
