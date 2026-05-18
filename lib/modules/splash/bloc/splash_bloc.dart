import 'dart:async';
import 'package:car_shop/core/enums/spalsh_destination.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/modules/splash/bloc/splash_event.dart';
import 'package:car_shop/modules/splash/bloc/splash_state.dart';
import 'package:car_shop/modules/splash/data/splash_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final SplashService service;
  StreamSubscription<User?>? _authSub;

  SplashBloc(this.service) : super(const SplashState()) {
    on<SplashStarted>(_onStarted);
    on<GoToRegisterPressed>(
      (event, emit) =>
          emit(state.copyWith(destination: SplashDestination.register)),
    );
    on<GoToLoginPressed>(
      (event, emit) =>
          emit(state.copyWith(destination: SplashDestination.login)),
    );
    on<AuthStatusChanged>(_onAuthChanged);
    try {
      _authSub = service.authStateChanges().listen((user) {
        add(AuthStatusChanged(user));
      });
    } on AppException catch (e) {
      AppErrorCubit().showError(e.message);
    }
  }

  Future<void> _onStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    // print(" CURRENT user: $currentUser");
    final isIntroSeen = await service.isIntroSeen();
    await Future.delayed(const Duration(milliseconds: 800));

    if (!isIntroSeen) {
      emit(state.copyWith(destination: SplashDestination.intro));
    }
  }

  void _onAuthChanged(AuthStatusChanged event, Emitter<SplashState> emit) {
    emit(
      state.copyWith(
        destination: event.user != null
            ? SplashDestination.home
            : SplashDestination.login,
      ),
    );
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
