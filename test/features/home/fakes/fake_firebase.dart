import 'package:car_shop/core/cache/cache_helper.dart';
import 'package:car_shop/core/cache/cache_keys.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

bool markerSet() => CacheHelper.getData(key: CacheKeys.firestoreWipePending) == true;

// Records every call in one list, so tests can check the exact order.
class CallLog {
  final calls = <String>[];
  // Marker value when signOut ran.
  bool? markerAtSignOut;
}

class FakeFirestore implements FirebaseFirestore {
  final CallLog log;
  FakeFirestore(this.log);

  bool failTerminate = false;
  bool failClear = false;
  Future<void> pendingWrites = Future.value();

  FirebaseException _failure() =>
      FirebaseException(plugin: 'cloud_firestore', code: 'failed-precondition');

  @override
  Future<void> terminate() async {
    log.calls.add('terminate');
    if (failTerminate) throw _failure();
  }

  @override
  Future<void> clearPersistence() async {
    log.calls.add('clearPersistence');
    if (failClear) throw _failure();
  }

  @override
  Future<void> waitForPendingWrites() {
    log.calls.add('waitForPendingWrites');
    return pendingWrites;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements FirebaseAuth {
  final CallLog log;
  FakeAuth(this.log);

  bool failSignOut = false;

  @override
  Future<void> signOut() async {
    log.calls.add('signOut');
    log.markerAtSignOut = markerSet();
    if (failSignOut) {
      throw FirebaseAuthException(code: 'internal-error');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingGate extends SessionGate {
  final CallLog log;
  RecordingGate(this.log);

  @override
  Future<void> closeForSignOut({
    Duration drainTimeout = const Duration(seconds: 5),
  }) {
    log.calls.add('closeForSignOut');
    return super.closeForSignOut(drainTimeout: drainTimeout);
  }

  @override
  void open() {
    log.calls.add('open');
    super.open();
  }
}

