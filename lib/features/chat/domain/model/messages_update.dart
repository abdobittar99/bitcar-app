import 'package:car_shop/entities/message.dart';

// One emission of the live window (newest messages) with the conversation's read state.
class MessagesUpdate {
  final List<MessageEntity> messages;
  final DateTime? otherLastReadAt;
  final int unreadCount;
  final DateTime? clearedAt;
  final bool isFromCache;

  MessagesUpdate({
    required this.messages,
    required this.otherLastReadAt,
    required this.unreadCount,
    required this.clearedAt,
    required this.isFromCache,
  });
}
