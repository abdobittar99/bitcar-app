import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/core/validators/auth_validator.dart';
import 'package:car_shop/modules/auth/domain/usecase/login.dart';
import 'package:car_shop/modules/auth/login/bloc/login_event.dart';
import 'package:car_shop/modules/auth/login/bloc/login_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final Login login;
  final AppErrorCubit appErrorCubit;

  LoginBloc({required this.login, required this.appErrorCubit})
    : super(const LoginState()) {
    on<LoginPasswordVisibilityToggled>(_togglePassword);
    on<LoginEmailChanged>(_emailChanged);
    on<LoginPasswordChanged>(_passwordChanged);
    on<LoginSubmitted>(_login);
  }

  void _togglePassword(_, emit) {
    emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
  }

  void _emailChanged(LoginEmailChanged e, emit) {
    emit(state.copyWith(email: e.email));
  }

  void _passwordChanged(LoginPasswordChanged e, emit) {
    emit(state.copyWith(password: e.password));
  }

  Future<void> _login(LoginSubmitted event, emit) async {
    if (!isValidEmail(state.email)) {
      appErrorCubit.showError('Invalid email format');
      return;
    }

    if (!state.isFormValid) {
      appErrorCubit.showError('Please fill all required fields correctly');
      return;
    }

    emit(state.copyWith(isLoading: true, isSuccess: false));

    try {
      await login(email: state.email.trim(), password: state.password);
      emit(state.copyWith(isLoading: false, isSuccess: true));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }
}
