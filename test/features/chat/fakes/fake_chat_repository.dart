import 'dart:async';

import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_page.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

// In-memory ChatRepository for bloc tests: push stream updates, queue older batches,
// make any method throw, and inspect the calls that were made.
class FakeChatRepository implements ChatRepository {
  String uid = 'alice';

  ChatTarget target = ChatTarget(
    conversationId: 'alice_seller',
    otherUserId: 'seller',
    otherUserName: 'Sam Seller',
    exists: true,
  );

  // Name of a method -> exception it throws (futures) or emits first (streams).
  final Map<String, AppException> errors = {};

  // Name of a method -> argument lists of every call, in order.
  final Map<String, List<List<Object?>>> calls = {};

  // One controller per watch call, so retries can be observed and driven separately.
  final List<StreamController<ConversationsUpdate>> conversationStreams = [];
  final List<StreamController<MessagesUpdate>> messageStreams = [];

  // Results returned by loadOlderMessages, in order.
  final List<MessagesPage> olderPages = [];

  int _nextId = 0;

  int callCount(String method) => calls[method]?.length ?? 0;

  void emitConversations(ConversationsUpdate update) =>
      conversationStreams.last.add(update);

  void emitMessages(MessagesUpdate update) => messageStreams.last.add(update);

  void failMessages(AppException error) => messageStreams.last.addError(error);

  Future<void> closeMessages() => messageStreams.last.close();

  Future<void> closeConversations() => conversationStreams.last.close();

  void _record(String method, [List<Object?> args = const []]) {
    calls.putIfAbsent(method, () => []).add(args);
    final error = errors[method];
    if (error != null) throw error;
  }

  @override
  String get currentUserId {
    _record('currentUserId');
    return uid;
  }

  @override
  Future<void> syncPublicProfile(String displayName) async {
    _record('syncPublicProfile', [displayName]);
  }

  @override
  Future<ChatTarget> openChatWith({required String otherUserId}) async {
    _record('openChatWith', [otherUserId]);
    return target;
  }

  @override
  Future<ChatTarget> getChatTarget(String conversationId) async {
    _record('getChatTarget', [conversationId]);
    return target;
  }

  @override
  Stream<ConversationsUpdate> watchConversations() {
    final controller = StreamController<ConversationsUpdate>();
    conversationStreams.add(controller);
    try {
      _record('watchConversations');
    } on AppException catch (e) {
      controller.addError(e);
    }
    return controller.stream;
  }

  @override
  Stream<MessagesUpdate> watchLatestMessages({
    required String conversationId,
    required int pageSize,
  }) {
    final controller = StreamController<MessagesUpdate>();
    messageStreams.add(controller);
    try {
      _record('watchLatestMessages', [conversationId, pageSize]);
    } on AppException catch (e) {
      controller.addError(e);
    }
    return controller.stream;
  }

  @override
  Future<MessagesPage> loadOlderMessages({
    required String conversationId,
    required MessageCursor before,
    DateTime? after,
    required int pageSize,
  }) async {
    _record('loadOlderMessages', [conversationId, before, after, pageSize]);
    return olderPages.isEmpty
        ? MessagesPage(messages: const [], hasOlder: false, isFromCache: false)
        : olderPages.removeAt(0);
  }

  @override
  String newMessageId(String conversationId) {
    _record('newMessageId', [conversationId]);
    return 'local-${_nextId++}';
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String otherUserId,
    required String text,
  }) async {
    _record('sendMessage', [conversationId, messageId, otherUserId, text]);
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    _record('markConversationRead', [conversationId]);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    _record('deleteMessage', [conversationId, messageId]);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _record('deleteConversation', [conversationId]);
  }
}
