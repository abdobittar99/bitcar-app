import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_page.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';

abstract class ChatRepository {
  String get currentUserId;

  Future<void> syncPublicProfile(String displayName);

  Future<ChatTarget> openChatWith({required String otherUserId});

  Future<ChatTarget> getChatTarget(String conversationId);

  Future<void> fillOwnPlaceholderName(String conversationId);

  Stream<ConversationsUpdate> watchConversations();

  Stream<MessagesUpdate> watchLatestMessages({
    required String conversationId,
    required int pageSize,
  });

  Future<MessagesPage> loadOlderMessages({
    required String conversationId,
    required MessageCursor before,
    DateTime? after,
    required int pageSize,
  });

  String newMessageId(String conversationId);

  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String otherUserId,
    required String text,
  });

  Future<void> markConversationRead(String conversationId);

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  Future<void> deleteConversation(String conversationId);
}
