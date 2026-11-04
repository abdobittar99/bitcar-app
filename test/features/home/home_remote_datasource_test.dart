import 'dart:async';

import 'package:car_shop/core/cache/cache_helper.dart';
import 'package:car_shop/core/cache/cache_keys.dart';
import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/features/home/data/datasource/home_remote_datasource.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_firebase.dart';

const wipeMessage = 'Previous session data could not be cleared. Please try again.';
const signOutMessage =
    'Could not finish signing out. Please restart the app to complete it.';

void main() {
  late CallLog log;
  late FakeFirestore firestore;
  late FakeAuth auth;
  late RecordingGate gate;
  late HomeRemoteDataSource dataSource;

  Future<void> setMarker() =>
      CacheHelper.saveData(key: CacheKeys.firestoreWipePending, value: true);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    log = CallLog();
    firestore = FakeFirestore(log);
    auth = FakeAuth(log);
    gate = RecordingGate(log);
    gate.retryWipe = () => dataSource.retryPendingWipe();
    dataSource = HomeRemoteDataSource(auth, firestore, gate);
  });

  Matcher throwsApp(ErrorType type, String message) => throwsA(
    isA<AppException>()
        .having((e) => e.type, 'type', type)
        .having((e) => e.message, 'message', message),
  );

  Future<void> expectFirestoreRefused(String message, ErrorType type) async {
    var ran = false;
    await expectLater(
      gate.run(() async => ran = true),
      throwsApp(type, message),
    );
    expect(ran, isFalse);
  }

  group('logOut', () {
    test('success: the exact order, with the marker removed only after signOut', () async {
      await dataSource.logOut();

      expect(log.calls, [
        'closeForSignOut',
        'terminate',
        'clearPersistence',
        'signOut',
        'open',
      ]);
      expect(log.markerAtSignOut, isTrue);
      expect(markerSet(), isFalse);
      expect(gate.isOpen, isTrue);
    });

    test('the marker is saved before terminate', () async {
      var markerAtTerminate = false;
      firestore = _MarkerCheckingFirestore(log, (v) => markerAtTerminate = v);
      dataSource = HomeRemoteDataSource(auth, firestore, gate);

      await dataSource.logOut();

      expect(markerAtTerminate, isTrue);
    });

    test('new operations are refused during the sequence', () async {
      Object? refused;
      firestore = _MarkerCheckingFirestore(log, (_) {
        gate.run(() async => 1).catchError((Object e) {
          refused = e;
          return 0;
        });
      });
      dataSource = HomeRemoteDataSource(auth, firestore, gate);

      await dataSource.logOut();
      await pumpEventQueue();

      expect(refused, isA<AppException>());
    });

    for (final (name, breakIt) in [
      ('terminate', (FakeFirestore f) => f.failTerminate = true),
      ('clearPersistence', (FakeFirestore f) => f.failClear = true),
    ]) {
      test('$name fails: signOut still runs, marker kept, wipePending, wipe error', () async {
        breakIt(firestore);

        await expectLater(
          dataSource.logOut(),
          throwsApp(ErrorType.cache, wipeMessage),
        );

        expect(log.calls, contains('signOut'));
        expect(log.calls, isNot(contains('open')));
        expect(markerSet(), isTrue);
        expect(gate.state, SessionGateState.wipePending);
        expect(gate.isSignOutIncomplete, isFalse);
      });
    }

    test('a failed wipe keeps blocking with the wipe message while the retry fails', () async {
      firestore.failClear = true;
      await expectLater(dataSource.logOut(), throwsA(isA<AppException>()));

      await expectFirestoreRefused(wipeMessage, ErrorType.cache);
      expect(markerSet(), isTrue);
    });

    test('a failed wipe retried with success opens the gate, without another signOut', () async {
      firestore.failClear = true;
      await expectLater(dataSource.logOut(), throwsA(isA<AppException>()));
      final signOuts = log.calls.where((c) => c == 'signOut').length;

      firestore.failClear = false;
      expect(await gate.run(() async => 'data'), 'data');

      expect(log.calls.where((c) => c == 'signOut').length, signOuts);
      expect(markerSet(), isFalse);
      expect(gate.isOpen, isTrue);
    });
  });

  group('logOut when signOut fails', () {
    for (final (name, wipeFails) in [('after a good wipe', false), ('after a failed wipe', true)]) {
      group(name, () {
        setUp(() async {
          auth.failSignOut = true;
          firestore.failClear = wipeFails;
          await expectLater(
            dataSource.logOut(),
            throwsApp(ErrorType.auth, signOutMessage),
          );
        });

        test('marker kept, gate wipePending and never opened', () {
          expect(markerSet(), isTrue);
          expect(gate.state, SessionGateState.wipePending);
          expect(gate.isSignOutIncomplete, isTrue);
          expect(log.calls, isNot(contains('open')));
        });

        test('Firestore is refused with the sign-out message, with no wipe retry', () async {
          log.calls.clear();

          await expectFirestoreRefused(signOutMessage, ErrorType.auth);

          expect(log.calls, isEmpty);
          expect(gate.isOpen, isFalse);
        });

        test('a second logOut does nothing and throws the same error', () async {
          log.calls.clear();
          auth.failSignOut = false;
          firestore.failClear = false;

          await expectLater(
            dataSource.logOut(),
            throwsApp(ErrorType.auth, signOutMessage),
          );

          expect(log.calls, isEmpty);
          expect(markerSet(), isTrue);
          expect(gate.state, SessionGateState.wipePending);
        });

        test('hasPendingWrites does not touch Firestore and throws the same error', () async {
          log.calls.clear();

          await expectLater(
            dataSource.hasPendingWrites(),
            throwsApp(ErrorType.auth, signOutMessage),
          );

          expect(log.calls, isEmpty);
        });
      });
    }

    test('the next app start finishes it', () async {
      auth.failSignOut = true;
      await expectLater(dataSource.logOut(), throwsA(isA<AppException>()));

      // A new app run: new gate, same device marker, and signOut works now.
      log.calls.clear();
      auth.failSignOut = false;
      gate = RecordingGate(log);
      dataSource = HomeRemoteDataSource(auth, firestore, gate);

      await dataSource.completePendingSignOut();

      expect(log.calls, ['terminate', 'clearPersistence', 'signOut', 'open']);
      expect(markerSet(), isFalse);
      expect(gate.isOpen, isTrue);
    });
  });

  group('retryPendingWipe', () {
    setUp(() async {
      await setMarker();
      gate.markWipePending();
    });

    test('success: wipes, removes the marker, opens the gate and never signs out', () async {
      await dataSource.retryPendingWipe();

      expect(log.calls, ['terminate', 'clearPersistence', 'open']);
      expect(markerSet(), isFalse);
      expect(gate.isOpen, isTrue);
    });

    test('failure: marker kept, still wipePending, no signOut, no throw', () async {
      firestore.failClear = true;

      await dataSource.retryPendingWipe();

      expect(log.calls, isNot(contains('signOut')));
      expect(log.calls, isNot(contains('open')));
      expect(markerSet(), isTrue);
      expect(gate.state, SessionGateState.wipePending);
    });

    test('a user who signed in after the failed wipe stays signed in', () async {
      expect(await gate.run(() async => 'first read'), 'first read');

      expect(log.calls, isNot(contains('signOut')));
    });
  });

  group('completePendingSignOut', () {
    test('no marker: no call at all', () async {
      await dataSource.completePendingSignOut();

      expect(log.calls, isEmpty);
      expect(gate.isOpen, isTrue);
    });

    test('marker: wipes, signs out, removes the marker, opens the gate', () async {
      await setMarker();

      await dataSource.completePendingSignOut();

      expect(log.calls, ['terminate', 'clearPersistence', 'signOut', 'open']);
      expect(log.markerAtSignOut, isTrue);
      expect(markerSet(), isFalse);
      expect(gate.isOpen, isTrue);
    });

    test('wipe failure: signOut still runs, marker kept, wipePending, no throw', () async {
      await setMarker();
      firestore.failTerminate = true;

      await dataSource.completePendingSignOut();

      expect(log.calls, contains('signOut'));
      expect(markerSet(), isTrue);
      expect(gate.state, SessionGateState.wipePending);
      expect(gate.isSignOutIncomplete, isFalse);
    });

    test('signOut failure: marker kept, Firestore refused, no throw', () async {
      await setMarker();
      auth.failSignOut = true;

      await dataSource.completePendingSignOut();

      expect(markerSet(), isTrue);
      expect(gate.isSignOutIncomplete, isTrue);
      await expectFirestoreRefused(signOutMessage, ErrorType.auth);
    });
  });

  group('hasPendingWrites', () {
    test('completes: false', () async {
      expect(await dataSource.hasPendingWrites(), isFalse);
    });

    test('no answer within 3 s: true', () {
      fakeAsync((async) {
        firestore.pendingWrites = Completer<void>().future;
        bool? result;
        dataSource.hasPendingWrites().then((v) => result = v);

        async.elapse(const Duration(milliseconds: 2999));
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(result, isTrue);
      });
    });

    test('another error is mapped', () async {
      firestore.pendingWrites = Future.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      await expectLater(
        dataSource.hasPendingWrites(),
        throwsA(isA<AppException>().having((e) => e.type, 'type', ErrorType.permission)),
      );
    });
  });
}

// Runs a check at the moment terminate is called.
class _MarkerCheckingFirestore extends FakeFirestore {
  final void Function(bool markerSet) onTerminate;
  _MarkerCheckingFirestore(super.log, this.onTerminate);

  @override
  Future<void> terminate() {
    onTerminate(markerSet());
    return super.terminate();
  }
}
