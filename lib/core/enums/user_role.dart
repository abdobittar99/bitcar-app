enum UserRole { buyer, seller, admin }

extension UserRoleX on UserRole {
  String get value {
    return name;
  }
}

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (e) => e.name == value,
    orElse: () => UserRole.buyer,
  );
}
