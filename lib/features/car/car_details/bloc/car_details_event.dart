abstract class CarDetailsEvent {}

class CarDetailsStarted extends CarDetailsEvent {
  final String carId;
  CarDetailsStarted(this.carId);
}
