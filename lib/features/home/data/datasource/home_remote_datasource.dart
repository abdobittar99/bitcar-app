import 'dart:async';

import 'package:car_shop/core/cache/cache_helper.dart';
import 'package:car_shop/core/cache/cache_keys.dart';
import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final SessionGate sessionGate;

  HomeRemoteDataSource(this.auth, this.firestore, this.sessionGate);

  Future<AppUserModel> getCurrentUser() async {
    try {
      final user = auth.currentUser;

      if (user == null) {
        throw AppException(
          message: 'user has logged out ',
          type: ErrorType.auth,
        );
      }

      final doc = await sessionGate.run(
        () => firestore.collection('users').doc(user.uid).get(),
      );

      if (!doc.exists) {
        throw AppException(
          message: 'User data missing',
          type: ErrorType.server,
        );
      }
      return AppUserModel.fromMap(doc.data()!, user.uid);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // True when writes are still waiting for the server. It only times out with unsynced writes or
  // a slow network, so it can warn when not needed but never misses a change (research D18).
  Future<bool> hasPendingWrites() async {
    _throwIfSignOutIncomplete();
    try {
      await firestore.waitForPendingWrites().timeout(const Duration(seconds: 3));
      return false;
    } on TimeoutException {
      return true;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // Sign-out sequence of research D18 step 3. These methods manage the gate, so they do not go
  // through sessionGate.run. The marker is removed last: if the app is killed before that, the
  // next start wipes again, which is harmless, and finishes the sign-out.
  Future<void> logOut() async {
    _throwIfSignOutIncomplete();
    await sessionGate.closeForSignOut();
    final wiped = await _wipe(saveMarker: true);
    if (!await _signOut()) {
      sessionGate.markSignOutIncomplete();
      throw AppException(
        message: SessionGate.signOutIncompleteMessage,
        type: ErrorType.auth,
      );
    }
    if (!wiped) {
      sessionGate.markWipePending();
      throw AppException(
        message: SessionGate.wipePendingMessage,
        type: ErrorType.cache,
      );
    }
    await _finish();
  }

  // Startup, before runApp: finishes a sign-out that did not complete. It never throws; a failure
  // leaves the gate blocking Firestore (research D18 step 4).
  Future<void> completePendingSignOut() async {
    if (CacheHelper.getData(key: CacheKeys.firestoreWipePending) != true) return;
    final wiped = await _wipe();
    if (!await _signOut()) {
      sessionGate.markSignOutIncomplete();
      return;
    }
    if (!wiped) {
      sessionGate.markWipePending();
      return;
    }
    await _finish();
  }

  // The gate's retryWipe, after a failed wipe. It only wipes and never signs out: by then the
  // sign-out is finished, and another user may be signed in (research D18 step 4).
  Future<void> retryPendingWipe() async {
    if (await _wipe()) await _finish();
  }

  void _throwIfSignOutIncomplete() {
    if (sessionGate.isSignOutIncomplete) {
      throw AppException(
        message: SessionGate.signOutIncompleteMessage,
        type: ErrorType.auth,
      );
    }
  }

  // A failure is not lost: the callers report it through the gate state and the marker.
  Future<bool> _wipe({bool saveMarker = false}) async {
    try {
      if (saveMarker) {
        await CacheHelper.saveData(
          key: CacheKeys.firestoreWipePending,
          value: true,
        );
      }
      await firestore.terminate();
      await firestore.clearPersistence();
      return true;
    } on Exception {
      return false;
    }
  }

  Future<bool> _signOut() async {
    try {
      await auth.signOut();
      return true;
    } on Exception {
      return false;
    }
  }

  // The wipe and sign-out are done, so a marker that could not be removed must not block the app:
  // the next start only repeats a harmless wipe and sign-out.
  Future<void> _finish() async {
    try {
      await CacheHelper.removeData(key: CacheKeys.firestoreWipePending);
    } on Exception {
      // Reported by the marker itself, which the next start handles.
    }
    sessionGate.open();
  }
}
