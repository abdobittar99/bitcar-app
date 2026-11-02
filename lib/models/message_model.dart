import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/entities/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel extends MessageEntity {
  MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.text,
    required super.createdAt,
    required super.isDeleted,
    required super.status,
  });

  // Server messages are "sent"; "read" is derived later from the other user's lastReadAt.
  // A null createdAt (not expected: sends are transactions) stays "sending" and is never a cursor.
  factory MessageModel.fromMap(
    Map<String, dynamic> map,
    String id,
    String conversationId,
  ) {
    final createdAt = (map['createdAt'] as Timestamp?)?.toDate();
    final isDeleted = map['deleted'] as bool? ?? false;
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: map['senderId'] as String? ?? '',
      text: isDeleted ? '' : map['text'] as String? ?? '',
      createdAt: createdAt,
      isDeleted: isDeleted,
      status: createdAt == null ? MessageStatus.sending : MessageStatus.sent,
    );
  }

  // Exactly the keys the security rules accept for a new message.
  static Map<String, dynamic> toCreateMap({
    required String senderId,
    required String text,
  }) {
    return {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    };
  }
}
