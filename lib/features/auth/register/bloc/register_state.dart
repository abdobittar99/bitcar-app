import 'package:car_shop/core/enums/user_role.dart';

class RegisterState {
  final String fullName;
  final String email;
  final String password;
  final bool isLoading;
  final String? error;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;

  final String phone;
  final String confirmPassword;
  final UserRole? role;
  final bool isSuccess;

  const RegisterState({
    this.fullName = '',
    this.email = '',
    this.password = '',
    this.isLoading = false,
    this.isSuccess = false,
    this.isPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.error,
    this.phone = '',
    this.confirmPassword = '',
    this.role,
  });

  bool get isFormValid =>
      fullName.isNotEmpty &&
      email.isNotEmpty &&
      password.length >= 6 &&
      confirmPassword == password &&
      phone.isNotEmpty &&
      role != null;

  RegisterState copyWith({
    String? fullName,
    String? email,
    String? password,
    bool? isLoading,
    bool? isSuccess,
    String? error,
    bool? isPasswordVisible,
    bool? isConfirmPasswordVisible,
    String? phone,
    String? confirmPassword,
    UserRole? role,
  }) {
    return RegisterState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error ?? this.error,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isConfirmPasswordVisible:
          isConfirmPasswordVisible ?? this.isConfirmPasswordVisible,
      phone: phone ?? this.phone,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      role: role ?? this.role,
    );
  }
}
