import 'package:car_shop/entities/ad.dart';

abstract class FeedsEvent {}

class LoadAds extends FeedsEvent {}

class AddAdPressed extends FeedsEvent {
  final AdEntity ad;

  AddAdPressed(this.ad);
}

class DeleteAdPressed extends FeedsEvent {
  final String adId;
  DeleteAdPressed(this.adId);
}

class LoadLatestCars extends FeedsEvent {}
