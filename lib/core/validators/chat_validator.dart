class ChatValidator {
  static const maxLength = 1000;

  // Rate limit (FR-014a): enforced by the security rules, pre-checked on the device.
  static const maxMessagesPerMinute = 20;
  static const rateLimitMessage =
      "You're sending messages too fast, try again shortly";

  static String? validate(String text) {
    final v = text.trim();
    if (v.isEmpty) return 'Message cannot be empty';
    if (v.length > maxLength) {
      return 'Message is too long (max 1,000 characters)';
    }
    return null;
  }
}
