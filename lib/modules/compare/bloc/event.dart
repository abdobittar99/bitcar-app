import 'package:car_shop/entities/car.dart';

abstract class CompareEvent {}

class SelectFirstCar extends CompareEvent {
  final CarEntity car;
  SelectFirstCar(this.car);
}

class SelectSecondCar extends CompareEvent {
  final CarEntity car;
  SelectSecondCar(this.car);
}

class ClearFirstCar extends CompareEvent {}

class ClearSecondCar extends CompareEvent {}

class ResetCompare extends CompareEvent {}
