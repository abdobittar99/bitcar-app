import 'package:car_shop/entities/ad.dart';
import 'package:car_shop/entities/car.dart';

class FeedsState {
  final List<CarEntity> cars;
  final List<AdEntity> ads;
  final bool isLoading;
  final bool isSuccess;
  final bool isAdLoading;
  final String? error;
  final String deletedAdId;

  const FeedsState({
    this.cars = const [],
    this.ads = const [],
    this.isAdLoading = false,
    this.isLoading = true,
    this.isSuccess = false,
    this.error,
    this.deletedAdId = '',
  });

  FeedsState copyWith({
    List<CarEntity>? cars,
    List<AdEntity>? ads,
    bool? isLoading,
    bool? isAdLoading,
    bool? isSuccess,
    String? error,
    String? deletedAdId,
  }) {
    return FeedsState(
      cars: cars ?? this.cars,
      ads: ads ?? this.ads,
      isLoading: isLoading ?? this.isLoading,
      isAdLoading: isAdLoading ?? this.isAdLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      deletedAdId: deletedAdId ?? this.deletedAdId,
    );
  }
}
