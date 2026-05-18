import 'package:car_shop/core/utils/image_diff.dart';
import 'package:car_shop/models/car_model.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/car_list/data/datasource/cars_datasource.dart';
import 'package:car_shop/modules/car/car_list/domain/model/cars_page.dart';
import 'package:car_shop/modules/car/car_list/domain/repositories/cars_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CarsRepositoryImpl implements CarsRepository {
  final CarsRemoteDataSource carsDs;

  CarsRepositoryImpl(this.carsDs);
  @override
  Future<CarsPage> getInitialCars() {
    return carsDs.getInitialCars();
  }

  @override
  Future<List<CarEntity>> getMyCars(String uid) {
    return carsDs.getMyCars(uid);
  }

  @override
  Future<CarsPage> loadMoreCars({required DocumentSnapshot lastDoc}) {
    return carsDs.getMoreCars(lastDoc: lastDoc);
  }

  @override
  Future<void> updateCarDetails(
    String id,
    Map<String, dynamic> data,
    ImageDiff diff,
  ) {
    return carsDs.updateCarDetails(id, data, diff);
  }

  @override
  Future<void> updateCar(CarEntity car) {
    final model = CarModel.fromEntity(car);
    return carsDs.updateCar(model);
  }

  @override
  Future<void> addCar(CarEntity car) {
    assert(car.images.isNotEmpty);
    final model = CarModel.fromEntity(car);
    return carsDs.addCar(model);
  }

  @override
  Future<void> deleteCar(String carId) {
    return carsDs.deleteCar(carId);
  }

  @override
  Future<CarEntity> getCarById(String id) {
    return carsDs.getCar(id);
  }
}
