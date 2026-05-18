import 'package:car_shop/entities/car.dart';

abstract class FavoriteEvent {}

class FavoriteStarted extends FavoriteEvent {}

class LoadMoreFavorite extends FavoriteEvent {}

class FavoriteToggled extends FavoriteEvent {
  final String carId;
  final CarEntity? car;
  FavoriteToggled({required this.carId, required this.car});
}

class FavDeletedLocally extends FavoriteEvent {
  final String carId;
  FavDeletedLocally(this.carId);
}

class FavCarUpdateLocally extends FavoriteEvent {
  final CarEntity updatedCar;
  FavCarUpdateLocally(this.updatedCar);
}

class ClearFavorite extends FavoriteEvent {}
