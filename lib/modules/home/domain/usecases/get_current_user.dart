import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/home/domain/repositories/home_repository.dart';

class GetCurrentUser {
  final HomeRepository repo;
  GetCurrentUser(this.repo);

  Future<UserEntity> call() => repo.getCurrentUser();
}
