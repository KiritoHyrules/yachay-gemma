import 'package:flutter/material.dart';

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

/// Chat-first screen with message list, thinking indicator, context chips,
/// and prompt bar. Pure presentational — accepts data as parameters.
class ChatScreen extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isThinking;
  final ValueChanged<String>? onSend;

  const ChatScreen({
    super.key,
    this.messages = const [],
    this.isThinking = false,
    this.onSend,
  });

  static const _greetingText =
      '¡Hola! Soy Yachay, tu tutor de aritmética. ¿Qué querés aprender hoy?';

  @override
  Widget build(BuildContext context) {
    final displayMessages = messages.isEmpty && !isThinking
        ? [const ChatMessage(text: _greetingText, isUser: false)]
        : messages;

    return Column(
      children: [
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
        _ContextChipRow(onChipTapped: _handleChip),
        _PromptBar(
          enabled: !isThinking,
          onSend: onSend,
        ),
      ],
    );
  }

  void _handleChip(String chipLabel) {
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
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

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
                    child: Text('Y', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                    border: isUser ? null : Border.all(color: Colors.grey.shade300),
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
            child: Text('Y', style: TextStyle(color: Colors.white, fontSize: 12)),
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

/// Row of quick-action chips: Explicar, Practicar, Mi progreso, Cambiar tema.
class _ContextChipRow extends StatelessWidget {
  final ValueChanged<String>? onChipTapped;

  const _ContextChipRow({this.onChipTapped});

  static const _chips = ['Explicar', 'Practicar', 'Mi progreso', 'Cambiar tema'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _chips.map((label) {
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
            IconButton(
              icon: const Icon(Icons.mic, color: Colors.grey),
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
                  hintText: widget.enabled ? 'Escribí tu mensaje...' : 'Yachay está pensando...',
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
