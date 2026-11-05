import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class CreateMessageId {
  final ChatRepository repo;
  CreateMessageId(this.repo);

  String call(String conversationId) => repo.newMessageId(conversationId);
}
