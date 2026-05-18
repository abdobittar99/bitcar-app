import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/auth/data/datasource/auth_remote_datasource.dart';
import 'package:car_shop/modules/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remote;

  AuthRepositoryImpl(this.remote);

  @override
  Future<void> login({required String email, required String password}) {
    return remote.login(email: email, password: password);
  }

  @override
  Future<UserEntity> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) {
    return remote.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: role,
    );
  }
}
