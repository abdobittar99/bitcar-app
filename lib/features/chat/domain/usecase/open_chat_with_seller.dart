import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class OpenChatWithSeller {
  final ChatRepository repo;
  OpenChatWithSeller(this.repo);

  Future<ChatTarget> call(String sellerId) {
    return repo.openChatWith(otherUserId: sellerId);
  }
}
