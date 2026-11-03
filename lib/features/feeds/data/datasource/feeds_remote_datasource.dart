import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/models/ad_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedsRemoteDataSource {
  final FirebaseFirestore firestore;
  final SessionGate sessionGate;

  FeedsRemoteDataSource(this.firestore, this.sessionGate);

  Future<List<AdModel>> getAds() async {
    try {
      final snapshot = await sessionGate.run(
        () => firestore.collection('ads').get(),
      );

      return snapshot.docs.map((doc) {
        return AdModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> addAd(AdModel ad) async {
    try {
      await sessionGate.run(() => firestore.collection('ads').add(ad.toMap()));
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> deleteAd(String id) async {
    try {
      await sessionGate.run(
        () => firestore.collection('ads').doc(id).delete(),
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
