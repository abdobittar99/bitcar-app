import 'package:car_shop/entities/app_user.dart';

abstract class HomeRepository {
  Future<UserEntity> getCurrentUser();
  Future<void> logOut();
}
