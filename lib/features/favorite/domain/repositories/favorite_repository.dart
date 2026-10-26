import 'package:car_shop/features/favorite/domain/model/favorite_page.dart';

abstract class FavoriteRepository {
  Future<FavoritePage> getFavoritesPage({
    required int page,
    required int limit,
  });

  Future<void> toggleFavorite(String carId);

  Future<void> refresh();
  Future<Set<String>> getFavoriteIds();
}
