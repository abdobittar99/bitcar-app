import 'package:car_shop/entities/car.dart';

abstract class MyCarsEvent {}

class MyCarsStarted extends MyCarsEvent {}

class MyCarsRefreshed extends MyCarsEvent {}

class MyCarDeletedLocally extends MyCarsEvent {
  final String carId;
  MyCarDeletedLocally(this.carId);
}

class DeleteMyCarPressed extends MyCarsEvent {
  final String carId;
  DeleteMyCarPressed(this.carId);
}

class MyCarsReloaded extends MyCarsEvent {}

class MyCarUpdateLocally extends MyCarsEvent {
  final CarEntity updatedCar;

  MyCarUpdateLocally(this.updatedCar);
}

class ClearMycars extends MyCarsEvent {}
