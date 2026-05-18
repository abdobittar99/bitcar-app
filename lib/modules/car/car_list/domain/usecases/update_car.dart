import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/car_list/domain/repositories/cars_repository.dart';

class UpdateCar {
  final CarsRepository repo;
  UpdateCar(this.repo);

  Future<void> call(CarEntity car) => repo.updateCar(car);
}
