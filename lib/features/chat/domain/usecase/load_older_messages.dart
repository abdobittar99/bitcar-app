import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_page.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class LoadOlderMessages {
  final ChatRepository repo;
  LoadOlderMessages(this.repo);

  Future<MessagesPage> call(
    String conversationId,
    MessageCursor before, {
    DateTime? after,
    int pageSize = messagesPageSize,
  }) {
    return repo.loadOlderMessages(
      conversationId: conversationId,
      before: before,
      after: after,
      pageSize: pageSize,
    );
  }
}
