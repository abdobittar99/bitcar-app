import 'package:car_shop/core/enums/user_role.dart';

abstract class RegisterEvent {}

class RegisterEmailChanged extends RegisterEvent {
  final String email;
  RegisterEmailChanged(this.email);
}

class RegisterNameChanged extends RegisterEvent {
  final String fullName;
  RegisterNameChanged(this.fullName);
}

class RegisterPasswordChanged extends RegisterEvent {
  final String password;
  RegisterPasswordChanged(this.password);
}

class RegisterPhoneChanged extends RegisterEvent {
  final String phone;
  RegisterPhoneChanged(this.phone);
}

class RegisterConfirmPasswordChanged extends RegisterEvent {
  final String confirmPassword;
  RegisterConfirmPasswordChanged(this.confirmPassword);
}

class RegisterRoleChanged extends RegisterEvent {
  final UserRole role;

  RegisterRoleChanged(this.role);
}

class RegisterSubmitted extends RegisterEvent {}

class RegisterPasswordVisibilityToggled extends RegisterEvent {
  final bool isConfirm;

  RegisterPasswordVisibilityToggled({required this.isConfirm});
}
