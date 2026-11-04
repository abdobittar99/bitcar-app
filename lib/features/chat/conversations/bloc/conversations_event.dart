abstract class ConversationsEvent {}

class ConversationsStarted extends ConversationsEvent {}

// One-sided delete, after the user confirmed (FR-027a).
class ConversationDeletePressed extends ConversationsEvent {
  final String conversationId;
  ConversationDeletePressed(this.conversationId);
}

// Retry button of the list error state.
class ConversationsRetried extends ConversationsEvent {}
