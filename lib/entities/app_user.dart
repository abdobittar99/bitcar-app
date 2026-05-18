import 'package:car_shop/core/enums/user_role.dart';

class UserEntity {
  final String fullName;
  final String id;
  final String email;
  final String phone;
  final UserRole role;

  UserEntity({
    required this.fullName,
    required this.id,
    required this.email,
    required this.phone,
    required this.role,
  });
}
