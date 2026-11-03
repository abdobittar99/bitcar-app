import 'package:car_shop/core/validators/chat_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatValidator.validate', () {
    test('rejects an empty message', () {
      expect(ChatValidator.validate(''), 'Message cannot be empty');
    });

    test('rejects a whitespace-only message', () {
      expect(ChatValidator.validate('   \n\t '), 'Message cannot be empty');
    });

    test('accepts a single character', () {
      expect(ChatValidator.validate('a'), isNull);
    });

    test('accepts exactly 1,000 characters after trimming', () {
      expect(ChatValidator.validate('  ${'x' * 1000}  '), isNull);
    });

    test('rejects 1,001 characters', () {
      expect(
        ChatValidator.validate('x' * 1001),
        'Message is too long (max 1,000 characters)',
      );
    });
  });
}
