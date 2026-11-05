import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class WatchConversations {
  final ChatRepository repo;
  WatchConversations(this.repo);

  Stream<ConversationsUpdate> call() => repo.watchConversations();
}
