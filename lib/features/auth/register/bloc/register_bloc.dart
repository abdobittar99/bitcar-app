import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/validators/auth_validator.dart';
import 'package:car_shop/features/auth/domain/usecase/register.dart';
import 'package:car_shop/features/auth/register/bloc/register_event.dart';
import 'package:car_shop/features/auth/register/bloc/register_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final Register register;
  final AppErrorCubit appErrorCubit;

  RegisterBloc({required this.register, required this.appErrorCubit})
    : super(const RegisterState()) {
    on<RegisterPasswordVisibilityToggled>((event, emit) {
      if (event.isConfirm) {
        emit(
          state.copyWith(
            isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
          ),
        );
      } else {
        emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
      }
    });
    on<RegisterNameChanged>((event, emit) {
      emit(state.copyWith(fullName: event.fullName, error: null));
    });
    on<RegisterEmailChanged>((event, emit) {
      emit(state.copyWith(email: event.email, error: null));
    });

    on<RegisterPasswordChanged>((event, emit) {
      emit(state.copyWith(password: event.password, error: null));
    });
    on<RegisterConfirmPasswordChanged>((event, emit) {
      emit(state.copyWith(confirmPassword: event.confirmPassword, error: null));
    });
    on<RegisterPhoneChanged>((event, emit) {
      emit(state.copyWith(phone: event.phone, error: null));
    });

    on<RegisterRoleChanged>((event, emit) {
      emit(state.copyWith(role: event.role, error: null));
    });

    on<RegisterSubmitted>(onsubmited);
  }

  Future<void> onsubmited(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    if (!state.isFormValid) {
      appErrorCubit.showError('Please fill all required fields correctly');
      return;
    }
    if (!isValidEmail(state.email)) {
      appErrorCubit.showError('Invalid email format');
      return;
    }
    final fullName = normalizeName(state.fullName);
    if (!isValidFullName(fullName)) {
      appErrorCubit.showError('Please enter your full name correctly');
      return;
    }
    emit(state.copyWith(isLoading: true, error: null));

    try {
      await register(
        fullName: fullName,
        email: state.email.trim(),
        password: state.password,
        phone: state.phone.trim(),
        role: state.role!,
      );

      emit(state.copyWith(isLoading: false, isSuccess: true));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      appErrorCubit.showError('something went wrong');
      emit(state.copyWith(isLoading: false));
    }
  }
}
