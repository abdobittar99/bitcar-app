import 'package:car_shop/core/cache/cache_helper.dart';
import 'package:car_shop/core/cache/cache_keys.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashService {
  Future<bool> isIntroSeen() async {
    return CacheHelper.getData(key: CacheKeys.introSeen) ?? false;
  }

  Stream<User?> authStateChanges() async* {
    try {
      yield* FirebaseAuth.instance.authStateChanges();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
