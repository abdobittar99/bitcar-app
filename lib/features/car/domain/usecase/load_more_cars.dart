import 'package:car_shop/features/car/domain/model/cars_page.dart';
import 'package:car_shop/features/car/domain/repositories/cars_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoadMoreCars {
  final CarsRepository repo;

  LoadMoreCars(this.repo);

  Future<CarsPage> call(DocumentSnapshot lastDoc) =>
      repo.loadMoreCars(lastDoc: lastDoc);
}
