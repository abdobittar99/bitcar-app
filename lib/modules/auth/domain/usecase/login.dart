import 'package:car_shop/modules/auth/domain/repositories/auth_repository.dart';

class Login {
  final AuthRepository repo;
  Login(this.repo);
  Future<void> call({required String email, required String password}) {
    return repo.login(email: email, password: password);
  }
}
