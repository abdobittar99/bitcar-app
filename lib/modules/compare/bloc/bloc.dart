import 'package:car_shop/modules/compare/bloc/event.dart';
import 'package:car_shop/modules/compare/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CompareBloc extends Bloc<CompareEvent, CompareState> {
  CompareBloc() : super(const CompareState()) {
    on<SelectFirstCar>((event, emit) {
      emit(state.copyWith(firstCar: event.car));
    });

    on<SelectSecondCar>((event, emit) {
      emit(state.copyWith(secondCar: event.car));
    });

    on<ClearFirstCar>((event, emit) {
      emit(state.copyWith(clearFirst: true));
    });

    on<ClearSecondCar>((event, emit) {
      emit(state.copyWith(clearSecond: true));
    });

    on<ResetCompare>((event, emit) {
      emit(const CompareState());
    });
  }
}
