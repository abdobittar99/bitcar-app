import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';

class SyncPublicProfile {
  final ChatRepository repo;
  SyncPublicProfile(this.repo);

  Future<void> call(String displayName) {
    return repo.syncPublicProfile(displayName);
  }
}
