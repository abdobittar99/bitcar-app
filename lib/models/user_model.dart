import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/entities/app_user.dart';

class AppUserModel extends UserEntity {
  AppUserModel({
    required super.fullName,
    required super.id,
    required super.email,
    required super.phone,
    required super.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'role': role.name,
      'id': id,
      'fullName': fullName,
    };
  }

  factory AppUserModel.fromEntity(UserEntity user) {
    return AppUserModel(
      fullName: user.fullName,
      id: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role,
    );
  }

  factory AppUserModel.fromMap(Map<String, dynamic> map, String id) {
    return AppUserModel(
      fullName: map['fullName'] as String,
      id: id,
      email: map['email'],
      phone: map['phone'],
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.buyer,
      ),
    );
  }
}
