class ChatTarget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final bool exists;
  // Own stored name is still the placeholder, according to server data (research D14).
  final bool ownNameIsPlaceholder;

  ChatTarget({
    this.ownNameIsPlaceholder = false,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.exists,
  });
}
