import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/domain/repositories/cars_repository.dart';

class GetCarDetails {
  final CarsRepository repo;

  GetCarDetails(this.repo);

  Future<CarEntity> call(String carId) => repo.getCarById(carId);
}
