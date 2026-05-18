import 'package:car_shop/modules/car/car_list/domain/repositories/cars_repository.dart';

class DeleteCar {
  final CarsRepository repo;
  DeleteCar(this.repo);

  Future<void> call(String id) => repo.deleteCar(id);
}
