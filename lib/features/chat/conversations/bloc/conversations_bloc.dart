import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_event.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_state.dart';
import 'package:car_shop/features/chat/domain/model/conversations_update.dart';
import 'package:car_shop/features/chat/domain/usecase/delete_conversation.dart';
import 'package:car_shop/features/chat/domain/usecase/get_current_user_id.dart';
import 'package:car_shop/features/chat/domain/usecase/sync_public_profile.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_conversations.dart';
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  final GetCurrentUser getCurrentUser;
  final GetCurrentUserId getCurrentUserId;
  final SyncPublicProfile syncPublicProfile;
  final WatchConversations watchConversations;
  final DeleteConversation deleteConversation;
  final AppErrorCubit appErrorCubit;

  static const offlineBannerDelay = Duration(seconds: 2);

  StreamSubscription<ConversationsUpdate>? _conversationsSub;
  // Events of a cancelled subscription carry an old generation and are ignored.
  int _generation = 0;
  Timer? _offlineTimer;
  ConversationsUpdate? _lastUpdate;
  bool _connecting = false;
  bool _hasUid = false;
  // The public name sync needs the name from GetCurrentUser (research D14, sync point 1).
  bool _syncStarted = false;

  ConversationsBloc({
    required this.getCurrentUser,
    required this.getCurrentUserId,
    required this.syncPublicProfile,
    required this.watchConversations,
    required this.deleteConversation,
    required this.appErrorCubit,
  }) : super(const ConversationsState()) {
    on<ConversationsStarted>((event, emit) => _connect(emit));
    on<ConversationsRetried>((event, emit) => _connect(emit));
    on<ConversationDeletePressed>(_onDeletePressed);
    on<_ConversationsUpdated>(_onUpdated);
    on<_ConversationsFailed>(_onFailed);
    on<_OfflineDelayElapsed>(_onOfflineDelayElapsed);
  }

  // The list changes through the stream once the server accepts the delete.
  Future<void> _onDeletePressed(
    ConversationDeletePressed event,
    Emitter<ConversationsState> emit,
  ) async {
    if (state.isOffline) return;
    try {
      await deleteConversation(event.conversationId);
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
    }
  }

  // Subscribes only with a valid uid; nothing here waits for the sync.
  Future<void> _connect(Emitter<ConversationsState> emit) async {
    if (_connecting || _conversationsSub != null) return;
    _connecting = true;
    emit(state.copyWith(isLoading: true, hasError: false));
    try {
      final name = _syncStarted ? null : await _loadUserName();
      if (isClosed) return;
      _hasUid = _hasUid || _sessionHasUid();
      if (!_hasUid) {
        emit(state.copyWith(isLoading: false, hasError: true));
        return;
      }
      _subscribe();
      if (name != null) {
        _syncStarted = true;
        unawaited(_syncName(name));
      }
    } finally {
      _connecting = false;
    }
  }

  // Null when the user could not be loaded: the error is shown and the sync waits for the next
  // ConversationsRetried or app open.
  Future<String?> _loadUserName() async {
    try {
      final user = await getCurrentUser();
      if (user.id.isEmpty) return null;
      _hasUid = true;
      return user.fullName;
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      return null;
    }
  }

  // The auth session can still give a uid when the user document could not be read. Without one
  // the failure that brought us here is already shown.
  bool _sessionHasUid() {
    try {
      return getCurrentUserId().isNotEmpty;
    } on AppException {
      return false;
    }
  }

  // Best effort and never waited for. A connection error is repeated by the next app open, so
  // it is not shown; after close() the user has left and nothing is shown.
  Future<void> _syncName(String name) async {
    try {
      await syncPublicProfile(name);
    } on AppException catch (e) {
      if (isClosed || e.type == ErrorType.network) return;
      appErrorCubit.showError(e.message);
    }
  }

  // Data and errors are forwarded as events; the listener never emits directly.
  // A stream that completes (session ended, research D18) is not an error.
  void _subscribe() {
    _conversationsSub?.cancel();
    final generation = ++_generation;
    _conversationsSub = watchConversations().listen(
      (update) => add(_ConversationsUpdated(update, generation)),
      onError: (Object error) => add(_ConversationsFailed(error, generation)),
    );
  }

  void _onUpdated(
    _ConversationsUpdated event,
    Emitter<ConversationsState> emit,
  ) {
    if (event.generation != _generation) return;
    final update = event.update;
    _lastUpdate = update;

    // Firestore delivers cached data first even when online, so the offline banner waits to see
    // whether server data follows (FR-014b).
    if (update.isFromCache) {
      _offlineTimer ??= Timer(offlineBannerDelay, () {
        if (!isClosed) add(_OfflineDelayElapsed());
      });
    } else {
      _offlineTimer?.cancel();
      _offlineTimer = null;
    }

    emit(
      state.copyWith(
        isLoading: false,
        hasError: false,
        isOffline: update.isFromCache ? null : false,
        conversations: update.conversations,
        totalUnread: update.conversations.fold<int>(
          0,
          (sum, c) => sum + c.unreadCount,
        ),
      ),
    );
  }

  void _onOfflineDelayElapsed(
    _OfflineDelayElapsed event,
    Emitter<ConversationsState> emit,
  ) {
    _offlineTimer = null;
    if (_lastUpdate?.isFromCache ?? false) {
      emit(state.copyWith(isOffline: true));
    }
  }

  void _onFailed(_ConversationsFailed event, Emitter<ConversationsState> emit) {
    if (event.generation != _generation) return;
    // An error is terminal for the listener.
    _conversationsSub?.cancel();
    _conversationsSub = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;

    final error = event.error;
    appErrorCubit.showError(
      error is AppException
          ? error.message
          : 'Something went wrong, please try again',
    );
    emit(state.copyWith(isLoading: false, hasError: true));
  }

  @override
  Future<void> close() {
    _offlineTimer?.cancel();
    _conversationsSub?.cancel();
    return super.close();
  }
}

class _ConversationsUpdated extends ConversationsEvent {
  final ConversationsUpdate update;
  final int generation;
  _ConversationsUpdated(this.update, this.generation);
}

class _ConversationsFailed extends ConversationsEvent {
  final Object error;
  final int generation;
  _ConversationsFailed(this.error, this.generation);
}

class _OfflineDelayElapsed extends ConversationsEvent {}
