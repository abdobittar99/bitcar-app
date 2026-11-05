import 'package:car_shop/features/home/domain/repositories/home_repository.dart';

class PrepareSignOut {
  final HomeRepository repo;
  PrepareSignOut(this.repo);

  Future<void> call() => repo.prepareSignOut();
}
