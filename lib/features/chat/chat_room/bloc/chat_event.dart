import 'package:car_shop/entities/car.dart';

abstract class ChatEvent {}

class ChatStarted extends ChatEvent {
  final String otherUserId;
  final String draft;

  // Opened from a car's details page: the input is pre-filled with the inquiry (FR-007, FR-050).
  ChatStarted.fromCar(CarEntity car)
    : otherUserId = car.sellerId,
      draft = inquiryFor(car);

  static String inquiryFor(CarEntity car) =>
      "Hello, I'm interested in your ${car.brand} ${car.model} (${car.year}). "
      'Is it still available?';
}

class ChatMessageSubmitted extends ChatEvent {
  final String text;
  ChatMessageSubmitted(this.text);
}
