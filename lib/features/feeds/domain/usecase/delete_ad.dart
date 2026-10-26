import 'package:car_shop/features/feeds/domain/repositories/feeds_repository.dart';

class DeleteAd {
  final FeedsRepository repo;
  DeleteAd(this.repo);

  Future<void> call(String id) => repo.deleteAd(id);
}
