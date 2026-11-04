import 'package:car_shop/entities/car.dart';

abstract class ChatEvent {}

class ChatStarted extends ChatEvent {
  final String? otherUserId;
  final String? conversationId;
  final String draft;

  // Opened from a car's details page: the input is pre-filled with the inquiry (FR-007, FR-050).
  ChatStarted.fromCar(CarEntity car)
    : otherUserId = car.sellerId,
      conversationId = null,
      draft = inquiryFor(car);

  // Opened from the conversations list: the input is empty (FR-009).
  ChatStarted.fromConversation(String this.conversationId)
    : otherUserId = null,
      draft = '';

  static String inquiryFor(CarEntity car) =>
      "Hello, I'm interested in your ${car.brand} ${car.model} (${car.year}). "
      'Is it still available?';
}

class ChatMessageSubmitted extends ChatEvent {
  final String text;
  ChatMessageSubmitted(this.text);
}

// Re-sends a failed message with the same id, so it is never duplicated (FR-014).
class ChatMessageRetried extends ChatEvent {
  final String messageId;
  ChatMessageRetried(this.messageId);
}

// Delete for everyone, after the user confirmed (FR-027, FR-047).
class ChatMessageDeletePressed extends ChatEvent {
  final String messageId;
  ChatMessageDeletePressed(this.messageId);
}

// From the app lifecycle: messages are marked read only while the chat is on screen.
class ChatVisibilityChanged extends ChatEvent {
  final bool isVisible;
  ChatVisibilityChanged(this.isVisible);
}

// The list reached the top, or the user tapped Retry on the top row (FR-038, FR-043).
class ChatLoadOlderRequested extends ChatEvent {}

// Retry button or the single automatic retry after a live window failure (FR-054).
class ChatRetried extends ChatEvent {}
