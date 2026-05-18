import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/profile/domain/repository/profile_repository.dart';

class GetUserProfile {
  final ProfileRepository repo;
  GetUserProfile(this.repo);

  Future<UserEntity> call() => repo.getCurrentUserProfile();
}
