const messagesPageSize = 20;

// Plain-Dart cursor: the oldest server-confirmed message loaded so far.
class MessageCursor {
  final DateTime createdAt;
  final String messageId;

  MessageCursor({required this.createdAt, required this.messageId});
}
