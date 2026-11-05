import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class MarkConversationRead {
  final ChatRepository repo;
  MarkConversationRead(this.repo);

  Future<void> call(String conversationId) {
    return repo.markConversationRead(conversationId);
  }
}
