import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class WatchLatestMessages {
  final ChatRepository repo;
  WatchLatestMessages(this.repo);

  Stream<MessagesUpdate> call(
    String conversationId, {
    int pageSize = messagesPageSize,
  }) {
    return repo.watchLatestMessages(
      conversationId: conversationId,
      pageSize: pageSize,
    );
  }
}
