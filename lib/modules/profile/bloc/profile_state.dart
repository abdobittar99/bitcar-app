import 'package:car_shop/entities/app_user.dart';

class ProfileState {
  final bool isLoading;
  final bool isSuccess;
  final UserEntity? user;
  final bool? error;

  const ProfileState({
    this.isLoading = false,
    this.user,
    this.error,
    this.isSuccess = false,
  });

  ProfileState copyWith({
    bool? isLoading,
    UserEntity? user,
    bool? error,
    bool? isSuccess,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? false,
      user: user ?? this.user,
      error: error,
    );
  }
}
