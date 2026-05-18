import 'package:car_shop/entities/car.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CarModel extends CarEntity {
  final List<String> searchKeywords;
  CarModel({
    required super.id,
    required super.model,
    required super.brand,
    required super.year,
    required super.price,
    required super.location,
    required super.description,
    required super.phone,
    required super.images,
    required super.sellerId,
    required super.color,
    required super.carCondition,
    required super.createdAt,
    required this.searchKeywords,
    required super.bodyType,
    required super.fuelType,
    required super.mileage,
    required super.horsePower,
  });

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'brand': brand,
      'year': year,
      'price': price,
      'location': location,
      'description': description,
      'phone': phone,
      'images': images,
      'sellerId': sellerId,
      'color': color,
      'condition': carCondition,
      'createdAt': FieldValue.serverTimestamp(),
      'searchKeywords': searchKeywords,
      'bodyType': bodyType,
      'fuelType': fuelType,
      'mileage': mileage,
     'horsePower': horsePower,
    };
  }

  CarModel copyWith({
    String? id,
    String? model,
    String? brand,
    int? year,
    int? price,
    String? location,
    String? description,
    String? phone,
    List<String>? images,
    String? sellerId,
    String? color,
    String? carCondition,
    DateTime? createdAt,
    List<String>? searchkeywords,
    String? bodyType,
    String? fuelType,
    int? mileage,
    int? horsePower,
  }) {
    return CarModel(
      id: id ?? this.id,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      year: year ?? this.year,
      price: price ?? this.price,
      location: location ?? this.location,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      images: images ?? this.images,
      sellerId: sellerId ?? this.sellerId,
      color: color ?? this.color,
      carCondition: carCondition ?? this.carCondition,
      createdAt: createdAt ?? this.createdAt,
      searchKeywords: searchkeywords ?? [],
      bodyType: bodyType ?? this.bodyType,
      fuelType: fuelType ?? this.fuelType,
      mileage: mileage ?? this.mileage,
      horsePower: horsePower ?? this.horsePower,
    );
  }

  factory CarModel.fromMap(Map<String, dynamic> map, String id) {
    return CarModel(
      id: id,
      model: map['model'] as String,
      brand: map['brand'] as String,
      year: (map['year'] as num).toInt(),
      price: (map['price'] as num).toInt(),
      location: map['location'] as String,
      description: map['description'] as String,
      phone: map['phone'] as String,
      images: (map['images'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      color: map['color'] as String,
      carCondition: map['condition'] as String,
      sellerId: map['sellerId'] as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      searchKeywords: (map['searchKeywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      bodyType: map['bodyType'] as String,
      fuelType: map['fuelType'] as String,
      mileage: (map['mileage'] as num).toInt(),
      horsePower: (map['horsePower'] as num).toInt(),
    );
  }

  factory CarModel.fromEntity(CarEntity car) {
    return CarModel(
      id: car.id,
      model: car.model,
      brand: car.brand,
      year: car.year,
      price: car.price,
      location: car.location,
      description: car.description,
      phone: car.phone,
      images: car.images,
      color: car.color,
      carCondition: car.carCondition,
      sellerId: car.sellerId,
      createdAt: car.createdAt,
      searchKeywords: const [],
      bodyType: car.bodyType,
      fuelType: car.fuelType,
      mileage: car.mileage,
      horsePower: car.horsePower,
    );
  }
}
