import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class GetChatTarget {
  final ChatRepository repo;
  GetChatTarget(this.repo);

  Future<ChatTarget> call(String conversationId) {
    return repo.getChatTarget(conversationId);
  }
}
