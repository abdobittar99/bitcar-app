import 'package:car_shop/entities/car.dart';

class MyCarsState {
  final bool isLoading;
  final List<CarEntity> myCars;
  final String? error;
  final bool isSuccess;
  final bool isDeleted;
  final String deletedCarId;

  const MyCarsState({
    this.isLoading = true,
    this.myCars = const [],
    this.error,
    this.isSuccess = false,
    this.isDeleted = false,
    this.deletedCarId = '',
  });
  MyCarsState copyWith({
    bool? isLoading,
    List<CarEntity>? myCars,
    String? error,
    bool? isSuccess,
    bool? isDeleted,
    String? deletedCarId,
  }) {
    return MyCarsState(
      isLoading: isLoading ?? this.isLoading,
      myCars: myCars ?? this.myCars,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error ?? this.error,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedCarId: deletedCarId ?? this.deletedCarId,
    );
  }
}
