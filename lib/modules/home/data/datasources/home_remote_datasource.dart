import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  HomeRemoteDataSource(this.auth, this.firestore);

  Future<AppUserModel> getCurrentUser() async {
    try {
      final user = auth.currentUser;

      if (user == null) {
        throw AppException(
          message: 'user has logged out ',
          type: ErrorType.auth,
        );
      }

      final doc = await firestore.collection('users').doc(user.uid).get();

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

  Future<void> logOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
