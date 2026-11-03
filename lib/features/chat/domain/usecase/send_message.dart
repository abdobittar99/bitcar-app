import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class SendMessage {
  final ChatRepository repo;
  SendMessage(this.repo);

  Future<void> call({
    required String conversationId,
    required String messageId,
    required String otherUserId,
    required String text,
  }) {
    return repo.sendMessage(
      conversationId: conversationId,
      messageId: messageId,
      otherUserId: otherUserId,
      text: text,
    );
  }
}
