import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRemoteDatasource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  AuthRemoteDatasource(this.auth, this.firestore);
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
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
