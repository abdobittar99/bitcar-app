import 'dart:async';

import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/car_list/domain/usecases/delete_cars.dart';
import 'package:car_shop/modules/car/car_list/domain/usecases/get_initial_cars.dart';
import 'package:car_shop/modules/car/car_list/domain/usecases/update_car.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_event.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_state.dart';
import 'package:car_shop/modules/car/car_list/domain/usecases/load_more_cars.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CarsBloc extends Bloc<CarsEvent, CarsState> {
  final GetInitialCars getInitialCars;
  final LoadMoreCars loadMoreCars;
  final DeleteCar adminDeleteCar;

  final UpdateCar updateCar;
  final AppErrorCubit appErrorCubit;
  CarsBloc({
    required this.getInitialCars,
    required this.loadMoreCars,
    required this.adminDeleteCar,
    required this.updateCar,
    required this.appErrorCubit,
  }) : super(const CarsState()) {
    on<LoadInitialCars>(_onLoadInitial);
    on<ClearCars>(_onClear);
    on<CarsLoadMore>(_onLoadMore);
    on<AdminDeleteCarPressed>(_onDelete);
    on<CarUpdateLocally>((event, emit) {
      final updatedList = state.cars.map((car) {
        return car.id == event.updatedCar.id ? event.updatedCar : car;
      }).toList();
      emit(state.copyWith(cars: updatedList));
    });
    on<CarDeletedLocally>((event, emit) {
      final updated = state.cars.where((c) => c.id != event.carId).toList();

      emit(state.copyWith(cars: updated));
    });
  }

  Future<void> _onLoadInitial(
    LoadInitialCars event,
    Emitter<CarsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      emit(
        state.copyWith(
          isLoading: true,
          cars: [],
          lastDoc: null,
          hasReachedEnd: false,
        ),
      );

      final page = await getInitialCars();

      emit(
        state.copyWith(
          cars: page.cars,
          lastDoc: page.lastDoc,
          hasReachedEnd: page.hasReachedEnd,
          isLoading: false,
        ),
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);

      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onLoadMore(CarsLoadMore event, Emitter<CarsState> emit) async {
    if (state.hasReachedEnd || state.isLoadingMore || state.lastDoc == null) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await loadMoreCars(state.lastDoc!);

      emit(
        state.copyWith(
          cars: [...state.cars, ...page.cars],
          lastDoc: page.lastDoc,
          hasReachedEnd: page.hasReachedEnd,
          isLoadingMore: false,
        ),
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onDelete(
    AdminDeleteCarPressed event,
    Emitter<CarsState> emit,
  ) async {
    emit(state.copyWith(deletedCarId: ''));

    final oldList = List<CarEntity>.from(state.cars);

    final newList = oldList.where((c) => c.id != event.carId).toList();

    emit(state.copyWith(cars: newList));

    try {
      assert(event.carId.isNotEmpty);

      await adminDeleteCar(event.carId);

      emit(state.copyWith(deletedCarId: event.carId));
    } on AppException catch (e) {
      emit(state.copyWith(cars: oldList, deletedCarId: ''));

      appErrorCubit.showError(e.message);
    }
  }

  void _onClear(CarsEvent event, Emitter<CarsState> emit) {
    emit(
      state.copyWith(
        isLoading: true,
        isSuccess: false,
        cars: [],
        lastDoc: null,
        hasReachedEnd: false,
        isLoadingMore: false,
      ),
    );
  }
}
