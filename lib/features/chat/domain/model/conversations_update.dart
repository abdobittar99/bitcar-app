import 'package:car_shop/entities/conversation.dart';

class ConversationsUpdate {
  final List<ConversationEntity> conversations;
  final bool isFromCache;

  ConversationsUpdate({required this.conversations, required this.isFromCache});
}
