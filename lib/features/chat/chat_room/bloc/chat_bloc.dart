import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/validators/chat_validator.dart';
import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_event.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_state.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/usecase/create_message_id.dart';
import 'package:car_shop/features/chat/domain/usecase/get_current_user_id.dart';
import 'package:car_shop/features/chat/domain/usecase/load_older_messages.dart';
import 'package:car_shop/features/chat/domain/usecase/mark_conversation_read.dart';
import 'package:car_shop/features/chat/domain/usecase/open_chat_with_seller.dart';
import 'package:car_shop/features/chat/domain/usecase/send_message.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_latest_messages.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final OpenChatWithSeller openChatWithSeller;
  final WatchLatestMessages watchLatestMessages;
  final LoadOlderMessages loadOlderMessages;
  final CreateMessageId createMessageId;
  final SendMessage sendMessage;
  final MarkConversationRead markConversationRead;
  final GetCurrentUserId getCurrentUserId;
  final AppErrorCubit appErrorCubit;
  // Clock for the client rate pre-check; tests pass their own.
  final DateTime Function() now;

  static const autoRetryDelay = Duration(seconds: 3);
  static const offlineBannerDelay = Duration(seconds: 2);
  static const _rateWindow = Duration(seconds: 60);

  // Errors that retrying can fix (FR-054); every other type is fatal for the live window.
  static const _retryableErrors = {
    ErrorType.network,
    ErrorType.firestore,
    ErrorType.unknown,
    ErrorType.platform,
    ErrorType.server,
    ErrorType.cache,
  };

  // The only subscription of this bloc: the live window of the open conversation.
  StreamSubscription<MessagesUpdate>? _messagesSub;
  // Events of a cancelled subscription carry an old generation and are ignored.
  int _generation = 0;
  Timer? _retryTimer;
  Timer? _offlineTimer;
  Future<void> _lastSend = Future.value();
  final List<DateTime> _recentSends = [];
  MessagesUpdate? _lastUpdate;
  bool _windowSettled = false;
  bool _olderLoaded = false;
  bool _markingRead = false;

  ChatBloc({
    required this.openChatWithSeller,
    required this.watchLatestMessages,
    required this.loadOlderMessages,
    required this.createMessageId,
    required this.sendMessage,
    required this.markConversationRead,
    required this.getCurrentUserId,
    required this.appErrorCubit,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessageSubmitted>(_onMessageSubmitted);
    on<ChatMessageRetried>(_onMessageRetried);
    on<ChatVisibilityChanged>(_onVisibilityChanged);
    on<ChatLoadOlderRequested>(_onLoadOlderRequested);
    on<ChatRetried>(_onRetried);
    on<_MessagesUpdated>(_onMessagesUpdated);
    on<_MessagesFailed>(_onMessagesFailed);
    on<_OfflineDelayElapsed>(_onOfflineDelayElapsed);
  }

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    // The inquiry always replaces any previous draft (FR-050).
    emit(state.copyWith(isLoading: true, draft: event.draft));
    try {
      final uid = getCurrentUserId();
      final target = await openChatWithSeller(event.otherUserId);
      if (isClosed) return;
      emit(state.copyWith(currentUserId: uid, target: target));
      _windowSettled = false;
      _olderLoaded = false;
      _subscribe(target.conversationId);
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }

  // Data and errors are forwarded as events; the listener never emits directly.
  // A stream that completes (session ended, research D18) is not an error.
  void _subscribe(String conversationId) {
    _messagesSub?.cancel();
    final generation = ++_generation;
    _messagesSub = watchLatestMessages(conversationId).listen(
      (update) => add(_MessagesUpdated(update, generation)),
      onError: (Object error) => add(_MessagesFailed(error, generation)),
    );
  }

  Future<void> _onMessageSubmitted(
    ChatMessageSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    final target = state.target;
    final uid = state.currentUserId;
    if (!state.canSend || target == null || uid == null) return;

    final error = ChatValidator.validate(event.text);
    if (error != null) {
      appErrorCubit.showError(error);
      return;
    }

    final id = createMessageId(target.conversationId);
    // Over the limit the message is kept as failed and can be retried later (FR-014a).
    final limited = _rateLimited();
    final pending = MessageEntity(
      id: id,
      conversationId: target.conversationId,
      senderId: uid,
      text: event.text.trim(),
      createdAt: null,
      isDeleted: false,
      status: limited ? MessageStatus.failed : MessageStatus.sending,
    );
    emit(
      state.copyWith(
        draft: '',
        pendingMessages: {...state.pendingMessages, id: pending},
        outgoingCount: state.outgoingCount + 1,
      ),
    );
    if (limited) {
      appErrorCubit.showError(ChatValidator.rateLimitMessage);
      return;
    }
    _recentSends.add(now());
    await _deliver(id, emit);
  }

  Future<void> _onMessageRetried(
    ChatMessageRetried event,
    Emitter<ChatState> emit,
  ) async {
    final message = state.pendingMessages[event.messageId];
    if (message == null ||
        message.status != MessageStatus.failed ||
        !state.canSend) {
      return;
    }
    if (_rateLimited()) {
      appErrorCubit.showError(ChatValidator.rateLimitMessage);
      return;
    }
    _recentSends.add(now());
    emit(
      state.copyWith(
        pendingMessages: {
          ...state.pendingMessages,
          message.id: message.copyWith(status: MessageStatus.sending),
        },
        outgoingCount: state.outgoingCount + 1,
      ),
    );
    await _deliver(message.id, emit);
  }

  // Sends a pending message with its own id: a retry never creates a duplicate (FR-014).
  // One send at a time, in the order they were requested: this keeps the order of the messages
  // and stops their transactions from competing. A queued message is still sent if the user
  // leaves the screen, and a failed send does not stop the next one.
  Future<void> _deliver(String id, Emitter<ChatState> emit) async {
    final target = state.target!;
    final message = state.pendingMessages[id]!;
    final previous = _lastSend;
    final done = Completer<void>();
    _lastSend = done.future;
    await previous;
    try {
      await sendMessage(
        conversationId: target.conversationId,
        messageId: id,
        otherUserId: target.otherUserId,
        text: message.text,
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      final current = state.pendingMessages[id];
      if (current == null) return;
      emit(
        state.copyWith(
          pendingMessages: {
            ...state.pendingMessages,
            id: current.copyWith(status: MessageStatus.failed),
          },
        ),
      );
    } finally {
      done.complete();
    }
  }

  // Client pre-check of the rules limit: at most 20 sends in the last 60 s.
  bool _rateLimited() {
    final current = now();
    _recentSends.removeWhere((t) => current.difference(t) >= _rateWindow);
    return _recentSends.length >= ChatValidator.maxMessagesPerMinute;
  }

  Future<void> _onVisibilityChanged(
    ChatVisibilityChanged event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isVisible: event.isVisible));
    if (event.isVisible) await _markReadIfNeeded();
  }

  // Marks all messages read while the chat is on screen (FR-015). Only on server data:
  // changes need a connection (FR-014b), and an already-read conversation is not written.
  Future<void> _markReadIfNeeded() async {
    final update = _lastUpdate;
    final target = state.target;
    if (update == null ||
        target == null ||
        !state.isVisible ||
        update.isFromCache ||
        update.unreadCount == 0 ||
        _markingRead) {
      return;
    }
    _markingRead = true;
    try {
      await markConversationRead(target.conversationId);
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _onLoadOlderRequested(
    ChatLoadOlderRequested event,
    Emitter<ChatState> emit,
  ) async {
    final cursor = state.oldestCursor;
    final target = state.target;
    // One request at a time (FR-042): the flag is set before the first await.
    if (state.isLoadingOlder ||
        !state.hasOlder ||
        cursor == null ||
        target == null) {
      return;
    }
    // The saved messages have run out: asking the cache again returns the same short batch.
    // The next server update requests it again (_onMessagesUpdated).
    if (state.olderBatchIncomplete && (_lastUpdate?.isFromCache ?? true)) return;
    emit(state.copyWith(isLoadingOlder: true, olderLoadFailed: false));

    try {
      final page = await loadOlderMessages(
        target.conversationId,
        cursor,
        after: state.clearedAt,
      );
      _olderLoaded = true;
      // A short batch from the cache only does not end the history; the cursor stays so the
      // same batch is read again from the server (research D17).
      final incomplete =
          page.isFromCache && page.messages.length < messagesPageSize;
      emit(
        state.copyWith(
          isLoadingOlder: false,
          loadedMessages: {
            ...state.loadedMessages,
            for (final m in page.messages) m.id: m,
          },
          hasOlder: page.hasOlder,
          olderBatchIncomplete: incomplete,
          oldestCursor: incomplete ? cursor : _oldestOf(page.messages) ?? cursor,
        ),
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoadingOlder: false, olderLoadFailed: true));
    }
  }

  void _onRetried(ChatRetried event, Emitter<ChatState> emit) {
    final target = state.target;
    if (state.streamStatus != ChatStreamStatus.failedRetryable ||
        _messagesSub != null ||
        target == null) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    emit(state.copyWith(streamStatus: ChatStreamStatus.retrying));
    _subscribe(target.conversationId);
  }

  void _onMessagesUpdated(_MessagesUpdated event, Emitter<ChatState> emit) {
    if (event.generation != _generation) return;
    final update = event.update;
    _lastUpdate = update;

    final live = {for (final m in update.messages) m.id: m};
    // Messages pushed out of the live window stay on screen as loaded-once (research D17).
    final loaded = Map.of(state.loadedMessages);
    for (final m in state.liveMessages.values) {
      if (!live.containsKey(m.id)) loaded[m.id] = m;
    }
    // A local message is dropped once the server copy with the same id arrives.
    final pending = Map.of(state.pendingMessages)
      ..removeWhere((id, _) => live.containsKey(id) || loaded.containsKey(id));

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

    var next = state.copyWith(
      isLoading: false,
      isOffline: update.isFromCache ? null : false,
      liveMessages: live,
      loadedMessages: loaded,
      pendingMessages: pending,
      otherLastReadAt: update.otherLastReadAt,
      clearedAt: update.clearedAt,
      streamStatus: ChatStreamStatus.live,
      clearStreamError: true,
    );
    // Until the first server window, the window decides whether older messages exist
    // (fewer than 20 from the server: none) and where the cursor starts.
    if (!_windowSettled && !_olderLoaded) {
      next = next.copyWith(
        hasOlder:
            update.isFromCache || update.messages.length >= messagesPageSize,
        oldestCursor: _oldestOf(update.messages),
      );
    }
    if (!update.isFromCache) _windowSettled = true;
    emit(next);

    if (state.olderBatchIncomplete && !update.isFromCache) {
      add(ChatLoadOlderRequested());
    }
    _markReadIfNeeded();
  }

  void _onOfflineDelayElapsed(
    _OfflineDelayElapsed event,
    Emitter<ChatState> emit,
  ) {
    _offlineTimer = null;
    if (_lastUpdate?.isFromCache ?? false) {
      emit(state.copyWith(isOffline: true));
    }
  }

  void _onMessagesFailed(_MessagesFailed event, Emitter<ChatState> emit) {
    if (event.generation != _generation) return;
    // An error is terminal for the live window listener.
    _messagesSub?.cancel();
    _messagesSub = null;

    final raw = event.error;
    final error = raw is AppException
        ? raw
        : AppException(
            message: 'Something went wrong, please try again',
            type: ErrorType.unknown,
          );
    appErrorCubit.showError(error.message);

    final retryable = _retryableErrors.contains(error.type);
    final autoRetry = retryable && !state.autoRetryUsed;
    // Nothing disappears: the live window moves into the loaded-once messages.
    emit(
      state.copyWith(
        isLoading: false,
        liveMessages: const <String, MessageEntity>{},
        loadedMessages: {...state.loadedMessages, ...state.liveMessages},
        streamStatus: retryable
            ? ChatStreamStatus.failedRetryable
            : ChatStreamStatus.failedFatal,
        streamError: error.message,
        autoRetryUsed: autoRetry ? true : null,
      ),
    );
    if (autoRetry) {
      _retryTimer?.cancel();
      _retryTimer = Timer(autoRetryDelay, () {
        if (!isClosed) add(ChatRetried());
      });
    }
  }

  // Oldest server-confirmed message: the cursor never points at a local message.
  MessageCursor? _oldestOf(Iterable<MessageEntity> messages) {
    MessageEntity? oldest;
    for (final m in messages) {
      if (m.createdAt == null) continue;
      if (oldest == null) {
        oldest = m;
        continue;
      }
      final byTime = m.createdAt!.compareTo(oldest.createdAt!);
      if (byTime < 0 || (byTime == 0 && m.id.compareTo(oldest.id) < 0)) {
        oldest = m;
      }
    }
    return oldest == null
        ? null
        : MessageCursor(createdAt: oldest.createdAt!, messageId: oldest.id);
  }

  @override
  Future<void> close() {
    _retryTimer?.cancel();
    _offlineTimer?.cancel();
    _messagesSub?.cancel();
    return super.close();
  }
}

class _MessagesUpdated extends ChatEvent {
  final MessagesUpdate update;
  final int generation;
  _MessagesUpdated(this.update, this.generation);
}

class _MessagesFailed extends ChatEvent {
  final Object error;
  final int generation;
  _MessagesFailed(this.error, this.generation);
}

class _OfflineDelayElapsed extends ChatEvent {}
