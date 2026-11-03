import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_bloc.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_event.dart';
import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/usecase/create_message_id.dart';
import 'package:car_shop/features/chat/domain/usecase/get_current_user_id.dart';
import 'package:car_shop/features/chat/domain/usecase/open_chat_with_seller.dart';
import 'package:car_shop/features/chat/domain/usecase/send_message.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_latest_messages.dart';
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

MessagesUpdate updateOf(List<MessageEntity> messages) {
  return MessagesUpdate(
    messages: messages,
    otherLastReadAt: null,
    unreadCount: 0,
    clearedAt: null,
    isFromCache: false,
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
  late AppErrorCubit errors;
  late ChatBloc bloc;

  const inquiry =
      "Hello, I'm interested in your Toyota Corolla (2020). Is it still available?";

  setUp(() {
    repo = FakeChatRepository();
    errors = AppErrorCubit();
    bloc = ChatBloc(
      openChatWithSeller: OpenChatWithSeller(repo),
      watchLatestMessages: WatchLatestMessages(repo),
      createMessageId: CreateMessageId(repo),
      sendMessage: SendMessage(repo),
      getCurrentUserId: GetCurrentUserId(repo),
      appErrorCubit: errors,
    );
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

    test('close() cancels the live window subscription', () async {
      bloc.add(ChatStarted.fromCar(carOf()));
      await settle();
      expect(repo.messageStreams.single.hasListener, isTrue);

      await bloc.close();

      expect(repo.messageStreams.single.hasListener, isFalse);
    });
  });
}
