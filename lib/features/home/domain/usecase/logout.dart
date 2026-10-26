import 'package:car_shop/features/home/domain/repositories/home_repository.dart';

class LogOut {
  final HomeRepository repo;
  LogOut(this.repo);

  Future<void> call() => repo.logOut();
}
