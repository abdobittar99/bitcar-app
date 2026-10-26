import 'package:car_shop/entities/ad.dart';
import 'package:car_shop/features/feeds/domain/repositories/feeds_repository.dart';

class AddAd {
  final FeedsRepository repo;

  AddAd(this.repo);

  Future<void> call(AdEntity ad) async {
    await repo.addAd(ad);
  }
}
