import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/models/ad_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedsRemoteDataSource {
  final FirebaseFirestore firestore;

  FeedsRemoteDataSource(this.firestore);

  Future<List<AdModel>> getAds() async {
    try {
      final snapshot = await firestore.collection('ads').get();

      return snapshot.docs.map((doc) {
        return AdModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> addAd(AdModel ad) async {
    try {
      await firestore.collection('ads').add(ad.toMap());
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> deleteAd(String id) async {
    try {
      await firestore.collection('ads').doc(id).delete();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
