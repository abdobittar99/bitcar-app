import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class GetCurrentUserId {
  final ChatRepository repo;
  GetCurrentUserId(this.repo);

  String call() => repo.currentUserId;
}
