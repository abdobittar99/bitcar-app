import 'package:car_shop/core/enums/error_type.dart';

class AppException implements Exception {
  final String message;
  final ErrorType type;

  AppException({required this.message, required this.type});

  @override
  String toString() => message;
}
