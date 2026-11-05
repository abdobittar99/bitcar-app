import 'package:car_shop/core/enums/message_status.dart';

class MessageEntity {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  // Null only for local pending messages.
  final DateTime? createdAt;
  final bool isDeleted;
  final MessageStatus status;

  MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isDeleted,
    required this.status,
  });

  MessageEntity copyWith({
    String? text,
    DateTime? createdAt,
    bool? isDeleted,
    MessageStatus? status,
  }) {
    return MessageEntity(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      status: status ?? this.status,
    );
  }
}
