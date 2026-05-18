bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

bool isValidPassword(String password) {
  return password.length >= 6;
}

String normalizeName(String name) {
  return name.trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool isValidFullName(String name) {
  final normalized = normalizeName(name);

  if (normalized.length < 3 || normalized.length > 50) {
    return false;
  }

  final parts = normalized.split(' ');
  if (parts.length < 2) {
    return false;
  }

  final nameRegex = RegExp(r"^[a-zA-Z\u0600-\u06FF ]+$");

  return nameRegex.hasMatch(normalized);
}
