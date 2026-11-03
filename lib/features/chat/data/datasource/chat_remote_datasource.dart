import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// The only chat class that talks to Firestore and Auth. Returns models (or records of models),
// never domain types; ChatRepositoryImpl builds the domain wrappers (constitution I).
class ChatRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final SessionGate sessionGate;

  ChatRemoteDataSource(this.firestore, this.auth, this.sessionGate);

  static const placeholderName = 'BitCar user';

  String get currentUserId {
    final user = auth.currentUser;
    if (user == null) {
      throw AppException(message: 'User not logged in', type: ErrorType.auth);
    }
    return user.uid;
  }

  // Writes own publicProfiles/{uid} only when it is missing or different (research D14).
  Future<void> syncPublicProfile(String displayName) async {
    try {
      await sessionGate.run(() async {
        final ref = firestore.collection('publicProfiles').doc(currentUserId);
        final doc = await ref.get();
        if (doc.exists && doc.data()?['displayName'] == displayName) return;
        await ref.set({'displayName': displayName});
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // Public name of a user, or the placeholder when they have no public profile.
  Future<String> readPublicName(String uid) async {
    try {
      final doc = await sessionGate.run(
        () => firestore.collection('publicProfiles').doc(uid).get(),
      );
      return doc.data()?['displayName'] as String? ?? placeholderName;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  // Every chat stream goes through the session gate. When the session is ending
  // (gate closing for sign-out, or no signed-in user) the stream is closed without an error;
  // that is an explicit check, not a blanket catch (constitution III). Any other error is
  // mapped with ErrorMapper and reaches the bloc.
  Stream<T> watchGuarded<T>(Stream<T> Function() open) {
    return sessionGate
        .watch(open)
        .transform(
          StreamTransformer<T, T>.fromHandlers(
            handleError: (error, stackTrace, sink) {
              if (_sessionEnded) {
                sink.close();
                return;
              }
              sink.addError(ErrorMapper.map(error), stackTrace);
            },
          ),
        );
  }

  bool get _sessionEnded =>
      sessionGate.state == SessionGateState.closing || auth.currentUser == null;
}
