import 'package:car_shop/core/cache/cache_helper.dart';
import 'package:car_shop/core/cache/cache_keys.dart';
import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/features/home/data/datasource/home_remote_datasource.dart';
import 'package:car_shop/features/home/domain/usecase/complete_pending_sign_out.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/fakes/fake_firebase.dart';

// The real DI wiring of T080, with the Firebase classes replaced by fakes.
void main() {
  late CallLog log;
  late FakeFirestore firestore;
  late FakeAuth auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    await sl.reset();
    await init();
    log = CallLog();
    firestore = FakeFirestore(log);
    auth = FakeAuth(log);
    sl.unregister<HomeRemoteDataSource>();
    sl.registerLazySingleton(() => HomeRemoteDataSource(auth, firestore, sl()));
  });

  tearDown(() => sl.reset());

  Future<void> setMarker() =>
      CacheHelper.saveData(key: CacheKeys.firestoreWipePending, value: true);

  test('the gate retry is wired, and it only wipes and never signs out', () async {
    await setMarker();
    final gate = sl<SessionGate>()..markWipePending();

    expect(await gate.run(() async => 'first read'), 'first read');

    expect(log.calls, ['terminate', 'clearPersistence']);
    expect(markerSet(), isFalse);
    expect(gate.isOpen, isTrue);
  });

  test('startup, with the marker: wipes and signs out, and the gate opens', () async {
    await setMarker();

    await sl<CompletePendingSignOut>()();

    expect(log.calls, ['terminate', 'clearPersistence', 'signOut']);
    expect(markerSet(), isFalse);
    expect(sl<SessionGate>().isOpen, isTrue);
  });

  test('startup, no marker: nothing runs', () async {
    await sl<CompletePendingSignOut>()();

    expect(log.calls, isEmpty);
    expect(sl<SessionGate>().isOpen, isTrue);
  });

  test('startup, wipe fails: Firestore waits for the wipe, and a later retry can finish it', () async {
    await setMarker();
    firestore.failClear = true;

    await sl<CompletePendingSignOut>()();
    final gate = sl<SessionGate>();
    expect(gate.state, SessionGateState.wipePending);
    expect(gate.isSignOutIncomplete, isFalse);

    var ran = false;
    await expectLater(gate.run(() async => ran = true), throwsA(anything));
    expect(ran, isFalse);
    expect(markerSet(), isTrue);

    firestore.failClear = false;
    await gate.run(() async => ran = true);
    expect(ran, isTrue);
    expect(markerSet(), isFalse);
    expect(log.calls.where((c) => c == 'signOut').length, 1);
  });

  test('startup, signOut fails: Firestore stays refused, with no wipe retry', () async {
    await setMarker();
    auth.failSignOut = true;

    await sl<CompletePendingSignOut>()();
    final gate = sl<SessionGate>();
    log.calls.clear();

    var ran = false;
    await expectLater(gate.run(() async => ran = true), throwsA(anything));

    expect(ran, isFalse);
    expect(log.calls, isEmpty);
    expect(gate.isSignOutIncomplete, isTrue);
    expect(markerSet(), isTrue);
  });
}
