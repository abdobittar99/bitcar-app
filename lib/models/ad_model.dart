import 'package:car_shop/entities/ad.dart';

class AdModel extends AdEntity {
  const AdModel({
    required super.id,
    required super.image,
    required super.whatsappLink,
    required super.order,
    required super.expiryDate,
  });

  factory AdModel.fromMap(Map<String, dynamic> data, String id) {
    return AdModel(
      id: id,
      image: data['image'],
      whatsappLink: data['whatsappLink'],
      order: data['order'],
      expiryDate: DateTime.parse(data['expiryDate']),
    );
  }

  factory AdModel.fromEntity(AdEntity ad) {
    return AdModel(
      id: ad.id,
      image: ad.image,
      whatsappLink: ad.whatsappLink,
      order: ad.order,
      expiryDate: ad.expiryDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "image": image,
      "whatsappLink": whatsappLink,
      "order": order,
      "expiryDate": expiryDate.toIso8601String(),
    };
  }
}
