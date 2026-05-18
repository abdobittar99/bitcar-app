import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/models/user_model.dart';
import 'package:car_shop/modules/profile/data/datasource/user_remote_datasource.dart';
import 'package:car_shop/modules/profile/domain/repository/profile_repository.dart';

class UserRepositoryImpl implements ProfileRepository {
  final UserRemoteDatasource remote;
  UserRepositoryImpl(this.remote);

  @override
  Future<UserEntity> getCurrentUserProfile() {
    final user = remote.getCurrentUserProfile();

    return user;
  }

  @override
  Future<UserEntity> updateUser(UserEntity user) {
    return remote.updateUser(AppUserModel.fromEntity(user));
  }
}
