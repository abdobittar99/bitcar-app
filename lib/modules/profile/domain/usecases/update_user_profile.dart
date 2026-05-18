import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/profile/domain/repository/profile_repository.dart';

class UpdateUserProfile {
  final ProfileRepository repo;
  UpdateUserProfile(this.repo);

  Future<UserEntity> call(UserEntity user) => repo.updateUser(user);
}
