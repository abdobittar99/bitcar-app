import 'package:car_shop/core/utils/image_diff.dart';
import 'package:car_shop/modules/car/car_list/domain/repositories/cars_repository.dart';

class UpdateCarDetails {
  final CarsRepository repo;
  UpdateCarDetails(this.repo);

  Future<void> call(String id, Map<String, dynamic> data,ImageDiff diff) =>
      repo.updateCarDetails(id, data, diff);
}
