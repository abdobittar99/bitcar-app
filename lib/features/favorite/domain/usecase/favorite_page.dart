import 'package:car_shop/features/favorite/domain/model/favorite_page.dart';
import 'package:car_shop/features/favorite/domain/repositories/favorite_repository.dart';

class GetFavoritesPage {
  final FavoriteRepository repo;
  GetFavoritesPage(this.repo);

  Future<FavoritePage> call(int page, int limit) {
    return repo.getFavoritesPage(page: page, limit: limit);
  }
}
