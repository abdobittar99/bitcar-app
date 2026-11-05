import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/features/home/bloc/home_event.dart';
import 'package:car_shop/features/home/bloc/home_state.dart';
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
import 'package:car_shop/features/home/domain/usecase/has_pending_writes.dart';
import 'package:car_shop/features/home/domain/usecase/logout.dart';
import 'package:car_shop/features/home/domain/usecase/prepare_sign_out.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetCurrentUser getCurrentUser;
  final LogOut loggout;
  final HasPendingWrites hasPendingWrites;
  final PrepareSignOut prepareSignOut;
  final AppErrorCubit appErrorCubit;
  bool _isPreparingSignOut = false;
  HomeBloc({
    required this.loggout,
    required this.hasPendingWrites,
    required this.prepareSignOut,
    required this.getCurrentUser,
    required this.appErrorCubit,
  }) : super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<LogoutPressed>(_onLogoutPressed);
    on<LogoutConfirmed>(_onLogoutConfirmed);
    on<LogoutCancelled>(_onLogoutCancelled);
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

  // Repeated presses are ignored during the check, the warning and the sign-out. The check itself
  // ends within 3 s (HomeRemoteDataSource.hasPendingWrites).
  Future<void> _onLogoutPressed(
    LogoutPressed event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isCheckingPendingWrites ||
        state.showUnsyncedWarning ||
        state.isSigningOut ||
        _isPreparingSignOut) {
      return;
    }
    emit(state.copyWith(isCheckingPendingWrites: true));

    final bool hasPending;
    try {
      hasPending = await hasPendingWrites();
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      if (isClosed) return;
      emit(state.copyWith(isCheckingPendingWrites: false));
      return;
    }
    if (isClosed) return;

    if (hasPending) {
      emit(
        state.copyWith(
          isCheckingPendingWrites: false,
          showUnsyncedWarning: true,
        ),
      );
      return;
    }
    await _signOut(emit);
  }

  Future<void> _onLogoutConfirmed(
    LogoutConfirmed event,
    Emitter<HomeState> emit,
  ) async {
    if (!state.showUnsyncedWarning || state.isSigningOut || _isPreparingSignOut) {
      return;
    }
    await _signOut(emit);
  }

  // The user stays signed in and nothing is wiped, so the unsynced changes are kept.
  void _onLogoutCancelled(LogoutCancelled event, Emitter<HomeState> emit) {
    emit(state.copyWith(showUnsyncedWarning: false));
  }

  // Sign-out disposes HomeLayout and this bloc through the auth stream, so it may already be closed
  // here. An error is still shown, since the error cubit outlives this bloc. isSuccess is true only
  // after a complete sign-out; profile_screen.dart clears the other blocs on it.
  //
  // The marker is saved first, so "Signing out…" never shows without it (research D18 step 3). If
  // it cannot be saved the sign-out does not start, and the user stays signed in.
  Future<void> _signOut(Emitter<HomeState> emit) async {
    _isPreparingSignOut = true;
    try {
      await prepareSignOut();
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      if (isClosed) return;
      emit(
        state.copyWith(
          isCheckingPendingWrites: false,
          showUnsyncedWarning: false,
        ),
      );
      return;
    } finally {
      _isPreparingSignOut = false;
    }
    if (isClosed) return;

    emit(
      state.copyWith(
        isSuccess: false,
        isCheckingPendingWrites: false,
        showUnsyncedWarning: false,
        isSigningOut: true,
      ),
    );
    try {
      await loggout();
      if (isClosed) return;
      emit(state.copyWith(isSuccess: true, isSigningOut: false));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      if (isClosed) return;
      emit(state.copyWith(isSigningOut: false));
    }
  }

  void _onTabChanged(HomeTabChanged event, Emitter<HomeState> emit) async {
    emit(state.copyWith(currentIndex: event.currentIndex));
  }
}
