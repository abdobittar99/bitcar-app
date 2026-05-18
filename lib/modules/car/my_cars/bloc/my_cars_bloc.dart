import 'dart:async';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/car_list/domain/usecases/get_my_cars.dart';
import 'package:car_shop/modules/car/my_cars/bloc/my_cars_event.dart';
import 'package:car_shop/modules/car/my_cars/bloc/my_cars_state.dart';
import 'package:car_shop/modules/car/car_list/domain/usecases/delete_cars.dart';
import 'package:car_shop/modules/home/domain/usecases/get_current_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MyCarsBloc extends Bloc<MyCarsEvent, MyCarsState> {
  final GetMyCars getMyCars;
  final DeleteCar deleteMyCar;
  final GetCurrentUser getCurrentUser;
  final AppErrorCubit appErrorCubit;

  MyCarsBloc({
    required this.getMyCars,
    required this.deleteMyCar,
    required this.getCurrentUser,
    required this.appErrorCubit,
  }) : super(const MyCarsState()) {
    on<MyCarsStarted>(_onStarted);
    on<DeleteMyCarPressed>(_onDelete);
    on<MyCarsReloaded>(_onReloaded);
    on<ClearMycars>(_onclear);
    on<MyCarUpdateLocally>((event, emit) {
      final updatedList = state.myCars.map((car) {
        return car.id == event.updatedCar.id ? event.updatedCar : car;
      }).toList();
      emit(state.copyWith(myCars: updatedList));
    });
  }

  Future<void> _onStarted(
    MyCarsStarted event,
    Emitter<MyCarsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final user = await getCurrentUser();

      final cars = await getMyCars(user.id);
      emit(state.copyWith(myCars: cars, isLoading: false));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onReloaded(
    MyCarsReloaded event,
    Emitter<MyCarsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, myCars: []));

    try {
      final user = await getCurrentUser();

      final cars = await getMyCars(user.id);

      emit(state.copyWith(isLoading: false, myCars: cars));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      appErrorCubit.showError(e.toString());
    }
  }

  Future<void> _onDelete(
    DeleteMyCarPressed event,
    Emitter<MyCarsState> emit,
  ) async {
    emit(state.copyWith(deletedCarId: ''));

    final oldList = List<CarEntity>.from(state.myCars);

    final newList = oldList.where((c) => c.id != event.carId).toList();

    emit(state.copyWith(myCars: newList));

    try {
      assert(event.carId.isNotEmpty);

      await deleteMyCar(event.carId);

      emit(state.copyWith(deletedCarId: event.carId));
    } on AppException catch (e) {
      emit(state.copyWith(myCars: oldList, deletedCarId: ''));

      appErrorCubit.showError(e.message);
    }
  }

  void _onclear(ClearMycars event, Emitter<MyCarsState> emit) {
    emit(
      state.copyWith(
        isLoading: true,
        myCars: [],
        isSuccess: false,
        isDeleted: false,
        deletedCarId: '',
      ),
    );
  }
}
