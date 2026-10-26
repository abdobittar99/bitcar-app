import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/features/home/data/datasource/home_remote_datasource.dart';
import 'package:car_shop/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remote;

  HomeRepositoryImpl(this.remote);

  @override
  Future<UserEntity> getCurrentUser() {
    return remote.getCurrentUser();
  }

  @override
  Future<void> logOut() {
    return remote.logOut();
  }
}
