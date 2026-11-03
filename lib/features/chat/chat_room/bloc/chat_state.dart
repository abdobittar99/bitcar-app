import 'package:car_shop/entities/message.dart';
import 'package:car_shop/features/chat/domain/model/chat_target.dart';
import 'package:car_shop/features/chat/domain/model/message_cursor.dart';

enum ChatStreamStatus { live, retrying, failedRetryable, failedFatal }

class ChatState {
  final bool isLoading;
  final bool isOffline;
  final ChatTarget? target;
  // Id-keyed sources of the displayed list (research D17): the current live window,
  // messages loaded once (older batches and messages that left the window), and local sends.
  final Map<String, MessageEntity> liveMessages;
  final Map<String, MessageEntity> loadedMessages;
  final Map<String, MessageEntity> pendingMessages;
  final DateTime? otherLastReadAt;
  final String draft;
  final MessageCursor? oldestCursor;
  final bool hasOlder;
  final bool isLoadingOlder;
  final bool olderLoadFailed;
  final bool olderBatchIncomplete;
  final bool isVisible;
  final String? currentUserId;
  final ChatStreamStatus streamStatus;
  final bool autoRetryUsed;

  const ChatState({
    this.isLoading = false,
    this.isOffline = false,
    this.target,
    this.liveMessages = const {},
    this.loadedMessages = const {},
    this.pendingMessages = const {},
    this.otherLastReadAt,
    this.draft = '',
    this.oldestCursor,
    this.hasOlder = false,
    this.isLoadingOlder = false,
    this.olderLoadFailed = false,
    this.olderBatchIncomplete = false,
    this.isVisible = true,
    this.currentUserId,
    this.streamStatus = ChatStreamStatus.live,
    this.autoRetryUsed = false,
  });

  // New conversation: it does not exist yet and nothing has been sent (FR-004).
  bool get isNewConversation =>
      target != null && !target!.exists && messages.isEmpty;

  // Union by id (live > loaded > pending), server messages sorted by (createdAt, id),
  // local pending/failed messages last in the order they were sent (FR-039, FR-040).
  List<MessageEntity> get messages {
    final byId = <String, MessageEntity>{
      ...pendingMessages,
      ...loadedMessages,
      ...liveMessages,
    };
    final confirmed = byId.values.where((m) => m.createdAt != null).toList()
      ..sort((a, b) {
        final byTime = a.createdAt!.compareTo(b.createdAt!);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final local = pendingMessages.keys
        .where((id) => !liveMessages.containsKey(id) && !loadedMessages.containsKey(id))
        .map((id) => pendingMessages[id]!);
    final unconfirmedServer = byId.values.where(
      (m) => m.createdAt == null && !pendingMessages.containsKey(m.id),
    );
    return [...confirmed, ...unconfirmedServer, ...local];
  }

  ChatState copyWith({
    bool? isLoading,
    bool? isOffline,
    ChatTarget? target,
    Map<String, MessageEntity>? liveMessages,
    Map<String, MessageEntity>? loadedMessages,
    Map<String, MessageEntity>? pendingMessages,
    DateTime? otherLastReadAt,
    String? draft,
    MessageCursor? oldestCursor,
    bool? hasOlder,
    bool? isLoadingOlder,
    bool? olderLoadFailed,
    bool? olderBatchIncomplete,
    bool? isVisible,
    String? currentUserId,
    ChatStreamStatus? streamStatus,
    bool? autoRetryUsed,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      target: target ?? this.target,
      liveMessages: liveMessages ?? this.liveMessages,
      loadedMessages: loadedMessages ?? this.loadedMessages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      otherLastReadAt: otherLastReadAt ?? this.otherLastReadAt,
      draft: draft ?? this.draft,
      oldestCursor: oldestCursor ?? this.oldestCursor,
      hasOlder: hasOlder ?? this.hasOlder,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      olderLoadFailed: olderLoadFailed ?? this.olderLoadFailed,
      olderBatchIncomplete: olderBatchIncomplete ?? this.olderBatchIncomplete,
      isVisible: isVisible ?? this.isVisible,
      currentUserId: currentUserId ?? this.currentUserId,
      streamStatus: streamStatus ?? this.streamStatus,
      autoRetryUsed: autoRetryUsed ?? this.autoRetryUsed,
    );
  }
}
