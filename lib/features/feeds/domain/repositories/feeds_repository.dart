import 'package:car_shop/entities/ad.dart';

abstract class FeedsRepository {
  Future<List<AdEntity>> getAds();
  Future<void> addAd(AdEntity ad);
  Future<void> deleteAd(String adId);
}
