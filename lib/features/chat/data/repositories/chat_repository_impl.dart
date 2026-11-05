import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/data/datasource/chat_remote_datasource.dart';
import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_page.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

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
  Future<ChatTarget> getChatTarget(String conversationId) async {
    final r = await dataSource.getChatTarget(conversationId);
    return ChatTarget(
      conversationId: r.conversationId,
      otherUserId: r.otherUserId,
      otherUserName: r.otherUserName,
      exists: r.exists,
      ownNameIsPlaceholder: r.ownNameIsPlaceholder,
    );
  }

  @override
  Future<void> fillOwnPlaceholderName(String conversationId) {
    return dataSource.fillOwnPlaceholderName(conversationId);
  }

  @override
  Stream<ConversationsUpdate> watchConversations() {
    return dataSource.watchConversations().map(
      (r) => ConversationsUpdate(
        conversations: r.conversations
            .where((c) => c.isVisibleInList)
            .toList(),
        isFromCache: r.isFromCache,
      ),
    );
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
  }) async {
    final r = await dataSource.loadOlderMessages(
      conversationId,
      beforeCreatedAt: before.createdAt,
      beforeMessageId: before.messageId,
      after: after,
      pageSize: pageSize,
    );
    return MessagesPage(
      messages: List<MessageEntity>.unmodifiable(r.messages),
      hasOlder: r.hasOlder,
      isFromCache: r.isFromCache,
    );
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
    return dataSource.markConversationRead(conversationId);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) {
    return dataSource.deleteMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) {
    return dataSource.deleteConversation(conversationId);
  }
}
