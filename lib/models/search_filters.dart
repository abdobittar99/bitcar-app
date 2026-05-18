import 'package:equatable/equatable.dart';

class SearchFilters extends Equatable {
  final String? brand;
  final String? location;
  final String? color;
  final String? condition;
  final String? bodyType;
  final String? fuelType;

  final int? minPrice;
  final int? maxPrice;

  final int? minYear;

  const SearchFilters({
    this.bodyType,
    this.fuelType,
    this.brand,
    this.location,
    this.color,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.minYear,
  });
  @override
  List<Object?> get props => [
    bodyType,
    fuelType,
    brand,
    location,
    color,
    condition,
    minPrice,
    maxPrice,
    minYear,
  ];

  bool get isEmpty =>
      brand == null &&
      bodyType == null &&
      fuelType == null &&
      location == null &&
      color == null &&
      condition == null &&
      minPrice == null &&
      maxPrice == null &&
      minYear == null;

  int get activeFiltersCount {
    int count = 0;
    if (brand != null) count++;
    if (bodyType != null) count++;
    if (fuelType != null) count++;
    if (location != null) count++;
    if (color != null) count++;
    if (condition != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minYear != null) count++;
    return count;
  }

  SearchFilters copyWith({
    String? Function()? brand,
    String? Function()? location,
    String? Function()? bodyType,
    String? Function()? fuelType,

    String? Function()? color,
    String? Function()? condition,
    int? minPrice,
    int? maxPrice,
    int? Function()? minYear,
  }) {
    return SearchFilters(
      brand: brand != null ? brand() : this.brand,
      bodyType: bodyType != null ? bodyType() : this.bodyType,
      fuelType: fuelType != null ? fuelType() : this.fuelType,
      location: location != null ? location() : this.location,
      color: color != null ? color() : this.color,
      condition: condition != null ? condition() : this.condition,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minYear: minYear != null ? minYear() : this.minYear,
    );
  }
}
