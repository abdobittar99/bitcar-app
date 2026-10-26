import 'package:car_shop/entities/car.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CarsState {
  final bool isLoading;
  final List<CarEntity> cars;
  final String? error;
  final bool isSuccess;
  final bool isLoadingMore;
  final bool hasReachedEnd;
  final DocumentSnapshot? lastDoc;
  final bool isDeleted;
  final String deletedCarId;

  const CarsState({
    this.isLoading = true,
    this.cars = const [],
    this.error,
    this.isSuccess = false,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.lastDoc,
    this.isDeleted = false,
    this.deletedCarId = '',
  });

  CarsState copyWith({
    bool? isLoading,
    List<CarEntity>? cars,
    String? error,
    bool? isSuccess,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    DocumentSnapshot? lastDoc,
    bool? isDeleted,
    String? deletedCarId,
  }) {
    return CarsState(
      isLoading: isLoading ?? this.isLoading,
      cars: cars ?? this.cars,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      lastDoc: lastDoc ?? this.lastDoc,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedCarId: deletedCarId ?? this.deletedCarId,
    );
  }
}
