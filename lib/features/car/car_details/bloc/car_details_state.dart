import 'package:car_shop/entities/car.dart';

class CarDetailsState {
  final bool isLoading;
  final CarEntity? car;
  final String? error;
  final String? currentUserId;

  const CarDetailsState({
    this.isLoading = false,
    this.car,
    this.error,
    this.currentUserId,
  });

  CarDetailsState copyWith({
    bool? isLoading,
    CarEntity? car,
    String? error,
    String? currentUserId,
  }) {
    return CarDetailsState(
      isLoading: isLoading ?? this.isLoading,
      car: car ?? this.car,
      error: error,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}
