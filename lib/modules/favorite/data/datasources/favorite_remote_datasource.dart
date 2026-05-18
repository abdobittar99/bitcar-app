import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/core/utils/list_utils.dart';
import 'package:car_shop/models/car_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  FavoriteRemoteDataSource(this.firestore, this.auth);
  Future<Set<String>> getFavoriteIds() async {
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .get();

      return snapshot.docs.map((d) => d.id).toSet();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<CarModel>> getFavCarsByIds(List<String> ids, String uid) async {
    if (ids.isEmpty) return [];

    final chunks = chunkList(ids, 10);
    List<CarModel> allCars = [];
    Set<String> foundIds = {};

    for (final chunk in chunks) {
      final snapshot = await firestore
          .collection('cars')
          .where(FieldPath.documentId, whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .get();

      final cars = snapshot.docs
          .map((d) => CarModel.fromMap(d.data(), d.id))
          .toList();

      for (final car in cars) {
        foundIds.add(car.id);
      }

      allCars.addAll(cars);
    }

    final missingIds = ids.where((id) => !foundIds.contains(id)).toList();

    if (missingIds.isNotEmpty) {
      final batch = firestore.batch();

      for (final id in missingIds) {
        final ref = firestore
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .doc(id);

        batch.delete(ref);
      }

      await batch.commit();
    }
    return allCars;
  }

  String get uid {
    final user = auth.currentUser;
    if (user == null) {
      throw AppException(message: 'User not logged in', type: ErrorType.auth);
    }
    return user.uid;
  }

  Future<void> addFavorite(String carId) async {
    try {
      await firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(carId)
          .set({'createdAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> removeFavorite(String carId) async {
    try {
      await firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(carId)
          .delete();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
