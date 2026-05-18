import 'package:car_shop/entities/app_user.dart';

abstract class ProfileRepository {
  Future<UserEntity> getCurrentUserProfile();
  Future<UserEntity> updateUser(UserEntity user);
}
