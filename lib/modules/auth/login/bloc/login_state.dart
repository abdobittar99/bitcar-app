import 'package:flutter/material.dart';

class LoginState {
  final String email;
  final String password;
  final bool isLoading;
  final String? error;
  final bool isPasswordVisible;
  final bool isSuccess;

  const LoginState({
    this.email = '',
    this.password = '',
    this.isLoading = false,
    this.isPasswordVisible = false,
    this.error,
    this.isSuccess = false,
  });
  bool get isFormValid => email.isNotEmpty && password.length >= 6;

  LoginState copyWith({
    String? email,
    String? password,
    bool? isLoading,
    String? error,
    bool? isPasswordVisible,
    bool? isSuccess,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  IconData get suffixIcon => isPasswordVisible
      ? Icons.visibility_off_outlined
      : Icons.visibility_outlined;
}
