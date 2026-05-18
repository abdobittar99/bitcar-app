import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/utils/image_diff.dart';
import 'package:car_shop/core/utils/search_utils.dart';
import 'package:car_shop/models/car_model.dart';
import 'package:car_shop/modules/car/car_list/domain/model/cars_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CarsRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  CarsRemoteDataSource(this.firestore, this.auth);

  Future<CarsPage> getInitialCars({int limit = 10}) async {
    try {
      final snapshot = await firestore
          .collection('cars')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final cars = snapshot.docs
          .map((d) => CarModel.fromMap(d.data(), d.id))
          .toList();

      return CarsPage(
        cars: cars,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasReachedEnd: snapshot.docs.length < limit,
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<CarsPage> getMoreCars({
    required DocumentSnapshot lastDoc,
    int limit = 10,
  }) async {
    try {
      final snapshot = await firestore
          .collection('cars')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(limit)
          .get();

      final cars = snapshot.docs
          .map((d) => CarModel.fromMap(d.data(), d.id))
          .toList();

      return CarsPage(
        cars: cars,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : lastDoc,
        hasReachedEnd: snapshot.docs.length < limit,
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<CarModel>> loadMoreCars(DocumentSnapshot lastDoc) async {
    try {
      final snapshot = await firestore
          .collection('cars')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => CarModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<CarModel>> getMyCars(String uid) async {
    try {
      final snapshot = await firestore
          .collection('cars')
          .where('sellerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((d) => CarModel.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> updateCarDetails(
    String id,
    Map<String, dynamic> changes,
    ImageDiff diff,
  ) async {
    try {
      if (!diff.hasChanges && changes.isEmpty) return;

      final affectsSearch =
          changes.containsKey('model') ||
          changes.containsKey('brand') ||
          changes.containsKey('year') ||
          changes.containsKey('location');

      if (affectsSearch) {
        final doc = await firestore.collection('cars').doc(id).get();
        final data = doc.data() as Map<String, dynamic>;

        final merged = {...data, ...changes};

        changes['searchKeywords'] = generateSearchKeywords(
          brand: merged['brand'],
          model: merged['model'],

          year: merged['year'],
          location: merged['location'],
        );
      }

      changes['updatedAt'] = FieldValue.serverTimestamp();

      await firestore.collection('cars').doc(id).update(changes);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> updateCar(CarModel car) async {
    try {
      await firestore.collection('cars').doc(car.id).update(car.toMap());
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> addCar(CarModel car) async {
    try {
      final user = auth.currentUser;
      if (user == null) {
        throw AppException(message: 'user not found', type: ErrorType.auth);
      }

      final doc = firestore.collection('cars').doc();

      final keywords = generateSearchKeywords(
        brand: car.brand,
        model: car.model,

        year: car.year,
        location: car.location,
      );

      final carWithId = car.copyWith(id: doc.id, searchkeywords: keywords);

      await doc.set(carWithId.toMap());
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> deleteCar(String id) async {
    try {
      await firestore.collection('cars').doc(id).delete();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<CarModel> getCar(String id) async {
    try {
      final doc = await firestore.collection('cars').doc(id).get();

      if (!doc.exists) throw Exception('Car not found');

      return CarModel.fromMap(doc.data()!, id);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
