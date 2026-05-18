import 'package:car_shop/models/car_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CarsPage {
  final List<CarModel> cars;
  final DocumentSnapshot? lastDoc;
  final bool hasReachedEnd;

  CarsPage({
    required this.cars,
    required this.lastDoc,
    required this.hasReachedEnd,
  });
}
