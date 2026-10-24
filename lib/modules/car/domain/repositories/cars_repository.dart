import 'package:car_shop/core/utils/image_diff.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/domain/model/cars_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class CarsRepository {
  Future<CarsPage> loadMoreCars({required DocumentSnapshot lastDoc});
  Future<CarsPage> getInitialCars();
  Future<void> updateCar(CarEntity car);
  Future<void> updateCarDetails(
    String id,
    Map<String, dynamic> data,
    ImageDiff diff,
  );
  Future<List<CarEntity>> getMyCars(String userId);
  Future<void> deleteCar(String carId);
  Future<void> addCar(CarEntity car);
  Future<CarEntity> getCarById(String id);
}
