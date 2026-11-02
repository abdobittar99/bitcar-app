class ChatValidator {
  static const maxLength = 1000;

  static String? validate(String text) {
    final v = text.trim();
    if (v.isEmpty) return 'Message cannot be empty';
    if (v.length > maxLength) {
      return 'Message is too long (max 1,000 characters)';
    }
    return null;
  }
}
