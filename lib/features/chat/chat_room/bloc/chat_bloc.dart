import 'dart:async';

import 'package:car_shop/core/enums/message_status.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/validators/chat_validator.dart';
import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_event.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_state.dart';
import 'package:car_shop/features/chat/domain/model/messages_update.dart';
import 'package:car_shop/features/chat/domain/usecase/create_message_id.dart';
import 'package:car_shop/features/chat/domain/usecase/get_current_user_id.dart';
import 'package:car_shop/features/chat/domain/usecase/open_chat_with_seller.dart';
import 'package:car_shop/features/chat/domain/usecase/send_message.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_latest_messages.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final OpenChatWithSeller openChatWithSeller;
  final WatchLatestMessages watchLatestMessages;
  final CreateMessageId createMessageId;
  final SendMessage sendMessage;
  final GetCurrentUserId getCurrentUserId;
  final AppErrorCubit appErrorCubit;

  // The only subscription of this bloc: the live window of the open conversation.
  StreamSubscription<MessagesUpdate>? _messagesSub;

  ChatBloc({
    required this.openChatWithSeller,
    required this.watchLatestMessages,
    required this.createMessageId,
    required this.sendMessage,
    required this.getCurrentUserId,
    required this.appErrorCubit,
  }) : super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessageSubmitted>(_onMessageSubmitted);
    on<_MessagesUpdated>(_onMessagesUpdated);
    on<_MessagesFailed>(_onMessagesFailed);
  }

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    // The inquiry always replaces any previous draft (FR-050).
    emit(state.copyWith(isLoading: true, draft: event.draft));
    try {
      final uid = getCurrentUserId();
      final target = await openChatWithSeller(event.otherUserId);
      if (isClosed) return;
      emit(state.copyWith(currentUserId: uid, target: target));
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
    _messagesSub = watchLatestMessages(conversationId).listen(
      (update) => add(_MessagesUpdated(update)),
      onError: (Object error) => add(_MessagesFailed(error)),
    );
  }

  Future<void> _onMessageSubmitted(
    ChatMessageSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    final target = state.target;
    final uid = state.currentUserId;
    if (target == null || uid == null) return;

    final error = ChatValidator.validate(event.text);
    if (error != null) {
      appErrorCubit.showError(error);
      return;
    }

    final text = event.text.trim();
    final id = createMessageId(target.conversationId);
    final pending = MessageEntity(
      id: id,
      conversationId: target.conversationId,
      senderId: uid,
      text: text,
      createdAt: null,
      isDeleted: false,
      status: MessageStatus.sending,
    );
    emit(
      state.copyWith(
        draft: '',
        pendingMessages: {...state.pendingMessages, id: pending},
      ),
    );

    try {
      await sendMessage(
        conversationId: target.conversationId,
        messageId: id,
        otherUserId: target.otherUserId,
        text: text,
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
    }
  }

  void _onMessagesUpdated(_MessagesUpdated event, Emitter<ChatState> emit) {
    final live = {for (final m in event.update.messages) m.id: m};
    // A local message is dropped once the server copy with the same id arrives.
    final pending = Map.of(state.pendingMessages)
      ..removeWhere((id, _) => live.containsKey(id));
    emit(
      state.copyWith(
        isLoading: false,
        liveMessages: live,
        pendingMessages: pending,
        otherLastReadAt: event.update.otherLastReadAt,
      ),
    );
  }

  void _onMessagesFailed(_MessagesFailed event, Emitter<ChatState> emit) {
    // An error is terminal for the live window listener.
    _messagesSub?.cancel();
    _messagesSub = null;
    final error = event.error;
    appErrorCubit.showError(
      error is AppException
          ? error.message
          : 'Something went wrong, please try again',
    );
    emit(state.copyWith(isLoading: false));
  }

  @override
  Future<void> close() {
    _messagesSub?.cancel();
    return super.close();
  }
}

class _MessagesUpdated extends ChatEvent {
  final MessagesUpdate update;
  _MessagesUpdated(this.update);
}

class _MessagesFailed extends ChatEvent {
  final Object error;
  _MessagesFailed(this.error);
}
