import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/features/chat/domain/usecase/sync_public_profile.dart';
import 'package:car_shop/features/profile/bloc/profile_event.dart';
import 'package:car_shop/features/profile/bloc/profile_state.dart';
import 'package:car_shop/features/profile/domain/usecase/get_user_profile.dart';
import 'package:car_shop/features/profile/domain/usecase/update_user_profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserProfile getUserProfile;
  final UpdateUserProfile updateUserProfile;
  final SyncPublicProfile syncPublicProfile;
  final AppErrorCubit appErrorCubit;

  ProfileBloc({
    required this.getUserProfile,
    required this.updateUserProfile,
    required this.syncPublicProfile,
    required this.appErrorCubit,
  }) : super(const ProfileState()) {
    on<ProfileRequested>(_onRequested);
    on<ProfileUpdated>(_onUpdated);
    on<ProfileCleared>(_onCleared);
  }

  Future<void> _onRequested(
    ProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (!event.forceRefresh && state.user != null) return;

    emit(state.copyWith(isLoading: true, isSuccess: false));

    try {
      final user = await getUserProfile();

      emit(state.copyWith(isLoading: false, user: user));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onUpdated(
    ProfileUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    emit(state.copyWith(isLoading: true, isSuccess: false));

    try {
      final updatedUser = UserEntity(
        id: currentUser.id,
        email: currentUser.email,
        role: currentUser.role,
        fullName: event.fullName,
        phone: event.phone,
      );

      final result = await updateUserProfile(updatedUser);

      if (result.fullName != currentUser.fullName) {
        await _syncName(result.fullName);
      }

      emit(state.copyWith(isLoading: false, user: result, isSuccess: true));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }

  // The profile itself is already saved; a failed sync is shown but does not undo that, and the
  // next app open repeats it (research D14, sync point 2).
  Future<void> _syncName(String fullName) async {
    try {
      await syncPublicProfile(fullName);
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
    }
  }

  void _onCleared(ProfileCleared event, Emitter<ProfileState> emit) {
    emit(const ProfileState());
  }
}
