import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/modules/car/car_details/bloc/car_details_event.dart';
import 'package:car_shop/modules/car/car_details/bloc/car_details_state.dart';
import 'package:car_shop/modules/car/domain/usecases/get_car_details.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CarDetailsBloc extends Bloc<CarDetailsEvent, CarDetailsState> {
  final GetCarDetails getCarDetails;
  final AppErrorCubit appErrorCubit;
  CarDetailsBloc({required this.getCarDetails, required this.appErrorCubit})
    : super(const CarDetailsState()) {
    on<CarDetailsStarted>(_onStarted);
  }
  Future<void> _onStarted(
    CarDetailsStarted event,
    Emitter<CarDetailsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final car = await getCarDetails(event.carId);
      emit(state.copyWith(isLoading: false, car: car));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }
}
