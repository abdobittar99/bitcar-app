import 'package:car_shop/core/validators/chat_validator.dart';
import 'package:flutter/material.dart';

class MessageInputBar extends StatefulWidget {
  final String draft;
  final bool enabled;
  final ValueChanged<String> onSend;

  const MessageInputBar({
    super.key,
    required this.draft,
    required this.onSend,
    this.enabled = true,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.draft,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  // A new draft from the bloc (the car inquiry) replaces the current text (FR-050).
  @override
  void didUpdateWidget(MessageInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft != oldWidget.draft) {
      _controller.text = widget.draft;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    widget.onSend(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && _controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                maxLength: ChatValidator.maxLength,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              icon: const Icon(Icons.send),
              onPressed: canSend ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}
