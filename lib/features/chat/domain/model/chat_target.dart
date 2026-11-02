class ChatTarget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final bool exists;

  ChatTarget({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.exists,
  });
}
