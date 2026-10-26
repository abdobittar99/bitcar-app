import 'package:car_shop/features/favorite/domain/repositories/favorite_repository.dart';

class RefreshFavorites {
  final FavoriteRepository repo;
  RefreshFavorites(this.repo);

  Future<void> call() {
    return repo.refresh();
  }
}
