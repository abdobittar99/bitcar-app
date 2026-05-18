import 'package:car_shop/entities/car.dart';

abstract class CarFormEvent {}

class EditCarStarted extends CarFormEvent {
  final CarEntity car;
  EditCarStarted(this.car);
}

class UpdateCarSubmitted extends CarFormEvent {}

class AddCarModelChanged extends CarFormEvent {
  final String model;
  AddCarModelChanged(this.model);
}

class AddCarBrandChanged extends CarFormEvent {
  final String brand;
  AddCarBrandChanged(this.brand);
}

class AddCarYearChanged extends CarFormEvent {
  final int? year;
  AddCarYearChanged(this.year);
}

class AddCarPriceChanged extends CarFormEvent {
  final int price;
  AddCarPriceChanged(this.price);
}

class AddCarLocationChanged extends CarFormEvent {
  final String location;
  AddCarLocationChanged(this.location);
}

class AddCarDescriptionChanged extends CarFormEvent {
  final String description;
  AddCarDescriptionChanged(this.description);
}

class AddCarContactChanged extends CarFormEvent {
  final String phone;
  AddCarContactChanged(this.phone);
}

class AddCarImagesChanged extends CarFormEvent {
  final List<String> images;
  AddCarImagesChanged(this.images);
}

class AddCarColorChanged extends CarFormEvent {
  final String? color;
  AddCarColorChanged(this.color);
}

class AddCarConditionChanged extends CarFormEvent {
  final String? carCondition;
  AddCarConditionChanged(this.carCondition);
}

class AddCarBodyTypeChanged extends CarFormEvent {
  final String? bodyType;
  AddCarBodyTypeChanged(this.bodyType);
}

class AddCarFuelTypeChanged extends CarFormEvent {
  final String? fuelType;
  AddCarFuelTypeChanged(this.fuelType);
}

class AddCarMileageChanged extends CarFormEvent {
  final int? mileage;
  AddCarMileageChanged(this.mileage);
}

class AddCarHorsePowerChanged extends CarFormEvent {
  final int? horsePower;
  AddCarHorsePowerChanged(this.horsePower);
}

class AddCarPickImagesPressed extends CarFormEvent {}

class AddCarNextStepPressed extends CarFormEvent {}

class AddCarPreviousStepPressed extends CarFormEvent {}

class AddCarSubmitted extends CarFormEvent {}
