import 'package:car_shop/modules/favorite/domain/repositories/favorite_repository.dart';

class GetFavoriteIds {
  final FavoriteRepository repo;
  GetFavoriteIds(this.repo);
  Future<Set<String>> call() => repo.getFavoriteIds();
}
