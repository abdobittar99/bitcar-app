import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/data/datasource/chat_remote_datasource.dart';
import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_page.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

// Methods that throw UnimplementedError are filled in by their user-story tasks (tasks.md).
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource dataSource;

  ChatRepositoryImpl(this.dataSource);

  @override
  String get currentUserId => dataSource.currentUserId;

  @override
  Future<void> syncPublicProfile(String displayName) {
    return dataSource.syncPublicProfile(displayName);
  }

  @override
  Future<ChatTarget> openChatWith({required String otherUserId}) async {
    final r = await dataSource.openChatWith(otherUserId);
    return ChatTarget(
      conversationId: r.conversationId,
      otherUserId: r.otherUserId,
      otherUserName: r.otherUserName,
      exists: r.exists,
    );
  }

  @override
  Future<ChatTarget> getChatTarget(String conversationId) {
    throw UnimplementedError('getChatTarget: T057/T058');
  }

  @override
  Stream<ConversationsUpdate> watchConversations() {
    throw UnimplementedError('watchConversations: T057/T058');
  }

  @override
  Stream<MessagesUpdate> watchLatestMessages({
    required String conversationId,
    required int pageSize,
  }) {
    return dataSource
        .watchLatestMessages(conversationId, pageSize)
        .map(
          (r) => MessagesUpdate(
            messages: List<MessageEntity>.unmodifiable(r.messages),
            otherLastReadAt: r.otherLastReadAt,
            unreadCount: r.unreadCount,
            clearedAt: r.clearedAt,
            isFromCache: r.isFromCache,
          ),
        );
  }

  @override
  Future<MessagesPage> loadOlderMessages({
    required String conversationId,
    required MessageCursor before,
    DateTime? after,
    required int pageSize,
  }) {
    throw UnimplementedError('loadOlderMessages: T048/T050');
  }

  @override
  String newMessageId(String conversationId) {
    return dataSource.newMessageId(conversationId);
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String otherUserId,
    required String text,
  }) {
    return dataSource.sendMessage(
      conversationId: conversationId,
      messageId: messageId,
      otherUserId: otherUserId,
      text: text,
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) {
    throw UnimplementedError('markConversationRead: T049/T050');
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) {
    throw UnimplementedError('deleteMessage: T069/T070');
  }

  @override
  Future<void> deleteConversation(String conversationId) {
    throw UnimplementedError('deleteConversation: T069/T070');
  }
}
