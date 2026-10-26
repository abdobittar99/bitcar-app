import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/features/home/bloc/home_event.dart';
import 'package:car_shop/features/home/bloc/home_state.dart';
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
import 'package:car_shop/features/home/domain/usecase/logout.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetCurrentUser getCurrentUser;
  final LogOut loggout;
  final AppErrorCubit appErrorCubit;
  HomeBloc({
    required this.loggout,
    required this.getCurrentUser,
    required this.appErrorCubit,
  }) : super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<LogoutPressed>(_onLogout);
    on<HomeTabChanged>(_onTabChanged);
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final user = await getCurrentUser();
      emit(state.copyWith(isLoading: false, role: user.role));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onLogout(LogoutPressed event, Emitter<HomeState> emit) async {
    try {
      emit(state.copyWith(isSuccess: false, isLoading: true));

      await loggout();
      emit(state.copyWith(isSuccess: true, isLoading: false));
    } on AppException catch (e) {
      emit(state.copyWith(isSuccess: false, isLoading: false));

      appErrorCubit.showError(e.message);
    }
  }

  void _onTabChanged(HomeTabChanged event, Emitter<HomeState> emit) async {
    emit(state.copyWith(currentIndex: event.currentIndex));
  }
}
