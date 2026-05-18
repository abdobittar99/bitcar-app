import 'package:car_shop/modules/feeds/domian/repository/feeds_repository.dart';

class DeleteAd {
  final FeedsRepository repo;
  DeleteAd(this.repo);

  Future<void> call(String id) => repo.deleteAd(id);
}
