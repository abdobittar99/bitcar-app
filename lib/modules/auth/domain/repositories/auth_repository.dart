import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/entities/app_user.dart';

abstract class AuthRepository {
  Future<void> login({required String email, required String password});

  Future<UserEntity> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  });
}
