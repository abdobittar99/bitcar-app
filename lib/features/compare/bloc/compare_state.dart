import 'package:car_shop/entities/car.dart';

class CompareState {
  final CarEntity? firstCar;
  final CarEntity? secondCar;

  const CompareState({this.firstCar, this.secondCar});

  bool get isReady => firstCar != null && secondCar != null;

  CompareState copyWith({
    CarEntity? firstCar,
    bool clearFirst = false,
    CarEntity? secondCar,
    bool clearSecond = false,
  }) {
    return CompareState(
      firstCar: clearFirst ? null : (firstCar ?? this.firstCar),
      secondCar: clearSecond ? null : (secondCar ?? this.secondCar),
    );
  }
}
