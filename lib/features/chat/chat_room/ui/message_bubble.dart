import 'package:car_shop/entities/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isOwn;

  const MessageBubble({super.key, required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final createdAt = message.createdAt;
    final textColor = isOwn ? Colors.white : Colors.black87;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOwn ? Colors.blue : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(message.text, style: TextStyle(color: textColor)),
              if (createdAt != null) ...[
                const SizedBox(height: 2),
                // Local time zone of the device (FR-048).
                Text(
                  DateFormat.jm().format(createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
