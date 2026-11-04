import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/features/chat/data/datasource/chat_remote_datasource.dart';
import 'package:car_shop/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/models/conversation_model.dart';
import 'package:car_shop/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Datasource double: only the members used by US1 are implemented; anything else fails loudly.
class _FakeDataSource implements ChatRemoteDataSource {
  OpenChatRecord openResult = (
    conversationId: 'alice_seller',
    otherUserId: 'seller',
    otherUserName: 'Sam Seller',
    exists: true,
  );
  AppException? openError;
  AppException? sendError;
  final openCalls = <String>[];
  final sendCalls = <List<String>>[];
  final watchCalls = <List<Object>>[];
  final controller = StreamController<LatestMessagesRecord>();

  @override
  Future<OpenChatRecord> openChatWith(String otherUserId) async {
    openCalls.add(otherUserId);
    if (openError != null) throw openError!;
    return openResult;
  }

  @override
  String newMessageId(String conversationId) => '$conversationId-new';

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String otherUserId,
    required String text,
  }) async {
    sendCalls.add([conversationId, messageId, otherUserId, text]);
    if (sendError != null) throw sendError!;
  }

  @override
  Stream<LatestMessagesRecord> watchLatestMessages(
    String conversationId,
    int pageSize,
  ) {
    watchCalls.add([conversationId, pageSize]);
    return controller.stream;
  }

  ChatTargetRecord targetResult = (
    conversationId: 'alice_seller',
    otherUserId: 'seller',
    otherUserName: 'Sam Seller',
    exists: true,
    ownNameIsPlaceholder: true,
  );
  final fillCalls = <String>[];
  final conversationsController = StreamController<ConversationsRecord>();

  @override
  Future<ChatTargetRecord> getChatTarget(String conversationId) async =>
      targetResult;

  @override
  Future<void> fillOwnPlaceholderName(String conversationId) async {
    fillCalls.add(conversationId);
  }

  @override
  Stream<ConversationsRecord> watchConversations() =>
      conversationsController.stream;

  final olderCalls = <List<Object?>>[];
  final readCalls = <String>[];

  @override
  Future<OlderMessagesRecord> loadOlderMessages(
    String conversationId, {
    required DateTime beforeCreatedAt,
    required String beforeMessageId,
    DateTime? after,
    required int pageSize,
  }) async {
    olderCalls.add([conversationId, beforeCreatedAt, beforeMessageId, after, pageSize]);
    return (messages: <MessageModel>[], hasOlder: true, isFromCache: true);
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    readCalls.add(conversationId);
  }

  final deleteMessageCalls = <List<String>>[];
  final deleteConversationCalls = <String>[];
  AppException? deleteError;

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    deleteMessageCalls.add([conversationId, messageId]);
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    deleteConversationCalls.add(conversationId);
    if (deleteError != null) throw deleteError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeDataSource dataSource;
  late ChatRepositoryImpl repo;

  setUp(() {
    dataSource = _FakeDataSource();
    repo = ChatRepositoryImpl(dataSource);
  });

  group('openChatWith', () {
    test('an existing conversation becomes a ChatTarget with exists true', () async {
      final target = await repo.openChatWith(otherUserId: 'seller');

      expect(dataSource.openCalls, ['seller']);
      expect(target.conversationId, 'alice_seller');
      expect(target.otherUserId, 'seller');
      expect(target.otherUserName, 'Sam Seller');
      expect(target.exists, isTrue);
    });

    test('a missing conversation becomes a ChatTarget with exists false (nothing written)', () async {
      dataSource.openResult = (
        conversationId: 'alice_seller',
        otherUserId: 'seller',
        otherUserName: 'BitCar user',
        exists: false,
      );

      final target = await repo.openChatWith(otherUserId: 'seller');

      expect(target.exists, isFalse);
      expect(target.otherUserName, 'BitCar user');
      expect(dataSource.sendCalls, isEmpty);
    });

    test('the self-chat validation error reaches the caller unchanged', () async {
      dataSource.openError = AppException(
        message: "You can't chat with yourself",
        type: ErrorType.validation,
      );

      expect(
        () => repo.openChatWith(otherUserId: 'alice'),
        throwsA(
          isA<AppException>().having((e) => e.type, 'type', ErrorType.validation),
        ),
      );
    });

    test('a permission error reaches the caller unchanged', () async {
      dataSource.openError = AppException(
        message: "You don't have permission",
        type: ErrorType.permission,
      );

      expect(
        () => repo.openChatWith(otherUserId: 'seller'),
        throwsA(
          isA<AppException>().having((e) => e.type, 'type', ErrorType.permission),
        ),
      );
    });
  });

  group('sending', () {
    test('newMessageId and sendMessage pass through to the datasource', () async {
      final id = repo.newMessageId('alice_seller');
      await repo.sendMessage(
        conversationId: 'alice_seller',
        messageId: id,
        otherUserId: 'seller',
        text: 'Hello',
      );

      expect(id, 'alice_seller-new');
      expect(dataSource.sendCalls, [
        ['alice_seller', 'alice_seller-new', 'seller', 'Hello'],
      ]);
    });

    test('the rate-limit error reaches the caller unchanged', () async {
      dataSource.sendError = AppException(
        message: ChatRemoteDataSource.rateLimitMessage,
        type: ErrorType.validation,
      );

      expect(
        () => repo.sendMessage(
          conversationId: 'alice_seller',
          messageId: 'm1',
          otherUserId: 'seller',
          text: 'Hello',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            "You're sending messages too fast, try again shortly",
          ),
        ),
      );
    });
  });

  group('conversations', () {
    ConversationModel conversation(String id, {DateTime? at, DateTime? cleared}) {
      return ConversationModel(
        id: id,
        participantIds: const ['alice', 'seller'],
        buyerId: 'alice',
        sellerId: 'seller',
        otherUserId: 'seller',
        otherUserName: 'Sam Seller',
        lastMessageText: 'Hello',
        isLastMessageDeleted: false,
        lastMessageSenderId: 'seller',
        lastMessageAt: at,
        unreadCount: 0,
        otherLastReadAt: null,
        clearedAt: cleared,
      );
    }

    test('getChatTarget carries ownNameIsPlaceholder', () async {
      final target = await repo.getChatTarget('alice_seller');

      expect(target.conversationId, 'alice_seller');
      expect(target.otherUserName, 'Sam Seller');
      expect(target.exists, isTrue);
      expect(target.ownNameIsPlaceholder, isTrue);
    });

    test('openChatWith leaves ownNameIsPlaceholder false', () async {
      final target = await repo.openChatWith(otherUserId: 'seller');

      expect(target.ownNameIsPlaceholder, isFalse);
    });

    test('fillOwnPlaceholderName passes through to the datasource', () async {
      await repo.fillOwnPlaceholderName('alice_seller');

      expect(dataSource.fillCalls, ['alice_seller']);
    });

    test('watchConversations keeps only conversations visible in the list', () async {
      final t = DateTime(2026, 11, 1, 10);
      final updates = <ConversationsUpdate>[];
      final sub = repo.watchConversations().listen(updates.add);

      dataSource.conversationsController.add((
        conversations: [
          conversation('visible', at: t),
          conversation('no-message'),
          conversation('cleared', at: t, cleared: t.add(const Duration(hours: 1))),
        ],
        isFromCache: true,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(updates.single.conversations.map((c) => c.id), ['visible']);
      expect(updates.single.isFromCache, isTrue);
      await sub.cancel();
    });
  });

  group('delete', () {
    test('deleteMessage and deleteConversation pass through to the datasource', () async {
      await repo.deleteMessage(conversationId: 'alice_seller', messageId: 'm1');
      await repo.deleteConversation('alice_seller');

      expect(dataSource.deleteMessageCalls, [
        ['alice_seller', 'm1'],
      ]);
      expect(dataSource.deleteConversationCalls, ['alice_seller']);
    });

    test('their errors reach the caller unchanged', () async {
      dataSource.deleteError = AppException(
        message: 'Message not found',
        type: ErrorType.notFound,
      );

      await expectLater(
        repo.deleteMessage(conversationId: 'alice_seller', messageId: 'm1'),
        throwsA(isA<AppException>().having((e) => e.type, 'type', ErrorType.notFound)),
      );
      await expectLater(
        repo.deleteConversation('alice_seller'),
        throwsA(isA<AppException>().having((e) => e.type, 'type', ErrorType.notFound)),
      );
    });
  });

  group('older messages and read state', () {
    test('loadOlderMessages unpacks the cursor and builds a MessagesPage', () async {
      final createdAt = DateTime(2026, 11, 1, 10);
      final clearedAt = DateTime(2026, 10, 1);

      final page = await repo.loadOlderMessages(
        conversationId: 'alice_seller',
        before: MessageCursor(createdAt: createdAt, messageId: 'm21'),
        after: clearedAt,
        pageSize: 20,
      );

      expect(dataSource.olderCalls, [
        ['alice_seller', createdAt, 'm21', clearedAt, 20],
      ]);
      expect(page.messages, isEmpty);
      expect(page.hasOlder, isTrue);
      expect(page.isFromCache, isTrue);
    });

    test('markConversationRead passes through to the datasource', () async {
      await repo.markConversationRead('alice_seller');

      expect(dataSource.readCalls, ['alice_seller']);
    });
  });

  group('watchLatestMessages', () {
    test('records become MessagesUpdate with entities and read state', () async {
      final createdAt = DateTime(2026, 11, 1, 10);
      final readAt = DateTime(2026, 11, 1, 11);
      final updates = <MessagesUpdate>[];
      final sub = repo
          .watchLatestMessages(conversationId: 'alice_seller', pageSize: 20)
          .listen(updates.add);

      dataSource.controller.add((
        messages: [
          MessageModel(
            id: 'm1',
            conversationId: 'alice_seller',
            senderId: 'alice',
            text: 'Hello',
            createdAt: createdAt,
            isDeleted: false,
            status: MessageStatus.sent,
          ),
        ],
        otherLastReadAt: readAt,
        unreadCount: 2,
        clearedAt: null,
        isFromCache: true,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(dataSource.watchCalls, [
        ['alice_seller', 20],
      ]);
      final update = updates.single;
      expect(update.messages.single.id, 'm1');
      expect(update.messages.single.createdAt, createdAt);
      expect(update.otherLastReadAt, readAt);
      expect(update.unreadCount, 2);
      expect(update.clearedAt, isNull);
      expect(update.isFromCache, isTrue);
      await sub.cancel();
    });

    test('stream errors and completion are passed on', () async {
      final errors = <Object>[];
      var done = false;
      repo
          .watchLatestMessages(conversationId: 'alice_seller', pageSize: 20)
          .listen((_) {}, onError: errors.add, onDone: () => done = true);

      dataSource.controller.addError(
        AppException(message: "You don't have permission", type: ErrorType.permission),
      );
      await dataSource.controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<AppException>());
      expect(done, isTrue);
    });
  });
}
