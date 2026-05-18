import 'package:car_shop/core/enums/user_role.dart';

class HomeState {
  final bool isLoading;
  final bool isSuccess;
  final UserRole? role;
  final int currentIndex;
  final String? error;

  const HomeState({
    this.isLoading = true,
    this.isSuccess = false,
    this.role,
    this.currentIndex = 0,
    this.error,
  });

  HomeState copyWith({
    bool? isLoading,
    bool? isSuccess,
    UserRole? role,
    int? currentIndex,
    String? error,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      role: role ?? this.role,
      currentIndex: currentIndex ?? this.currentIndex,
      error: error,
    );
  }
}
