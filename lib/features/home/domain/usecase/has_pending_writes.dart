import 'package:car_shop/features/home/domain/repositories/home_repository.dart';

class HasPendingWrites {
  final HomeRepository repo;
  HasPendingWrites(this.repo);

  Future<bool> call() => repo.hasPendingWrites();
}
