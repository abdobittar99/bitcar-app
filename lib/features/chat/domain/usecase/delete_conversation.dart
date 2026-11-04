import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class DeleteConversation {
  final ChatRepository repo;
  DeleteConversation(this.repo);

  Future<void> call(String conversationId) {
    return repo.deleteConversation(conversationId);
  }
}
