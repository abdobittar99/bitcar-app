import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRemoteDatasource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final SessionGate sessionGate;

  AuthRemoteDatasource(this.auth, this.firestore, this.sessionGate);
  Future<void> login({required String email, required String password}) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<AppUserModel> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    try {
      // The gate is checked before the account is created, so a blocked session never
      // leaves an account without its users document.
      return await sessionGate.run(() async {
        final result = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = AppUserModel(
          fullName: fullName,
          id: result.user!.uid,
          email: email,
          phone: phone,
          role: role,
        );

        await firestore.collection('users').doc(user.id).set(user.toMap());

        return user;
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
