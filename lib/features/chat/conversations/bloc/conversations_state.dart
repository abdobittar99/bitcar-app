import 'package:car_shop/entities/conversation.dart';

class ConversationsState {
  final bool isLoading;
  final bool hasError;
  final bool isOffline;
  final List<ConversationEntity> conversations;
  final int totalUnread;

  const ConversationsState({
    this.isLoading = false,
    this.hasError = false,
    this.isOffline = false,
    this.conversations = const [],
    this.totalUnread = 0,
  });

  ConversationsState copyWith({
    bool? isLoading,
    bool? hasError,
    bool? isOffline,
    List<ConversationEntity>? conversations,
    int? totalUnread,
  }) {
    return ConversationsState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      isOffline: isOffline ?? this.isOffline,
      conversations: conversations ?? this.conversations,
      totalUnread: totalUnread ?? this.totalUnread,
    );
  }
}
