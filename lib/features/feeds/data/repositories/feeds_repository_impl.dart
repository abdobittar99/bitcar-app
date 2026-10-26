import 'package:car_shop/entities/ad.dart';
import 'package:car_shop/models/ad_model.dart';
import 'package:car_shop/features/feeds/data/datasource/feeds_remote_datasource.dart';
import 'package:car_shop/features/feeds/domain/repositories/feeds_repository.dart';

class FeedsRepositoryImpl implements FeedsRepository {
  final FeedsRemoteDataSource remote;

  FeedsRepositoryImpl(this.remote);

  @override
  Future<List<AdEntity>> getAds() async {
    return await remote.getAds();
  }

  @override
  Future<void> addAd(AdEntity ad) async {
    final model = AdModel.fromEntity(ad);

    await remote.addAd(model);
  }

  @override
  Future<void> deleteAd(String adId) {
    return remote.deleteAd(adId);
  }
}
