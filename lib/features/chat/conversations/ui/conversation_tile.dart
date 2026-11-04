import 'package:car_shop/entities/conversation.dart';
import 'package:car_shop/shared/components/general_widget/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final VoidCallback onTap;
  // Null while deleting is unavailable (offline).
  final VoidCallback? onDelete;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onDelete,
  });

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete conversation',
      message: 'This removes the conversation from your list only.',
    );
    if (confirmed == true) onDelete?.call();
  }

  // Hour and minutes today, the date for earlier days, in the device's time zone (FR-048).
  static String timeText(DateTime time, DateTime now) {
    final local = time.toLocal();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return isToday
        ? DateFormat.jm().format(local)
        : DateFormat.yMMMd().format(local);
  }

  @override
  Widget build(BuildContext context) {
    final time = conversation.lastMessageAt;
    final unread = conversation.unreadCount;
    final isDeleted = conversation.isLastMessageDeleted;

    return ListTile(
      onTap: onTap,
      onLongPress: onDelete == null ? null : () => _confirmAndDelete(context),
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(
        conversation.otherUserName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        isDeleted
            ? 'This message was deleted'
            : conversation.lastMessageText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontStyle: isDeleted ? FontStyle.italic : null),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time != null)
            Text(
              timeText(time, DateTime.now()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Semantics(
              label: '$unread unread messages',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
