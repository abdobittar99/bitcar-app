class ConversationEntity {
  final String id;
  final List<String> participantIds;
  final String buyerId;
  final String sellerId;
  final String otherUserId;
  final String otherUserName;
  final String lastMessageText;
  final bool isLastMessageDeleted;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime? otherLastReadAt;
  final DateTime? clearedAt;

  ConversationEntity({
    required this.id,
    required this.participantIds,
    required this.buyerId,
    required this.sellerId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessageText,
    required this.isLastMessageDeleted,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.otherLastReadAt,
    required this.clearedAt,
  });

  bool get isVisibleInList =>
      lastMessageAt != null &&
      (clearedAt == null || lastMessageAt!.isAfter(clearedAt!));
}
