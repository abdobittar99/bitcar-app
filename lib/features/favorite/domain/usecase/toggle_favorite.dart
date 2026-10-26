import 'package:car_shop/features/favorite/domain/repositories/favorite_repository.dart';

class ToggleFavorite {
  final FavoriteRepository repo;
  ToggleFavorite(this.repo);

  Future<void> call(String id) {
    return repo.toggleFavorite(id);
  }
}
