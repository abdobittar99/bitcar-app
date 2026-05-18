import 'package:car_shop/entities/ad.dart';
import 'package:car_shop/modules/feeds/domian/repository/feeds_repository.dart';

class GetAds {
  final FeedsRepository repo;

  GetAds(this.repo);

  Future<List<AdEntity>> call() async {
    return await repo.getAds();
  }
}
