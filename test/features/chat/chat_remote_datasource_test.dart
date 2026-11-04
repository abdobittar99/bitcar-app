import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/errors/mapper/error_mapper.dart';
import 'package:car_shop/features/chat/data/datasource/chat_remote_datasource.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException denied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

void main() {
  group('retryOnceOnPermissionDenied', () {
    late int attempts;

    // Runs one scripted result per attempt: an exception to throw, or a value to return.
    Future<String> run(List<Object> script) {
      attempts = 0;
      return ChatRemoteDataSource.retryOnceOnPermissionDenied<String>(() async {
        final result = script[attempts++];
        if (result is Exception) throw result;
        return result as String;
      });
    }

    test('success: one attempt', () async {
      expect(await run(['done']), 'done');
      expect(attempts, 1);
    });

    test('denied, then success: two attempts', () async {
      expect(await run([denied(), 'done']), 'done');
      expect(attempts, 2);
    });

    test('denied twice: the error reaches the caller after two attempts, never a success', () async {
      await expectLater(
        run([denied(), denied(), 'must not run']),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied'),
        ),
      );
      expect(attempts, 2);
    });

    test('a real denial maps to a permission error, not a success', () async {
      Object? mapped;
      try {
        await run([denied(), denied()]);
      } catch (e) {
        mapped = ErrorMapper.map(e);
      }
      expect(mapped, isA<AppException>().having((e) => e.type, 'type', ErrorType.permission));
    });

    for (final code in ['unavailable', 'aborted', 'failed-precondition', 'not-found']) {
      test('$code is not retried', () async {
        await expectLater(
          run([FirebaseException(plugin: 'cloud_firestore', code: code), 'must not run']),
          throwsA(isA<FirebaseException>().having((e) => e.code, 'code', code)),
        );
        expect(attempts, 1);
      });
    }

    test('an error after the retry is the one that reaches the caller', () async {
      await expectLater(
        run([denied(), FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')]),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );
      expect(attempts, 2);
    });

    test('a non-Firebase error is not retried', () async {
      await expectLater(
        run([AppException(message: 'Message not found', type: ErrorType.notFound), 'must not run']),
        throwsA(isA<AppException>().having((e) => e.type, 'type', ErrorType.notFound)),
      );
      expect(attempts, 1);
    });
  });

  group('isUnseen', () {
    final at = Timestamp(1000, 500);
    final before = Timestamp(1000, 499);
    final after = Timestamp(1000, 501);

    test('nothing read or cleared: unseen', () {
      expect(ChatRemoteDataSource.isUnseen(at), isTrue);
    });

    test('read before the message: unseen', () {
      expect(ChatRemoteDataSource.isUnseen(at, lastReadAt: before), isTrue);
    });

    test('read at or after the message: seen', () {
      expect(ChatRemoteDataSource.isUnseen(at, lastReadAt: at), isFalse);
      expect(ChatRemoteDataSource.isUnseen(at, lastReadAt: after), isFalse);
    });

    test('cleared at or after the message: seen, even if never read', () {
      expect(ChatRemoteDataSource.isUnseen(at, clearedAt: at), isFalse);
      expect(ChatRemoteDataSource.isUnseen(at, clearedAt: after), isFalse);
    });

    test('newer than both: unseen; older than either: seen', () {
      expect(ChatRemoteDataSource.isUnseen(at, lastReadAt: before, clearedAt: before), isTrue);
      expect(ChatRemoteDataSource.isUnseen(at, lastReadAt: before, clearedAt: after), isFalse);
      expect(ChatRemoteDataSource.isUnseen(at, lastReadAt: after, clearedAt: before), isFalse);
    });
  });
}
