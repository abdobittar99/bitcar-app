import 'package:car_shop/entities/car.dart';

class CarDetailsState {
  final bool isLoading;
  final CarEntity? car;
  final String? error;

  const CarDetailsState({this.isLoading = false, this.car, this.error});

  CarDetailsState copyWith({bool? isLoading, CarEntity? car, String? error}) {
    return CarDetailsState(
      isLoading: isLoading ?? this.isLoading,
      car: car ?? this.car,
      error: error,
    );
  }
}
