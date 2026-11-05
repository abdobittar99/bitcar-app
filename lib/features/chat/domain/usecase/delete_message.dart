import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class DeleteMessage {
  final ChatRepository repo;
  DeleteMessage(this.repo);

  Future<void> call({
    required String conversationId,
    required String messageId,
  }) {
    return repo.deleteMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
  }
}
