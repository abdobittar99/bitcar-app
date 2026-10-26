import 'package:car_shop/entities/car.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchResult {
  final List<CarEntity> cars;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const SearchResult({
    required this.cars,
    required this.lastDoc,
    required this.hasMore,
  });
}
