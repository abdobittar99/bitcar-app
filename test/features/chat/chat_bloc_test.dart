import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_bloc.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_event.dart';
import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_state.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_page.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/usecase/create_message_id.dart';
import 'package:car_shop/features/chat/domain/usecase/fill_own_placeholder_name.dart';
import 'package:car_shop/features/chat/domain/usecase/get_chat_target.dart';
import 'package:car_shop/features/chat/domain/usecase/get_current_user_id.dart';
import 'package:car_shop/features/chat/domain/usecase/load_older_messages.dart';
import 'package:car_shop/features/chat/domain/usecase/mark_conversation_read.dart';
import 'package:car_shop/features/chat/domain/usecase/open_chat_with_seller.dart';
import 'package:car_shop/features/chat/domain/usecase/send_message.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_latest_messages.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_chat_repository.dart';

CarEntity carOf({
  String sellerId = 'seller',
  String brand = 'Toyota',
  String model = 'Corolla',
  int year = 2020,
}) {
  return CarEntity(
    id: 'car1',
    model: model,
    brand: brand,
    year: year,
    price: 15000,
    location: 'Amman',
    description: '',
    phone: '0790000000',
    images: const [],
    sellerId: sellerId,
    color: 'white',
    carCondition: 'used',
    createdAt: DateTime(2026, 1, 1),
    bodyType: 'sedan',
    fuelType: 'petrol',
    mileage: 1000,
    horsePower: 120,
  );
}

MessageEntity serverMessage(String id, String senderId, DateTime createdAt) {
  return MessageEntity(
    id: id,
    conversationId: 'alice_seller',
    senderId: senderId,
    text: 'text $id',
    createdAt: createdAt,
    isDeleted: false,
    status: MessageStatus.sent,
  );
}

MessagesUpdate updateOf(
  List<MessageEntity> messages, {
  DateTime? otherLastReadAt,
  int unreadCount = 0,
  bool isFromCache = false,
}) {
  return MessagesUpdate(
    messages: messages,
    otherLastReadAt: otherLastReadAt,
    unreadCount: unreadCount,
    clearedAt: null,
    isFromCache: isFromCache,
  );
}

final base = DateTime(2026, 11, 1, 8);

// Server messages m01..mNN, one minute apart, oldest first.
List<MessageEntity> range(int from, int to, {String sender = 'seller'}) => [
  for (var i = from; i <= to; i++)
    serverMessage(
      'm${i.toString().padLeft(2, '0')}',
      sender,
      base.add(Duration(minutes: i)),
    ),
];

MessagesPage pageOf(
  List<MessageEntity> messages, {
  required bool hasOlder,
  bool isFromCache = false,
}) => MessagesPage(
  messages: messages,
  hasOlder: hasOlder,
  isFromCache: isFromCache,
);

// Records every showError call (the cubit itself skips repeated equal messages).
class RecordingErrorCubit extends AppErrorCubit {
  final shown = <String>[];

  @override
  void showError(String message) {
    shown.add(message);
    super.showError(message);
  }
}

ChatBloc buildBloc(
  FakeChatRepository repo,
  AppErrorCubit errors, {
  DateTime Function()? now,
}) {
  return ChatBloc(
    openChatWithSeller: OpenChatWithSeller(repo),
    getChatTarget: GetChatTarget(repo),
    fillOwnPlaceholderName: FillOwnPlaceholderName(repo),
    watchLatestMessages: WatchLatestMessages(repo),
    loadOlderMessages: LoadOlderMessages(repo),
    createMessageId: CreateMessageId(repo),
    sendMessage: SendMessage(repo),
    markConversationRead: MarkConversationRead(repo),
    getCurrentUserId: GetCurrentUserId(repo),
    appErrorCubit: errors,
    now: now,
  );
}

// Lets queued bloc events and stream deliveries run.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeChatRepository repo;
  late RecordingErrorCubit errors;
  late ChatBloc bloc;
  late DateTime clock;

  const inquiry =
      "Hello, I'm interested in your Toyota Corolla (2020). Is it still available?";

  setUp(() {
    repo = FakeChatRepository();
    errors = RecordingErrorCubit();
    clock = DateTime(2026, 11, 1, 12);
    bloc = buildBloc(repo, errors, now: () => clock);
  });

  tearDown(() async {
    await bloc.close();
    await errors.close();
  });

  ChatTarget newTarget() => ChatTarget(
    conversationId: 'alice_seller',
    otherUserId: 'seller',
    otherUserName: 'Sam Seller',
    exists: false,
  );

  group('start', () {
    test('fromCar opens the chat with the car seller and sets the inquiry draft', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();

      expect(repo.calls['openChatWith'], [
        ['seller'],
      ]);
      expect(bloc.state.draft, inquiry);
      expect(bloc.state.target?.conversationId, 'alice_seller');
    });

    test('a new car inquiry replaces any previous draft (FR-050)', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      bloc.add(ChatStarted.fromCar(carOf(brand: 'Kia', model: 'Rio', year: 2018)));
      await settle();

      expect(
        bloc.state.draft,
        "Hello, I'm interested in your Kia Rio (2018). Is it still available?",
      );
    });

    test('a conversation that does not exist yet is new until a message arrives', () async {
      repo.target = newTarget();
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      repo.emitMessages(updateOf(const []));
      await settle();

      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.isNewConversation, isTrue);

      repo.emitMessages(
        updateOf([serverMessage('m1', 'alice', DateTime(2026, 11, 1))]),
      );
      await settle();

      expect(bloc.state.isNewConversation, isFalse);
    });

    test('an existing conversation is not new and shows its messages', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      repo.emitMessages(
        updateOf([
          serverMessage('m1', 'alice', DateTime(2026, 11, 1, 10)),
          serverMessage('m2', 'seller', DateTime(2026, 11, 1, 11)),
        ]),
      );
      await settle();

      expect(bloc.state.isNewConversation, isFalse);
      expect(bloc.state.messages.map((m) => m.id), ['m1', 'm2']);
    });

    test('subscribes to the live window of the opened conversation with 20 messages', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();

      expect(repo.calls['watchLatestMessages'], [
        ['alice_seller', 20],
      ]);
    });

    test('opening the same seller again uses the same conversation id (no duplicate)', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      bloc.add(ChatStarted.fromCar(carOf(brand: 'Kia', model: 'Rio')));
      await settle();

      expect(repo.calls['openChatWith'], [
        ['seller'],
        ['seller'],
      ]);
      expect(
        repo.calls['watchLatestMessages']!.map((c) => c.first).toSet(),
        {'alice_seller'},
      );
      // The first live window is cancelled before the second one starts.
      expect(repo.messageStreams.first.hasListener, isFalse);
      expect(repo.messageStreams.last.hasListener, isTrue);
    });

    test('self-chat AppException goes to AppErrorCubit and nothing is subscribed', () async {
      repo.errors['openChatWith'] = AppException(
        message: "You can't chat with yourself",
        type: ErrorType.validation,
      );
      bloc.add(ChatStarted.fromCar(carOf(sellerId: 'alice')));
      await settle();

      expect(errors.state, "You can't chat with yourself");
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.target, isNull);
      expect(repo.callCount('watchLatestMessages'), 0);
    });

    test('a permission error while opening is shown and nothing is subscribed', () async {
      repo.errors['openChatWith'] = AppException(
        message: "You don't have permission",
        type: ErrorType.permission,
      );
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();

      expect(errors.state, "You don't have permission");
      expect(repo.callCount('watchLatestMessages'), 0);
    });

    test('a signed-out user gets the auth error instead of a chat', () async {
      repo.errors['currentUserId'] = AppException(
        message: 'User not logged in',
        type: ErrorType.auth,
      );
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();

      expect(errors.state, 'User not logged in');
      expect(repo.callCount('openChatWith'), 0);
    });

    test('ChatMessageSubmitted with only whitespace sends nothing', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      bloc.add(ChatMessageSubmitted('   \n '));
      await settle();

      expect(repo.callCount('sendMessage'), 0);
      expect(bloc.state.pendingMessages, isEmpty);
    });

    test('a valid submit adds a sending message and sends it with the created id', () async {
      repo.target = newTarget();
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      bloc.add(ChatMessageSubmitted('  $inquiry  '));
      await settle();

      expect(repo.calls['newMessageId'], [
        ['alice_seller'],
      ]);
      expect(repo.calls['sendMessage'], [
        ['alice_seller', 'local-0', 'seller', inquiry],
      ]);
      final pending = bloc.state.pendingMessages['local-0']!;
      expect(pending.status, MessageStatus.sending);
      expect(pending.text, inquiry);
      expect(pending.senderId, 'alice');
      expect(bloc.state.draft, '');
      expect(bloc.state.messages.last.id, 'local-0');
    });

    test('the sending message is replaced by the server copy with the same id', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();
      repo.emitMessages(
        updateOf([serverMessage('local-0', 'alice', DateTime(2026, 11, 1))]),
      );
      await settle();

      expect(bloc.state.pendingMessages, isEmpty);
      expect(bloc.state.messages.single.status, MessageStatus.sent);
    });

    test('a failed send marks the message failed and shows the error', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      repo.errors['sendMessage'] = AppException(
        message: "You don't have permission",
        type: ErrorType.permission,
      );
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();

      expect(errors.state, "You don't have permission");
      expect(bloc.state.pendingMessages['local-0']!.status, MessageStatus.failed);
      expect(bloc.state.pendingMessages['local-0']!.text, 'Hi');
    });

    test('currentUserId comes from GetCurrentUserId and marks own messages', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      repo.emitMessages(
        updateOf([
          serverMessage('m1', 'alice', DateTime(2026, 11, 1, 10)),
          serverMessage('m2', 'seller', DateTime(2026, 11, 1, 11)),
        ]),
      );
      await settle();

      expect(repo.callCount('currentUserId'), 1);
      expect(bloc.state.currentUserId, 'alice');
      final own = bloc.state.messages
          .where((m) => m.senderId == bloc.state.currentUserId)
          .map((m) => m.id);
      expect(own, ['m1']);
    });

    test('the messages stream completing emits no error', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      await repo.closeMessages();
      await settle();

      expect(errors.state, isNull);
    });

    test('a stream AppException is shown through AppErrorCubit', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      repo.failMessages(
        AppException(message: 'No internet connection', type: ErrorType.network),
      );
      await settle();

      expect(errors.state, 'No internet connection');
      expect(bloc.state.isLoading, isFalse);
    });

    group('fromConversation', () {
      ChatTarget placeholderTarget() => ChatTarget(
        conversationId: 'alice_seller',
        otherUserId: 'seller',
        otherUserName: 'Sam Seller',
        exists: true,
        ownNameIsPlaceholder: true,
      );

      test('uses GetChatTarget, leaves the draft empty and subscribes (FR-009)', () async {
        bloc.add(ChatStarted.fromConversation('alice_seller'));
        await settle();

        expect(repo.calls['getChatTarget'], [
          ['alice_seller'],
        ]);
        expect(repo.callCount('openChatWith'), 0);
        expect(bloc.state.draft, '');
        expect(bloc.state.target?.conversationId, 'alice_seller');
        expect(repo.calls['watchLatestMessages'], [
          ['alice_seller', 20],
        ]);
      });

      test('a notFound AppException is shown and nothing is subscribed', () async {
        repo.errors['getChatTarget'] = AppException(
          message: 'Conversation not found',
          type: ErrorType.notFound,
        );
        bloc.add(ChatStarted.fromConversation('alice_seller'));
        await settle();

        expect(errors.shown, ['Conversation not found']);
        expect(bloc.state.isLoading, isFalse);
        expect(repo.callCount('watchLatestMessages'), 0);
      });

      test('no placeholder: the name fill is not called', () async {
        bloc.add(ChatStarted.fromConversation('alice_seller'));
        await settle();

        expect(repo.callCount('fillOwnPlaceholderName'), 0);
      });

      test('a fill that never completes does not delay the subscription', () async {
        repo.target = placeholderTarget();
        repo.fillGate = Completer<void>();
        bloc.add(ChatStarted.fromConversation('alice_seller'));
        await settle();

        expect(repo.callCount('fillOwnPlaceholderName'), 1);
        expect(repo.callCount('watchLatestMessages'), 1);

        repo.emitMessages(updateOf(range(1, 3)));
        await settle();
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.messages.length, 3);
      });

      test('a network error of the fill is not shown and the chat keeps working', () async {
        repo.target = placeholderTarget();
        repo.fillFailure = AppException(
          message: 'Service temporarily unavailable',
          type: ErrorType.network,
        );
        bloc.add(ChatStarted.fromConversation('alice_seller'));
        await settle();
        repo.emitMessages(updateOf(range(1, 3)));
        await settle();

        expect(errors.shown, isEmpty);
        expect(bloc.state.messages.length, 3);
        expect(bloc.state.canSend, isTrue);
      });

      test('any other error of the fill is shown once and the chat keeps working', () async {
        repo.target = placeholderTarget();
        repo.fillFailure = AppException(
          message: 'You do not have permission to perform this action',
          type: ErrorType.permission,
        );
        bloc.add(ChatStarted.fromConversation('alice_seller'));
        await settle();
        repo.emitMessages(updateOf(range(1, 3)));
        await settle();

        expect(errors.shown, ['You do not have permission to perform this action']);
        expect(bloc.state.streamStatus, ChatStreamStatus.live);
        expect(bloc.state.messages.length, 3);
      });

      test('a fill failing after the bloc is closed shows nothing and is not unhandled', () async {
        repo.target = placeholderTarget();
        repo.fillGate = Completer<void>();
        repo.fillFailure = AppException(
          message: 'You do not have permission to perform this action',
          type: ErrorType.permission,
        );
        bloc.add(ChatStarted.fromConversation('alice_seller'));
        await settle();

        await bloc.close();
        repo.fillGate!.complete();
        await settle();

        // An unhandled exception here would fail this test through the test zone.
        expect(errors.shown, isEmpty);
      });
    });

    test('close() cancels the live window subscription', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      expect(repo.messageStreams.single.hasListener, isTrue);

      await bloc.close();

      expect(repo.messageStreams.single.hasListener, isFalse);
    });
  });

  // Opens the existing A–S conversation and delivers a first live window.
  Future<void> open(List<MessageEntity> window, {bool isFromCache = false}) async {
    bloc.add(ChatStarted.fromCar(carOf()));
    await settle();
    repo.emitMessages(updateOf(window, isFromCache: isFromCache));
    await settle();
  }

  group('statuses', () {
    test('a pending message becomes sent when its id arrives, and appears once', () async {
      await open(const []);
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();
      expect(bloc.state.messages.single.status, MessageStatus.sending);

      repo.emitMessages(updateOf([serverMessage('local-0', 'alice', base)]));
      await settle();

      expect(bloc.state.messages.map((m) => m.id), ['local-0']);
      expect(bloc.state.messages.single.status, MessageStatus.sent);
    });

    test('own messages become read up to otherLastReadAt, also in loadedMessages', () async {
      final own = range(1, 20, sender: 'alice');
      await open(range(21, 40, sender: 'alice'));
      repo.olderPages.add(pageOf(own, hasOlder: false));
      bloc.add(ChatLoadOlderRequested());
      await settle();

      // Read up to m30: m01..m30 read (m01..m20 are loaded-once), m31..m40 sent.
      repo.emitMessages(
        updateOf(
          range(21, 40, sender: 'alice'),
          otherLastReadAt: base.add(const Duration(minutes: 30)),
        ),
      );
      await settle();

      final status = {for (final m in bloc.state.messages) m.id: m.status};
      expect(bloc.state.loadedMessages.containsKey('m05'), isTrue);
      expect(status['m05'], MessageStatus.read);
      expect(status['m30'], MessageStatus.read);
      expect(status['m31'], MessageStatus.sent);
    });

    test("the other user's messages never get a read status", () async {
      await open(range(1, 3));
      repo.emitMessages(updateOf(range(1, 3), otherLastReadAt: base.add(const Duration(hours: 1))));
      await settle();

      expect(bloc.state.messages.every((m) => m.status == MessageStatus.sent), isTrue);
    });

    test('ChatMessageRetried re-sends the same id and creates no duplicate', () async {
      await open(const []);
      repo.errors['sendMessage'] = AppException(
        message: 'No internet connection',
        type: ErrorType.network,
      );
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();
      expect(bloc.state.pendingMessages['local-0']!.status, MessageStatus.failed);

      repo.errors.remove('sendMessage');
      bloc.add(ChatMessageRetried('local-0'));
      await settle();
      repo.emitMessages(updateOf([serverMessage('local-0', 'alice', base)]));
      await settle();

      expect(repo.calls['sendMessage']!.map((c) => c[1]), ['local-0', 'local-0']);
      expect(repo.callCount('newMessageId'), 1);
      expect(bloc.state.messages.map((m) => m.id), ['local-0']);
    });

    test('retrying a message that is not failed does nothing', () async {
      await open(const []);
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();
      bloc.add(ChatMessageRetried('local-0'));
      await settle();

      expect(repo.callCount('sendMessage'), 1);
    });

    test('the server rate-limit error keeps the message failed and is shown', () async {
      await open(const []);
      repo.errors['sendMessage'] = AppException(
        message: "You're sending messages too fast, try again shortly",
        type: ErrorType.validation,
      );
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();

      expect(errors.shown, ["You're sending messages too fast, try again shortly"]);
      expect(bloc.state.pendingMessages['local-0']!.status, MessageStatus.failed);
      expect(bloc.state.pendingMessages['local-0']!.text, 'Hi');
    });

    test('the client pre-check refuses the 21st send within 60 s, and allows it later', () async {
      await open(const []);
      for (var i = 0; i < 21; i++) {
        bloc.add(ChatMessageSubmitted('message $i'));
      }
      await settle();

      expect(repo.callCount('sendMessage'), 20);
      expect(bloc.state.pendingMessages['local-20']!.status, MessageStatus.failed);
      expect(errors.shown, ["You're sending messages too fast, try again shortly"]);

      clock = clock.add(const Duration(seconds: 60));
      bloc.add(ChatMessageRetried('local-20'));
      await settle();

      expect(repo.callCount('sendMessage'), 21);
      expect(repo.calls['sendMessage']!.last[1], 'local-20');
    });

    test('MarkConversationRead is called when visible with unread messages from the server', () async {
      await open(range(1, 3));
      repo.emitMessages(updateOf(range(1, 3), unreadCount: 2));
      await settle();

      expect(repo.calls['markConversationRead'], [
        ['alice_seller'],
      ]);
    });

    test('not while invisible, and once visible again', () async {
      await open(range(1, 3));
      bloc.add(ChatVisibilityChanged(false));
      await settle();
      repo.emitMessages(updateOf(range(1, 3), unreadCount: 2));
      await settle();
      expect(repo.callCount('markConversationRead'), 0);

      bloc.add(ChatVisibilityChanged(true));
      await settle();
      expect(repo.callCount('markConversationRead'), 1);
    });

    test('not from cached data (changes need a connection) and not when already read', () async {
      await open(range(1, 3));
      repo.emitMessages(updateOf(range(1, 3), unreadCount: 2, isFromCache: true));
      await settle();
      repo.emitMessages(updateOf(range(1, 3)));
      await settle();

      expect(repo.callCount('markConversationRead'), 0);
    });

    test('pending messages are not counted in the 20 and never become the cursor', () async {
      await open(range(2, 20));
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();

      // 19 server messages + 1 pending: no older messages, cursor on the oldest server message.
      expect(bloc.state.hasOlder, isFalse);
      expect(bloc.state.oldestCursor!.messageId, 'm02');

      final other = buildBloc(repo, errors, now: () => clock);
      addTearDown(other.close);
      other.add(ChatStarted.fromCar(carOf()));
      await settle();
      other.add(ChatMessageSubmitted('Hi'));
      await settle();
      repo.emitMessages(updateOf(range(1, 20)));
      await settle();

      expect(other.state.hasOlder, isTrue);
      expect(other.state.oldestCursor!.messageId, 'm01');
      expect(other.state.messages.length, 21);
    });
  });

  group('send queue', () {
    List<Object?> sentIds() =>
        repo.calls['sendMessage']!.map((c) => c[1]).toList();

    test('quick sends go one at a time, in order', () async {
      await open(const []);
      repo.sendGate = Completer<void>();
      bloc.add(ChatMessageSubmitted('first'));
      bloc.add(ChatMessageSubmitted('second'));
      bloc.add(ChatMessageSubmitted('third'));
      await settle();

      // All three are on screen, but only the first has started.
      expect(bloc.state.pendingMessages.length, 3);
      expect(sentIds(), ['local-0']);

      repo.sendGate!.complete();
      await settle();
      expect(sentIds(), ['local-0', 'local-1', 'local-2']);
    });

    test('a failed send does not stop the next one', () async {
      await open(const []);
      repo.sendFailures['local-0'] = AppException(
        message: 'No internet connection',
        type: ErrorType.network,
      );
      bloc.add(ChatMessageSubmitted('first'));
      bloc.add(ChatMessageSubmitted('second'));
      await settle();

      expect(sentIds(), ['local-0', 'local-1']);
      expect(bloc.state.pendingMessages['local-0']!.status, MessageStatus.failed);
      expect(bloc.state.pendingMessages['local-1']!.status, MessageStatus.sending);
    });

    test('a retry waits for its turn and keeps the same id', () async {
      await open(const []);
      repo.sendFailures['local-0'] = AppException(
        message: 'No internet connection',
        type: ErrorType.network,
      );
      bloc.add(ChatMessageSubmitted('first'));
      await settle();

      repo.sendGate = Completer<void>();
      bloc.add(ChatMessageSubmitted('second'));
      bloc.add(ChatMessageRetried('local-0'));
      await settle();
      expect(sentIds(), ['local-0', 'local-1']);

      repo.sendGate!.complete();
      await settle();
      expect(sentIds(), ['local-0', 'local-1', 'local-0']);
    });

    test('queued messages are still sent after the user leaves the screen', () async {
      await open(const []);
      repo.sendGate = Completer<void>();
      bloc.add(ChatMessageSubmitted('first'));
      bloc.add(ChatMessageSubmitted('second'));
      await settle();

      final closing = bloc.close();
      repo.sendGate!.complete();
      await closing;
      await settle();

      expect(sentIds(), ['local-0', 'local-1']);
    });
  });

  group('offline banner', () {
    // Opens a chat inside fake time; the first window is from the device cache.
    ChatBloc openFromCache(FakeChatRepository r, FakeAsync async) {
      final b = buildBloc(r, RecordingErrorCubit());
      b.add(ChatStarted.fromCar(carOf()));
      async.flushMicrotasks();
      r.emitMessages(updateOf(range(1, 3), isFromCache: true));
      async.flushMicrotasks();
      return b;
    }

    test('cached data followed by server data never shows the banner', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = openFromCache(r, async);
        expect(b.state.isOffline, isFalse);

        async.elapse(const Duration(milliseconds: 500));
        r.emitMessages(updateOf(range(1, 3)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(b.state.isOffline, isFalse);
        b.close();
        async.flushMicrotasks();
      });
    });

    test('still only cached data after 2 s shows it, and server data hides it', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = openFromCache(r, async);

        async.elapse(const Duration(milliseconds: 1999));
        expect(b.state.isOffline, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(b.state.isOffline, isTrue);

        r.emitMessages(updateOf(range(1, 3)));
        async.flushMicrotasks();
        expect(b.state.isOffline, isFalse);
        b.close();
        async.flushMicrotasks();
      });
    });

    test('close() cancels the banner timer', () {
      fakeAsync((async) {
        final b = openFromCache(FakeChatRepository(), async);

        b.close();
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
      });
    });

    test('savedMessagesEnded needs both offline and a short cached batch', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = openFromCache(r, async);
        r.emitMessages(updateOf(range(21, 40), isFromCache: true));
        async.flushMicrotasks();
        r.olderPages.add(pageOf(range(15, 20), hasOlder: true, isFromCache: true));
        b.add(ChatLoadOlderRequested());
        async.flushMicrotasks();
        expect(b.state.olderBatchIncomplete, isTrue);
        expect(b.state.savedMessagesEnded, isFalse);

        async.elapse(const Duration(seconds: 2));
        expect(b.state.savedMessagesEnded, isTrue);
        b.close();
        async.flushMicrotasks();
      });
    });
  });

  group('stream errors', () {
    AppException network() =>
        AppException(message: 'No internet connection', type: ErrorType.network);

    test('a network error keeps the messages, shows the error once and retries once after 3 s', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final e = RecordingErrorCubit();
        final b = buildBloc(r, e);
        b.add(ChatStarted.fromCar(carOf()));
        async.flushMicrotasks();
        r.emitMessages(updateOf(range(1, 20)));
        async.flushMicrotasks();

        r.failMessages(network());
        async.flushMicrotasks();

        expect(b.state.streamStatus, ChatStreamStatus.failedRetryable);
        expect(b.state.messages.length, 20);
        expect(b.state.liveMessages, isEmpty);
        expect(e.shown, ['No internet connection']);
        expect(r.callCount('watchLatestMessages'), 1);

        async.elapse(const Duration(milliseconds: 2999));
        expect(r.callCount('watchLatestMessages'), 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(r.callCount('watchLatestMessages'), 2);
        expect(b.state.streamStatus, ChatStreamStatus.retrying);

        // The new window merges by id: nothing is duplicated, the cursor is unchanged.
        r.emitMessages(updateOf(range(2, 21)));
        async.flushMicrotasks();
        expect(b.state.streamStatus, ChatStreamStatus.live);
        expect(b.state.messages.map((m) => m.id).toSet().length, 21);
        expect(b.state.messages.length, 21);
        expect(b.state.oldestCursor!.messageId, 'm01');

        b.close();
        async.flushMicrotasks();
      });
    });

    test('a second failure shows Retry without another automatic retry', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = buildBloc(r, RecordingErrorCubit());
        b.add(ChatStarted.fromCar(carOf()));
        async.flushMicrotasks();
        r.failMessages(network());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));
        r.failMessages(network());
        async.flushMicrotasks();

        expect(b.state.streamStatus, ChatStreamStatus.failedRetryable);
        expect(b.state.autoRetryUsed, isTrue);
        async.elapse(const Duration(seconds: 10));
        expect(r.callCount('watchLatestMessages'), 2);

        // The Retry button still works.
        b.add(ChatRetried());
        async.flushMicrotasks();
        expect(r.callCount('watchLatestMessages'), 3);

        b.close();
        async.flushMicrotasks();
      });
    });

    test('two quick ChatRetried re-subscribe exactly once', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = buildBloc(r, RecordingErrorCubit());
        b.add(ChatStarted.fromCar(carOf()));
        async.flushMicrotasks();
        r.failMessages(network());
        async.flushMicrotasks();

        b.add(ChatRetried());
        b.add(ChatRetried());
        async.flushMicrotasks();
        expect(r.callCount('watchLatestMessages'), 2);

        // The pending automatic retry was cancelled by the manual one.
        async.elapse(const Duration(seconds: 5));
        expect(r.callCount('watchLatestMessages'), 2);

        b.close();
        async.flushMicrotasks();
      });
    });

    test('a permission error is fatal: no automatic retry, ChatRetried ignored, sending disabled', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final e = RecordingErrorCubit();
        final b = buildBloc(r, e);
        b.add(ChatStarted.fromCar(carOf()));
        async.flushMicrotasks();
        r.emitMessages(updateOf(range(1, 3)));
        async.flushMicrotasks();
        r.failMessages(
          AppException(message: "You don't have permission", type: ErrorType.permission),
        );
        async.flushMicrotasks();

        expect(b.state.streamStatus, ChatStreamStatus.failedFatal);
        expect(b.state.streamError, "You don't have permission");
        expect(b.state.canSend, isFalse);
        expect(b.state.messages.length, 3);

        async.elapse(const Duration(seconds: 10));
        b.add(ChatRetried());
        b.add(ChatMessageSubmitted('Hi'));
        async.flushMicrotasks();
        expect(r.callCount('watchLatestMessages'), 1);
        expect(r.callCount('sendMessage'), 0);

        b.close();
        async.flushMicrotasks();
      });
    });

    test('stream done changes nothing', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final e = RecordingErrorCubit();
        final b = buildBloc(r, e);
        b.add(ChatStarted.fromCar(carOf()));
        async.flushMicrotasks();
        r.emitMessages(updateOf(range(1, 3)));
        async.flushMicrotasks();
        r.closeMessages();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(b.state.streamStatus, ChatStreamStatus.live);
        expect(b.state.messages.length, 3);
        expect(e.shown, isEmpty);
        expect(r.callCount('watchLatestMessages'), 1);

        b.close();
        async.flushMicrotasks();
      });
    });

    test('close() cancels the retry timer', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = buildBloc(r, RecordingErrorCubit());
        b.add(ChatStarted.fromCar(carOf()));
        async.flushMicrotasks();
        r.failMessages(network());
        async.flushMicrotasks();

        b.close();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(r.callCount('watchLatestMessages'), 1);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('pagination', () {
    List<Object?> lastOlderCall() => repo.calls['loadOlderMessages']!.last;

    String cursorId(Object? cursor) => (cursor as MessageCursor).messageId;

    test('messages pushed out of the live window move to loadedMessages and stay', () async {
      await open(range(1, 20));
      repo.emitMessages(updateOf(range(2, 21)));
      await settle();

      expect(bloc.state.loadedMessages.keys, ['m01']);
      expect(bloc.state.messages.map((m) => m.id), range(1, 21).map((m) => m.id));
    });

    test('union of live, loaded and pending has no duplicates', () async {
      await open(range(21, 40));
      // The older batch overlaps the window by one message (m21).
      repo.olderPages.add(pageOf(range(2, 21), hasOlder: true));
      bloc.add(ChatLoadOlderRequested());
      bloc.add(ChatMessageSubmitted('Hi'));
      await settle();

      final ids = bloc.state.messages.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, 40);
      expect(ids.last, 'local-0');
    });

    test('order is by (createdAt, id), including equal timestamps', () async {
      await open([
        serverMessage('b', 'seller', base),
        serverMessage('c', 'seller', base.add(const Duration(seconds: 1))),
        serverMessage('a', 'seller', base),
      ]);

      expect(bloc.state.messages.map((m) => m.id), ['a', 'b', 'c']);
    });

    test('two ChatLoadOlderRequested in a row send one request', () async {
      await open(range(21, 40));
      repo.olderPages.add(pageOf(range(1, 20), hasOlder: true));
      repo.olderGate = Completer<void>();
      bloc.add(ChatLoadOlderRequested());
      bloc.add(ChatLoadOlderRequested());
      await settle();
      // Reaching the top again while the batch loads.
      bloc.add(ChatLoadOlderRequested());
      await settle();

      expect(repo.callCount('loadOlderMessages'), 1);
      expect(bloc.state.isLoadingOlder, isTrue);

      repo.olderGate!.complete();
      await settle();
      expect(bloc.state.isLoadingOlder, isFalse);
      expect(bloc.state.messages.length, 40);
    });

    test('a new message arriving while an older batch loads is kept, and nothing is lost', () async {
      await open(range(21, 40));
      repo.olderPages.add(pageOf(range(1, 20), hasOlder: true));
      repo.olderGate = Completer<void>();
      bloc.add(ChatLoadOlderRequested());
      await settle();

      repo.emitMessages(updateOf(range(22, 41)));
      await settle();
      repo.olderGate!.complete();
      await settle();

      expect(bloc.state.messages.map((m) => m.id), range(1, 41).map((m) => m.id));
      expect(bloc.state.oldestCursor!.messageId, 'm01');
      expect(bloc.state.loadedMessages.containsKey('m21'), isTrue);
    });

    test('the cursor is the oldest server-confirmed message overall', () async {
      await open(range(41, 60));
      expect(bloc.state.oldestCursor!.messageId, 'm41');

      repo.olderPages.add(pageOf(range(21, 40), hasOlder: true));
      bloc.add(ChatLoadOlderRequested());
      await settle();
      expect(cursorId(lastOlderCall()[1]), 'm41');
      expect(bloc.state.oldestCursor!.messageId, 'm21');

      // New messages sliding the window do not move the cursor.
      repo.emitMessages(updateOf(range(42, 61)));
      await settle();
      bloc.add(ChatLoadOlderRequested());
      await settle();
      expect(cursorId(lastOlderCall()[1]), 'm21');
    });

    test('fewer than 20 in the first server window: no older messages, no request', () async {
      await open(range(1, 7));
      bloc.add(ChatLoadOlderRequested());
      await settle();

      expect(bloc.state.hasOlder, isFalse);
      expect(repo.callCount('loadOlderMessages'), 0);
    });

    test('a server batch with fewer than 20 ends the history', () async {
      await open(range(21, 40));
      repo.olderPages.add(pageOf(range(16, 20), hasOlder: false));
      bloc.add(ChatLoadOlderRequested());
      await settle();
      bloc.add(ChatLoadOlderRequested());
      await settle();

      expect(bloc.state.hasOlder, isFalse);
      expect(repo.callCount('loadOlderMessages'), 1);
      expect(bloc.state.messages.length, 25);
    });

    test('40 messages: one extra empty request ends the history without an error', () async {
      await open(range(21, 40));
      repo.olderPages.add(pageOf(range(1, 20), hasOlder: true));
      bloc.add(ChatLoadOlderRequested());
      await settle();
      repo.olderPages.add(pageOf(const [], hasOlder: false));
      bloc.add(ChatLoadOlderRequested());
      await settle();

      expect(repo.callCount('loadOlderMessages'), 2);
      expect(bloc.state.hasOlder, isFalse);
      expect(bloc.state.olderLoadFailed, isFalse);
      expect(errors.shown, isEmpty);
      expect(bloc.state.messages.length, 40);
    });

    test('a cache-only short batch keeps hasOlder and is requested again on the next server update', () async {
      await open(range(21, 40));
      repo.olderPages.add(pageOf(range(15, 20), hasOlder: true, isFromCache: true));
      bloc.add(ChatLoadOlderRequested());
      await settle();

      expect(bloc.state.hasOlder, isTrue);
      expect(bloc.state.olderBatchIncomplete, isTrue);
      expect(bloc.state.oldestCursor!.messageId, 'm21');

      // Still offline: no new request.
      repo.emitMessages(updateOf(range(21, 40), isFromCache: true));
      await settle();
      expect(repo.callCount('loadOlderMessages'), 1);

      repo.olderPages.add(pageOf(range(1, 20), hasOlder: true));
      repo.emitMessages(updateOf(range(21, 40)));
      await settle();

      expect(repo.callCount('loadOlderMessages'), 2);
      expect(cursorId(lastOlderCall()[1]), 'm21');
      expect(bloc.state.olderBatchIncomplete, isFalse);
      expect(bloc.state.oldestCursor!.messageId, 'm01');
      expect(bloc.state.messages.length, 40);
    });

    test('a first window from the cache does not end the history', () async {
      await open(range(1, 5), isFromCache: true);
      expect(bloc.state.hasOlder, isTrue);

      repo.emitMessages(updateOf(range(1, 5)));
      await settle();
      expect(bloc.state.hasOlder, isFalse);
    });

    test('offline at the end of the saved messages: repeated requests stop until server data arrives', () async {
      await open(range(21, 40), isFromCache: true);
      repo.olderPages.add(pageOf(range(15, 20), hasOlder: true, isFromCache: true));
      bloc.add(ChatLoadOlderRequested());
      await settle();
      expect(repo.callCount('loadOlderMessages'), 1);

      // What the list does at the top after every rebuild.
      for (var i = 0; i < 5; i++) {
        bloc.add(ChatLoadOlderRequested());
        await settle();
      }
      expect(repo.callCount('loadOlderMessages'), 1);
      expect(bloc.state.isLoadingOlder, isFalse);
      expect(bloc.state.olderBatchIncomplete, isTrue);

      repo.olderPages.add(pageOf(range(1, 20), hasOlder: true));
      repo.emitMessages(updateOf(range(21, 40)));
      await settle();
      expect(repo.callCount('loadOlderMessages'), 2);
      expect(bloc.state.olderBatchIncomplete, isFalse);
    });

    test('an error keeps the messages, sets olderLoadFailed, and retry uses the same cursor', () async {
      await open(range(21, 40));
      repo.errors['loadOlderMessages'] = AppException(
        message: 'No internet connection',
        type: ErrorType.network,
      );
      bloc.add(ChatLoadOlderRequested());
      await settle();

      expect(bloc.state.olderLoadFailed, isTrue);
      expect(bloc.state.isLoadingOlder, isFalse);
      expect(bloc.state.messages.length, 20);
      expect(errors.shown, ['No internet connection']);

      repo.errors.remove('loadOlderMessages');
      repo.olderPages.add(pageOf(range(1, 20), hasOlder: true));
      bloc.add(ChatLoadOlderRequested());
      await settle();

      final calls = repo.calls['loadOlderMessages']!;
      expect(calls.map((c) => cursorId(c[1])), ['m21', 'm21']);
      expect(bloc.state.olderLoadFailed, isFalse);
      expect(bloc.state.messages.length, 40);
    });
  });
}
