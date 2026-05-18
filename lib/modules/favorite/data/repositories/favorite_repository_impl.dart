import 'package:car_shop/modules/car/car_list/data/datasource/cars_datasource.dart';
import 'package:car_shop/modules/favorite/data/datasources/favorite_remote_datasource.dart';
import 'package:car_shop/modules/favorite/domain/models/favorite_page.dart';
import 'package:car_shop/modules/favorite/domain/repositories/favorite_repository.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  final FavoriteRemoteDataSource favDs;
  final CarsRemoteDataSource carsDs;

  FavoriteRepositoryImpl(this.favDs, this.carsDs);

  Set<String>? _cachedIds;

  @override
  Future<Set<String>> getFavoriteIds() {
    return favDs.getFavoriteIds();
  }

  @override
  Future<FavoritePage> getFavoritesPage({
    required int page,
    required int limit,
  }) async {
    _cachedIds ??= await favDs.getFavoriteIds();

    final start = page * limit;
    final slice = _cachedIds!.skip(start).take(limit).toList();

    if (slice.isEmpty) {
      return FavoritePage(cars: [], hasMore: false);
    }

    final models = await favDs.getFavCarsByIds(slice, favDs.uid);

    final cars = models;

    final hasMore = start + limit < _cachedIds!.length;

    return FavoritePage(cars: cars, hasMore: hasMore);
  }

  @override
  Future<void> toggleFavorite(String carId) async {
    final ids = await favDs.getFavoriteIds();

    if (ids.contains(carId)) {
      await favDs.removeFavorite(carId);
    } else {
      await favDs.addFavorite(carId);
    }
  }

  @override
  Future<void> refresh() async {
    _cachedIds = null;
  }
}
