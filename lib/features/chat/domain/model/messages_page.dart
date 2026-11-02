import 'package:car_shop/entities/message.dart';

// Result of one older-batch read. hasOlder is false only when the server returned a short batch.
class MessagesPage {
  final List<MessageEntity> messages;
  final bool hasOlder;
  final bool isFromCache;

  MessagesPage({
    required this.messages,
    required this.hasOlder,
    required this.isFromCache,
  });
}
