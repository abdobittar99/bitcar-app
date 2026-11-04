import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class FillOwnPlaceholderName {
  final ChatRepository repo;
  FillOwnPlaceholderName(this.repo);

  Future<void> call(String conversationId) {
    return repo.fillOwnPlaceholderName(conversationId);
  }
}
