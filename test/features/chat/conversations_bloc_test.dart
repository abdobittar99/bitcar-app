import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/entities/conversation.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_bloc.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_event.dart';
import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/usecase/delete_conversation.dart';
import 'package:car_shop/features/chat/domain/usecase/get_current_user_id.dart';
import 'package:car_shop/features/chat/domain/usecase/sync_public_profile.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_conversations.dart';
import 'package:car_shop/features/home/domain/repositories/home_repository.dart';
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_chat_repository.dart';

class FakeHomeRepository implements HomeRepository {
  AppException? error;
  int calls = 0;

  @override
  Future<UserEntity> getCurrentUser() async {
    calls++;
    if (error != null) throw error!;
    return UserEntity(
      fullName: 'Alice Buyer',
      id: 'alice',
      email: 'alice@test.dev',
      phone: '0790000000',
      role: UserRole.buyer,
    );
  }

  @override
  Future<void> logOut() async {}
}

class RecordingErrorCubit extends AppErrorCubit {
  final shown = <String>[];

  @override
  void showError(String message) {
    shown.add(message);
    super.showError(message);
  }
}

ConversationEntity conversationOf(String id, int unread) => ConversationEntity(
  id: id,
  participantIds: const ['alice', 'seller'],
  buyerId: 'alice',
  sellerId: 'seller',
  otherUserId: 'seller',
  otherUserName: 'Sam Seller',
  lastMessageText: 'Hello',
  isLastMessageDeleted: false,
  lastMessageSenderId: 'seller',
  lastMessageAt: DateTime(2026, 11, 1),
  unreadCount: unread,
  otherLastReadAt: null,
  clearedAt: null,
);

ConversationsUpdate updateOf(
  List<ConversationEntity> conversations, {
  bool isFromCache = false,
}) => ConversationsUpdate(conversations: conversations, isFromCache: isFromCache);

ConversationsBloc buildBloc(
  FakeChatRepository repo,
  FakeHomeRepository home,
  AppErrorCubit errors,
) {
  return ConversationsBloc(
    getCurrentUser: GetCurrentUser(home),
    getCurrentUserId: GetCurrentUserId(repo),
    syncPublicProfile: SyncPublicProfile(repo),
    watchConversations: WatchConversations(repo),
    deleteConversation: DeleteConversation(repo),
    appErrorCubit: errors,
  );
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeChatRepository repo;
  late FakeHomeRepository home;
  late RecordingErrorCubit errors;
  late ConversationsBloc bloc;

  AppException permission() => AppException(
    message: 'You do not have permission to perform this action',
    type: ErrorType.permission,
  );
  AppException network() => AppException(
    message: 'Service temporarily unavailable',
    type: ErrorType.network,
  );

  setUp(() {
    repo = FakeChatRepository();
    home = FakeHomeRepository();
    errors = RecordingErrorCubit();
    bloc = buildBloc(repo, home, errors);
  });

  tearDown(() async {
    await bloc.close();
    await errors.close();
  });

  group('start', () {
    test('loads the user, subscribes and syncs the public name', () async {
      bloc.add(ConversationsStarted());
      await settle();

      expect(home.calls, 1);
      expect(repo.callCount('watchConversations'), 1);
      expect(repo.calls['syncPublicProfile'], [
        ['Alice Buyer'],
      ]);
    });

    test('a sync that never completes does not delay the subscription or the list', () async {
      repo.syncGate = Completer<void>();
      bloc.add(ConversationsStarted());
      await settle();

      expect(repo.callCount('watchConversations'), 1);
      repo.emitConversations(updateOf([conversationOf('a', 0)]));
      await settle();
      expect(bloc.state.conversations.length, 1);
      expect(bloc.state.isLoading, isFalse);
    });

    test('a network error of the sync is not shown and the list keeps working', () async {
      repo.syncFailure = network();
      bloc.add(ConversationsStarted());
      await settle();
      repo.emitConversations(updateOf([conversationOf('a', 0)]));
      await settle();

      expect(errors.shown, isEmpty);
      expect(bloc.state.hasError, isFalse);
      expect(bloc.state.conversations.length, 1);
    });

    test('any other error of the sync is shown once and the list keeps working', () async {
      repo.syncFailure = permission();
      bloc.add(ConversationsStarted());
      await settle();
      repo.emitConversations(updateOf([conversationOf('a', 0)]));
      await settle();

      expect(errors.shown, ['You do not have permission to perform this action']);
      expect(bloc.state.hasError, isFalse);
      expect(bloc.state.conversations.length, 1);
    });

    test('a sync failing after close() shows nothing and is not unhandled', () async {
      repo.syncGate = Completer<void>();
      repo.syncFailure = permission();
      bloc.add(ConversationsStarted());
      await settle();

      await bloc.close();
      repo.syncGate!.complete();
      await settle();

      expect(errors.shown, isEmpty);
    });

    test('totalUnread is the sum of unreadCount', () async {
      bloc.add(ConversationsStarted());
      await settle();
      repo.emitConversations(
        updateOf([conversationOf('a', 2), conversationOf('b', 0), conversationOf('c', 3)]),
      );
      await settle();
      expect(bloc.state.totalUnread, 5);

      repo.emitConversations(updateOf([conversationOf('a', 0)]));
      await settle();
      expect(bloc.state.totalUnread, 0);
    });
  });

  group('no user', () {
    test('no user and no uid: the error is shown once and nothing subscribes or syncs', () async {
      home.error = AppException(message: 'user has logged out', type: ErrorType.auth);
      repo.errors['currentUserId'] = AppException(
        message: 'User not logged in',
        type: ErrorType.auth,
      );
      bloc.add(ConversationsStarted());
      await settle();

      expect(errors.shown, ['user has logged out']);
      expect(repo.callCount('watchConversations'), 0);
      expect(repo.callCount('syncPublicProfile'), 0);
      expect(bloc.state.hasError, isTrue);
      expect(bloc.state.isLoading, isFalse);
    });

    test('a uid from the auth session still subscribes; the sync is skipped', () async {
      home.error = network();
      bloc.add(ConversationsStarted());
      await settle();

      expect(errors.shown, ['Service temporarily unavailable']);
      expect(repo.callCount('watchConversations'), 1);
      expect(repo.callCount('syncPublicProfile'), 0);
      expect(bloc.state.hasError, isFalse);

      repo.emitConversations(updateOf([conversationOf('a', 1)]));
      await settle();
      expect(bloc.state.conversations.length, 1);
    });

    test('an empty uid counts as no uid', () async {
      home.error = network();
      repo.uid = '';
      bloc.add(ConversationsStarted());
      await settle();

      expect(repo.callCount('watchConversations'), 0);
      expect(bloc.state.hasError, isTrue);
    });

    test('Retry without a uid repeats GetCurrentUser, then subscribes and runs the skipped sync', () async {
      home.error = network();
      repo.errors['currentUserId'] = AppException(
        message: 'User not logged in',
        type: ErrorType.auth,
      );
      bloc.add(ConversationsStarted());
      await settle();
      expect(repo.callCount('watchConversations'), 0);

      home.error = null;
      repo.errors.remove('currentUserId');
      bloc.add(ConversationsRetried());
      await settle();

      expect(home.calls, 2);
      expect(repo.callCount('watchConversations'), 1);
      expect(repo.calls['syncPublicProfile'], [
        ['Alice Buyer'],
      ]);
      expect(bloc.state.hasError, isFalse);
    });

    test('Retry that fails again still subscribes to nothing', () async {
      home.error = network();
      repo.errors['currentUserId'] = AppException(
        message: 'User not logged in',
        type: ErrorType.auth,
      );
      bloc.add(ConversationsStarted());
      await settle();
      bloc.add(ConversationsRetried());
      await settle();

      expect(home.calls, 2);
      expect(errors.shown.length, 2);
      expect(repo.callCount('watchConversations'), 0);
      expect(bloc.state.hasError, isTrue);
      expect(bloc.state.isLoading, isFalse);
    });

    test('two quick retries make one attempt', () async {
      home.error = network();
      repo.errors['currentUserId'] = AppException(
        message: 'User not logged in',
        type: ErrorType.auth,
      );
      bloc.add(ConversationsStarted());
      await settle();

      home.error = null;
      repo.errors.remove('currentUserId');
      bloc.add(ConversationsRetried());
      bloc.add(ConversationsRetried());
      await settle();

      expect(home.calls, 2);
      expect(repo.callCount('watchConversations'), 1);
      expect(repo.callCount('syncPublicProfile'), 1);
    });

    test('after a session-uid start, Retry on a stream failure runs the skipped sync', () async {
      home.error = network();
      bloc.add(ConversationsStarted());
      await settle();
      repo.conversationStreams.last.addError(network());
      await settle();

      home.error = null;
      bloc.add(ConversationsRetried());
      await settle();

      expect(repo.callCount('watchConversations'), 2);
      expect(repo.callCount('syncPublicProfile'), 1);
    });
  });

  group('stream', () {
    test('a stream AppException is shown and sets hasError', () async {
      bloc.add(ConversationsStarted());
      await settle();
      repo.conversationStreams.last.addError(permission());
      await settle();

      expect(errors.shown, ['You do not have permission to perform this action']);
      expect(bloc.state.hasError, isTrue);
      expect(bloc.state.isLoading, isFalse);
    });

    test('stream done (sign-out) shows no error', () async {
      bloc.add(ConversationsStarted());
      await settle();
      await repo.closeConversations();
      await settle();

      expect(errors.shown, isEmpty);
      expect(bloc.state.hasError, isFalse);
    });

    test('Retry after a stream failure re-subscribes once and does not repeat the sync', () async {
      bloc.add(ConversationsStarted());
      await settle();
      repo.conversationStreams.last.addError(network());
      await settle();

      bloc.add(ConversationsRetried());
      bloc.add(ConversationsRetried());
      await settle();

      expect(repo.callCount('watchConversations'), 2);
      expect(repo.callCount('syncPublicProfile'), 1);
      expect(home.calls, 1);

      repo.emitConversations(updateOf([conversationOf('a', 0)]));
      await settle();
      expect(bloc.state.hasError, isFalse);
    });

    test('ConversationsRetried while subscribed does nothing', () async {
      bloc.add(ConversationsStarted());
      await settle();
      bloc.add(ConversationsRetried());
      await settle();

      expect(repo.callCount('watchConversations'), 1);
    });

    test('close() cancels the subscription', () async {
      bloc.add(ConversationsStarted());
      await settle();
      expect(repo.conversationStreams.single.hasListener, isTrue);

      await bloc.close();

      expect(repo.conversationStreams.single.hasListener, isFalse);
    });
  });

  group('delete', () {
    test('ConversationDeletePressed calls DeleteConversation', () async {
      bloc.add(ConversationsStarted());
      await settle();
      bloc.add(ConversationDeletePressed('alice_seller'));
      await settle();

      expect(repo.calls['deleteConversation'], [
        ['alice_seller'],
      ]);
    });

    test('the list does not change locally: it follows the stream', () async {
      bloc.add(ConversationsStarted());
      await settle();
      repo.emitConversations(updateOf([conversationOf('alice_seller', 2)]));
      await settle();

      bloc.add(ConversationDeletePressed('alice_seller'));
      await settle();
      expect(bloc.state.conversations.length, 1);

      repo.emitConversations(updateOf(const []));
      await settle();
      expect(bloc.state.conversations, isEmpty);
      expect(bloc.state.totalUnread, 0);
    });

    test('an error is shown and the list stays', () async {
      bloc.add(ConversationsStarted());
      await settle();
      repo.emitConversations(updateOf([conversationOf('alice_seller', 2)]));
      await settle();
      repo.errors['deleteConversation'] = network();
      bloc.add(ConversationDeletePressed('alice_seller'));
      await settle();

      expect(errors.shown, ['Service temporarily unavailable']);
      expect(bloc.state.conversations.length, 1);
      expect(bloc.state.hasError, isFalse);
    });

    test('it is ignored while offline', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = buildBloc(r, FakeHomeRepository(), RecordingErrorCubit());
        b.add(ConversationsStarted());
        async.flushMicrotasks();
        r.emitConversations(updateOf([conversationOf('a', 0)], isFromCache: true));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        expect(b.state.isOffline, isTrue);

        b.add(ConversationDeletePressed('a'));
        async.flushMicrotasks();

        expect(r.callCount('deleteConversation'), 0);
        b.close();
        async.flushMicrotasks();
      });
    });
  });

  group('offline', () {
    ConversationsBloc openFromCache(FakeChatRepository r, FakeAsync async) {
      final b = buildBloc(r, FakeHomeRepository(), RecordingErrorCubit());
      b.add(ConversationsStarted());
      async.flushMicrotasks();
      r.emitConversations(updateOf([conversationOf('a', 0)], isFromCache: true));
      async.flushMicrotasks();
      return b;
    }

    test('cached data followed by server data within 2 s never sets isOffline', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = openFromCache(r, async);

        async.elapse(const Duration(milliseconds: 1999));
        expect(b.state.isOffline, isFalse);
        r.emitConversations(updateOf([conversationOf('a', 0)]));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(b.state.isOffline, isFalse);
        b.close();
        async.flushMicrotasks();
      });
    });

    test('only cached data for 2 s sets it, and server data clears it at once', () {
      fakeAsync((async) {
        final r = FakeChatRepository();
        final b = openFromCache(r, async);

        async.elapse(const Duration(seconds: 2));
        expect(b.state.isOffline, isTrue);

        r.emitConversations(updateOf([conversationOf('a', 0)]));
        async.flushMicrotasks();
        expect(b.state.isOffline, isFalse);
        b.close();
        async.flushMicrotasks();
      });
    });

    test('close() leaves no pending timer', () {
      fakeAsync((async) {
        final b = openFromCache(FakeChatRepository(), async);

        b.close();
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
