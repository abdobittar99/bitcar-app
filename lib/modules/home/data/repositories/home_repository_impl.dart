import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/home/data/datasources/home_remote_datasource.dart';
import 'package:car_shop/modules/home/domain/repositories/home_repository.dart';

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
