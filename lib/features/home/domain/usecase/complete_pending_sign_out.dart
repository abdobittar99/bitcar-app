import 'package:car_shop/features/home/domain/repositories/home_repository.dart';

class CompletePendingSignOut {
  final HomeRepository repo;
  CompletePendingSignOut(this.repo);

  Future<void> call() => repo.completePendingSignOut();
}
