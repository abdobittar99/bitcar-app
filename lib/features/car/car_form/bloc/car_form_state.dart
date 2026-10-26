import 'package:car_shop/core/enums/add_car_steps.dart';
import 'package:car_shop/core/enums/car_form_mode.dart';
import 'package:car_shop/entities/car.dart';

class CarFormState {
  final CarFormMode mode;
  final CarEntity? originalCar;
  final String? carId;
  final AddCarStep step;
  final String model;
  final String brand;
  final int year;
  final int price;
  final String location;
  final String description;
  final String phone;
  final List<String>? images;
  final String color;
  final String carCondition;
  final String bodyType;
  final String fuelType;
  final int mileage;
  final int horsePower;
  final bool isLoading;
  final bool isSuccess;
  final bool isUpdated;
  final String? error;

  const CarFormState({
    this.mode = CarFormMode.add,
    this.originalCar,
    this.carId,
    this.step = AddCarStep.details,
    this.model = '',
    this.brand = '',
    this.year = 0,
    this.price = 0,
    this.location = '',
    this.description = '',
    this.phone = '',
    this.images,
    this.bodyType = "",
    this.fuelType = "",
    this.mileage = 0,
    this.horsePower = 0,
    this.color = 'blackk',
    this.carCondition = '',
    this.isUpdated = false,
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });
  bool get isDetailsStep => step == AddCarStep.details;
  bool get isImagesStep => step == AddCarStep.images;
  bool get isContactStep => step == AddCarStep.contact;

  CarFormState copyWith({
    CarEntity? originalCar,
    CarFormMode? mode,
    String? carId,
    AddCarStep? step,
    String? model,
    String? brand,
    int? year,
    int? price,
    String? location,
    String? description,
    String? phone,
    List<String>? images,
    String? color,
    String? carCondition,
    String? bodyType,
    String? fuelType,
    int? mileage,
    int? horsePower,
    bool? isLoading,
    bool? isSuccess,
    bool? isUpdated,
    String? error,
  }) {
    return CarFormState(
      mode: mode ?? this.mode,
      originalCar: originalCar ?? this.originalCar,
      carId: carId ?? this.carId,
      step: step ?? this.step,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      year: year ?? this.year,
      price: price ?? this.price,
      location: location ?? this.location,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      images: images ?? this.images,
      color: color ?? this.color,
      carCondition: carCondition ?? this.carCondition,
      bodyType: bodyType ?? this.bodyType,
      fuelType: fuelType ?? this.fuelType,
      mileage: mileage ?? this.mileage,
      horsePower: horsePower ?? this.horsePower,
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      isUpdated: isUpdated ?? this.isUpdated,
      error: error,
    );
  }
}
