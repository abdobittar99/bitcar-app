import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/auth/domain/repositories/auth_repository.dart';

class Register {
  final AuthRepository repo;
  Register(this.repo);

  Future<UserEntity> call({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) {
    return repo.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: role,
    );
  }
}
