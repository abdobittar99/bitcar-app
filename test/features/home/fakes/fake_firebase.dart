import 'dart:async';

import 'package:car_shop/core/cache/cache_helper.dart';
import 'package:car_shop/core/cache/cache_keys.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool markerSet() => CacheHelper.getData(key: CacheKeys.firestoreWipePending) == true;

// Records every call in one list, so tests can check the exact order.
class CallLog {
  final calls = <String>[];
  // Marker value when these ran.
  bool? markerAtClose;
  bool? markerAtSignOut;
  // The call with this name never finishes, like an app killed at that step.
  String? hangOn;

  Future<void> reach(String call) async {
    calls.add(call);
    if (hangOn == call) await Completer<void>().future;
  }
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
    await log.reach('terminate');
    if (failTerminate) throw _failure();
  }

  @override
  Future<void> clearPersistence() async {
    await log.reach('clearPersistence');
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
    log.markerAtSignOut = markerSet();
    await log.reach('signOut');
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
  }) async {
    log.markerAtClose = markerSet();
    await log.reach('closeForSignOut');
    return super.closeForSignOut(drainTimeout: drainTimeout);
  }

  @override
  void open() {
    log.calls.add('open');
    super.open();
  }
}

// Device storage the tests can make fail. The values survive a simulated new app run.
class FakePrefs implements SharedPreferences {
  final values = <String, Object>{};
  // What a save returns; with storeAnyway, a failed save still leaves the value on disk.
  bool saveResult = true;
  bool storeAnyway = false;
  bool saveThrows = false;
  bool removeThrows = false;
  bool hangOnRemove = false;
  int saves = 0;
  int removes = 0;

  @override
  Future<bool> setBool(String key, bool value) async {
    saves++;
    if (saveThrows) throw Exception('disk full');
    if (saveResult || storeAnyway) values[key] = value;
    return saveResult;
  }

  @override
  Future<bool> remove(String key) async {
    removes++;
    if (removeThrows) throw Exception('disk error');
    if (hangOnRemove) await Completer<void>().future;
    values.remove(key);
    return true;
  }

  @override
  Object? get(String key) => values[key];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
