import 'package:car_shop/features/car/car_form/bloc/car_form_state.dart';

class CarValidator {
  static String? validateDetails(CarFormState s) {
    if (s.model.isEmpty ||
        s.brand.isEmpty ||
        s.year < 1900 ||
        s.price <= 0 ||
        s.location.isEmpty ||
        s.carCondition.isEmpty ||
        s.bodyType.isEmpty ||
        s.fuelType.isEmpty ||
        s.mileage == 0 ||
        s.color.isEmpty) {
      return 'Please fill all car details';
    }
    return null;
  }

  static String? validateImages(CarFormState s) {
    if (s.images == null || s.images!.length < 3) {
      return 'Please add at least 3 images';
    }
    return null;
  }

  static String? validateContact(CarFormState s) {
    final v = s.phone.trim();
    if (v.isEmpty) return 'Please enter phone number';
    if (!RegExp(r'^\d{7,15}$').hasMatch(v)) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
