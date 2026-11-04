import 'package:car_shop/core/enums/user_role.dart';

class HomeState {
  final bool isLoading;
  final bool isSuccess;
  final UserRole? role;
  final int currentIndex;
  final String? error;
  final bool showUnsyncedWarning;
  final bool isCheckingPendingWrites;
  final bool isSigningOut;

  const HomeState({
    this.isLoading = true,
    this.isSuccess = false,
    this.role,
    this.currentIndex = 0,
    this.error,
    this.showUnsyncedWarning = false,
    this.isCheckingPendingWrites = false,
    this.isSigningOut = false,
  });

  HomeState copyWith({
    bool? isLoading,
    bool? isSuccess,
    UserRole? role,
    int? currentIndex,
    String? error,
    bool? showUnsyncedWarning,
    bool? isCheckingPendingWrites,
    bool? isSigningOut,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      role: role ?? this.role,
      currentIndex: currentIndex ?? this.currentIndex,
      error: error,
      showUnsyncedWarning: showUnsyncedWarning ?? this.showUnsyncedWarning,
      isCheckingPendingWrites:
          isCheckingPendingWrites ?? this.isCheckingPendingWrites,
      isSigningOut: isSigningOut ?? this.isSigningOut,
    );
  }
}
