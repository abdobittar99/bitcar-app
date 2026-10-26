import 'package:car_shop/entities/car.dart';

abstract class CarsEvent {}

class LoadInitialCars extends CarsEvent {}

class CarsLoadMore extends CarsEvent {}

class RefreshCars extends CarsEvent {}

class CarDeletedLocally extends CarsEvent {
  final String carId;
  CarDeletedLocally(this.carId);
}

class AdminDeleteCarPressed extends CarsEvent {
  final String carId;
  AdminDeleteCarPressed(this.carId);
}

class CarsReloaded extends CarsEvent {}

class CarUpdateLocally extends CarsEvent {
  final CarEntity updatedCar;
  CarUpdateLocally(this.updatedCar);
}

class ClearCars extends CarsEvent {}
