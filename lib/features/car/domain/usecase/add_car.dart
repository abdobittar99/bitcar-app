import 'package:car_shop/entities/car.dart';
import 'package:car_shop/features/car/domain/repositories/cars_repository.dart';

class AddCar {
  final CarsRepository repo;
  AddCar(this.repo);
  Future<void> call(CarEntity car) => repo.addCar(car);
}
