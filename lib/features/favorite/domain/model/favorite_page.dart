import 'package:car_shop/entities/car.dart';

class FavoritePage {
  final List<CarEntity> cars;
  final bool hasMore;

  FavoritePage({required this.cars, required this.hasMore});
}
