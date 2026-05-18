import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/profile/bloc/profile_event.dart';
import 'package:car_shop/modules/profile/bloc/profile_state.dart';
import 'package:car_shop/modules/profile/domain/usecases/get_user_profile.dart';
import 'package:car_shop/modules/profile/domain/usecases/update_user_profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserProfile getUserProfile;
  final UpdateUserProfile updateUserProfile;
  final AppErrorCubit appErrorCubit;

  ProfileBloc({
    required this.getUserProfile,
    required this.updateUserProfile,
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

      emit(state.copyWith(isLoading: false, user: result, isSuccess: true));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onCleared(ProfileCleared event, Emitter<ProfileState> emit) {
    emit(const ProfileState());
  }
}
