import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/entities/message.dart';
import 'package:car_shop/shared/components/general_widget/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isOwn;
  // Tapping a failed own message sends it again (FR-014).
  final VoidCallback? onRetry;
  // Null while deleting is unavailable (offline, live updates failed).
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.onRetry,
    this.onDelete,
  });

  // Only own messages the server has confirmed can be deleted (FR-047).
  bool get _canOfferDelete =>
      onDelete != null &&
      isOwn &&
      !message.isDeleted &&
      (message.status == MessageStatus.sent ||
          message.status == MessageStatus.read);

  Future<void> _showDeleteOption(BuildContext context) async {
    final choseDelete = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text('Delete'),
          onTap: () => Navigator.pop(sheetContext, true),
        ),
      ),
    );
    if (choseDelete != true || !context.mounted) return;
    final confirmed = await confirmDelete(
      context,
      title: 'Delete message',
      message: 'Delete this message for everyone?',
    );
    if (confirmed == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = message.createdAt;
    final isDeleted = message.isDeleted;
    final isFailed = isOwn && !isDeleted && message.status == MessageStatus.failed;
    final textColor = isOwn ? Colors.white : Colors.black87;
    final metaColor = textColor.withValues(alpha: 0.7);

    final bubble = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isFailed
            ? Colors.red.shade400
            : isOwn
            ? Colors.blue
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          isDeleted
              ? Text(
                  'This message was deleted',
                  style: TextStyle(
                    color: metaColor,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Text(message.text, style: TextStyle(color: textColor)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (createdAt != null)
                // Local time zone of the device (FR-048).
                Text(
                  DateFormat.jm().format(createdAt.toLocal()),
                  style: TextStyle(fontSize: 11, color: metaColor),
                ),
              if (isOwn && !isDeleted) ...[
                const SizedBox(width: 4),
                _StatusIcon(status: message.status, color: metaColor),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: isFailed
            ? GestureDetector(onTap: onRetry, child: bubble)
            : _canOfferDelete
            ? GestureDetector(
                onLongPress: () => _showDeleteOption(context),
                child: bubble,
              )
            : bubble,
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final Color color;

  const _StatusIcon({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (status) {
      MessageStatus.sending => (Icons.access_time, 'Sending'),
      MessageStatus.sent => (Icons.done, 'Sent'),
      MessageStatus.read => (Icons.done_all, 'Read'),
      MessageStatus.failed => (Icons.error_outline, 'Failed, tap to retry'),
    };
    return Semantics(
      label: label,
      child: Icon(
        icon,
        size: 14,
        color: status == MessageStatus.failed ? Colors.white : color,
      ),
    );
  }
}
