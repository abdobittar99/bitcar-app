import 'package:car_shop/entities/conversation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel extends ConversationEntity {
  ConversationModel({
    required super.id,
    required super.participantIds,
    required super.buyerId,
    required super.sellerId,
    required super.otherUserId,
    required super.otherUserName,
    required super.lastMessageText,
    required super.isLastMessageDeleted,
    required super.lastMessageSenderId,
    required super.lastMessageAt,
    required super.unreadCount,
    required super.otherLastReadAt,
    required super.clearedAt,
  });

  // Deterministic id of the single conversation between two users.
  static String idFor(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  factory ConversationModel.fromMap(
    Map<String, dynamic> map,
    String id,
    String currentUid,
  ) {
    final participants = (map['participants'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final otherUserId = participants.firstWhere(
      (p) => p != currentUid,
      orElse: () => '',
    );
    final names = map['participantNames'] as Map<String, dynamic>? ?? {};
    final unread = map['unreadCount'] as Map<String, dynamic>? ?? {};
    final lastReadAt = map['lastReadAt'] as Map<String, dynamic>? ?? {};
    final clearedAt = map['clearedAt'] as Map<String, dynamic>? ?? {};
    final lastMessage = map['lastMessage'] as Map<String, dynamic>? ?? {};

    return ConversationModel(
      id: id,
      participantIds: participants,
      buyerId: map['buyerId'] as String? ?? '',
      sellerId: map['sellerId'] as String? ?? '',
      otherUserId: otherUserId,
      otherUserName: names[otherUserId] as String? ?? 'BitCar user',
      lastMessageText: lastMessage['text'] as String? ?? '',
      isLastMessageDeleted: lastMessage['deleted'] as bool? ?? false,
      lastMessageSenderId: lastMessage['senderId'] as String?,
      lastMessageAt: _toDate(map['lastMessageAt']),
      unreadCount: (unread[currentUid] as num?)?.toInt() ?? 0,
      otherLastReadAt: _toDate(lastReadAt[otherUserId]),
      clearedAt: _ownTime(clearedAt, currentUid),
    );
  }

  static DateTime? _toDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  // snapshots() in cloud_firestore 6.1.0 has no serverTimestampBehavior: an own pending
  // serverTimestamp() arrives as a present key with a null value, which means "now".
  static DateTime? _ownTime(Map<String, dynamic> map, String uid) {
    if (!map.containsKey(uid)) return null;
    return _toDate(map[uid]) ?? DateTime.now();
  }
}
