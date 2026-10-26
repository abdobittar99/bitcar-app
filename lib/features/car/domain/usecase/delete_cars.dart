import 'package:car_shop/features/car/domain/repositories/cars_repository.dart';

class DeleteCar {
  final CarsRepository repo;
  DeleteCar(this.repo);

  Future<void> call(String id) => repo.deleteCar(id);
}
