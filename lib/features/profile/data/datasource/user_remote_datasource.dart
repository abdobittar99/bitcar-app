import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRemoteDatasource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final SessionGate sessionGate;

  UserRemoteDatasource(this.firestore, this.auth, this.sessionGate);

  Future<AppUserModel> getCurrentUserProfile() async {
    final uid = auth.currentUser!.uid;

    try {
      final doc = await sessionGate.run(
        () => firestore.collection('users').doc(uid).get(),
      );
      if (!doc.exists) {
        throw AppException(
          message: 'User data missing',
          type: ErrorType.server,
        );
      }

      return AppUserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<AppUserModel> updateUser(AppUserModel user) async {
    try {
      await sessionGate.run(
        () => firestore.collection('users').doc(user.id).update(user.toMap()),
      );
      return user;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
