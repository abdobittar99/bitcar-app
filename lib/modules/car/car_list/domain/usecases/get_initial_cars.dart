import 'package:car_shop/modules/car/car_list/domain/model/cars_page.dart';
import 'package:car_shop/modules/car/car_list/domain/repositories/cars_repository.dart';

class GetInitialCars {
  final CarsRepository repo;
  GetInitialCars(this.repo);

  Future<CarsPage> call() => repo.getInitialCars();
}
