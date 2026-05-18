class CarEntity {
  final String id;
  final String model;
  final String brand;
  final int year;
  final int price;
  final String location;
  final String description;
  final String phone;
  final List<String> images;
  final String sellerId;
  final String color;
  final String? carCondition;
  final DateTime createdAt;
  final String bodyType;
  final String fuelType;
  final int mileage;
  final int horsePower;

  CarEntity({
    required this.id,
    required this.model,
    required this.brand,
    required this.year,
    required this.price,
    required this.location,
    required this.description,
    required this.phone,
    required this.images,
    required this.sellerId,
    required this.color,
    required this.carCondition,
    required this.createdAt,
    required this.bodyType,
    required this.fuelType,
    required this.mileage,
    required this.horsePower,
  });
}
