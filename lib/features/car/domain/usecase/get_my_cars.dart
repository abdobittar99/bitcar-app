import 'package:car_shop/entities/car.dart';
import 'package:car_shop/features/car/domain/repositories/cars_repository.dart';

class GetMyCars {
  final CarsRepository repo;
  GetMyCars(this.repo);

  Future<List<CarEntity>> call(String uid) => repo.getMyCars(uid);
}
