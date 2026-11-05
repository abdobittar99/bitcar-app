import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

TypeMatcher<AppException> appException(ErrorType type) =>
    isA<AppException>().having((e) => e.type, 'type', type);

void main() {
  late SessionGate gate;

  setUp(() => gate = SessionGate());

  group('open', () {
    test('run executes the operation and returns its value', () async {
      expect(await gate.run(() async => 42), 42);
      expect(gate.isOpen, isTrue);
    });

    test('run passes the operation error through unchanged', () async {
      final error = AppException(message: 'x', type: ErrorType.network);
      await expectLater(gate.run(() async => throw error), throwsA(same(error)));
    });

    test('watch forwards data, errors and done', () async {
      final source = StreamController<int>();
      final events = <Object>[];
      final done = Completer<void>();
      gate.watch(() => source.stream).listen(
            events.add,
            onError: events.add,
            onDone: done.complete,
          );
      source.add(1);
      source.addError('boom');
      await source.close();
      await done.future;
      expect(events, [1, 'boom']);
    });
  });

  group('closeForSignOut', () {
    test('refuses new run calls with an auth AppException', () async {
      await gate.closeForSignOut();
      expect(gate.isOpen, isFalse);
      await expectLater(
        gate.run(() async => 1),
        throwsA(appException(ErrorType.auth)),
      );
    });

    test('refuses new watch calls with an auth AppException on the stream', () async {
      await gate.closeForSignOut();
      var opened = false;
      await expectLater(
        gate.watch(() {
          opened = true;
          return const Stream<int>.empty();
        }),
        emitsInOrder([emitsError(appException(ErrorType.auth)), emitsDone]),
      );
      expect(opened, isFalse);
    });

    test('cancels every registered stream: listeners get done, not an error', () async {
      var sourceCancelled = false;
      final source = StreamController<int>(onCancel: () => sourceCancelled = true);
      final errors = <Object>[];
      final done = Completer<void>();
      gate.watch(() => source.stream).listen(
            (_) {},
            onError: errors.add,
            onDone: done.complete,
          );
      await Future<void>.delayed(Duration.zero);

      await gate.closeForSignOut();

      await done.future;
      expect(sourceCancelled, isTrue);
      expect(errors, isEmpty);
    });

    test('waits for in-flight operations before completing', () {
      fakeAsync((async) {
        final release = Completer<void>();
        unawaited(gate.run(() => release.future));
        var closed = false;
        gate.closeForSignOut().then((_) => closed = true);

        async.elapse(const Duration(seconds: 4));
        expect(closed, isFalse);

        release.complete();
        async.flushMicrotasks();
        expect(closed, isTrue);
      });
    });

    test('stops waiting for in-flight operations after the 5 s drain timeout', () {
      fakeAsync((async) {
        unawaited(gate.run(() => Completer<void>().future));
        var closed = false;
        gate.closeForSignOut().then((_) => closed = true);

        async.elapse(const Duration(seconds: 4, milliseconds: 999));
        expect(closed, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(closed, isTrue);
        expect(gate.state, SessionGateState.closing);
      });
    });

    test('honours a custom drainTimeout', () {
      fakeAsync((async) {
        unawaited(gate.run(() => Completer<void>().future));
        var closed = false;
        gate
            .closeForSignOut(drainTimeout: const Duration(seconds: 1))
            .then((_) => closed = true);

        async.elapse(const Duration(milliseconds: 999));
        expect(closed, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(closed, isTrue);
      });
    });

    test('open restores normal operation', () async {
      await gate.closeForSignOut();
      gate.open();
      expect(await gate.run(() async => 'ok'), 'ok');
    });
  });

  group('wipePending', () {
    const failureMessage =
        'Previous session data could not be cleared. Please try again.';

    test('run retries the wipe once and continues when it succeeds', () async {
      var attempts = 0;
      gate.retryWipe = () async {
        attempts++;
        gate.open();
      };
      gate.markWipePending();

      expect(await gate.run(() async => 'data'), 'data');
      expect(attempts, 1);
      expect(gate.isOpen, isTrue);
    });

    test('run is refused with a cache AppException when the retry fails', () async {
      var attempts = 0;
      gate.retryWipe = () async {
        attempts++;
        gate.markWipePending();
      };
      gate.markWipePending();
      var ran = false;

      await expectLater(
        gate.run(() async => ran = true),
        throwsA(
          appException(ErrorType.cache)
              .having((e) => e.message, 'message', failureMessage),
        ),
      );
      expect(attempts, 1);
      expect(ran, isFalse);
    });

    test('concurrent calls share a single wipe retry', () async {
      var attempts = 0;
      final finish = Completer<void>();
      gate.retryWipe = () async {
        attempts++;
        await finish.future;
        gate.open();
      };
      gate.markWipePending();

      final first = gate.run(() async => 1);
      final second = gate.run(() async => 2);
      finish.complete();

      expect(await Future.wait([first, second]), [1, 2]);
      expect(attempts, 1);
    });

    test('without a retryWipe callback, run is refused', () async {
      gate.markWipePending();
      await expectLater(
        gate.run(() async => 1),
        throwsA(appException(ErrorType.cache)),
      );
    });

    test('the refusal after a failed wipe has the wipe message', () async {
      gate.markWipePending();
      await expectLater(
        gate.run(() async => 1),
        throwsA(
          appException(ErrorType.cache).having(
            (e) => e.message,
            'message',
            'Previous session data could not be cleared. Please try again.',
          ),
        ),
      );
      expect(gate.isSignOutIncomplete, isFalse);
    });
  });

  group('sign-out incomplete', () {
    late int retries;
    late int operations;

    setUp(() {
      retries = 0;
      operations = 0;
      gate.retryWipe = () async {
        retries++;
        gate.open();
      };
      gate.markSignOutIncomplete();
    });

    Matcher signOutRefusal() => throwsA(
      appException(ErrorType.auth).having(
        (e) => e.message,
        'message',
        'Could not finish signing out. Please restart the app to complete it.',
      ),
    );

    test('state is wipePending and it is reported', () {
      expect(gate.state, SessionGateState.wipePending);
      expect(gate.isSignOutIncomplete, isTrue);
    });

    test('run is refused with its own message, without retrying the wipe', () async {
      await expectLater(gate.run(() async => operations++), signOutRefusal());

      expect(operations, 0);
      expect(retries, 0);
      expect(gate.state, SessionGateState.wipePending);
    });

    test('watch is refused with its own message', () async {
      final errors = <Object>[];
      var done = false;
      gate
          .watch(() => Stream<int>.value(1))
          .listen((_) {}, onError: errors.add, onDone: () => done = true);
      await pumpEventQueue();

      expect(errors.single, appException(ErrorType.auth));
      expect(done, isTrue);
    });

    test('markWipePending does not undo it', () async {
      gate.markWipePending();

      expect(gate.isSignOutIncomplete, isTrue);
      await expectLater(gate.run(() async => operations++), signOutRefusal());
      expect(retries, 0);
    });
  });

  // Research D18 step 1: _inFlight is never reset, so it can be too high but never too low.
  group('in-flight count across sessions', () {
    test('an abandoned operation finishing later does not hide a live operation of the new session', () {
      fakeAsync((async) {
        final abandoned = Completer<void>();
        final live = Completer<void>();
        gate.run(() => abandoned.future);

        var firstClosed = false;
        gate.closeForSignOut().then((_) => firstClosed = true);
        async.elapse(const Duration(seconds: 5));
        expect(firstClosed, isTrue);
        gate.open();

        gate.run(() => live.future);
        async.flushMicrotasks();
        abandoned.complete();
        async.flushMicrotasks();

        var secondClosed = false;
        gate.closeForSignOut().then((_) => secondClosed = true);
        async.elapse(const Duration(seconds: 4));
        expect(secondClosed, isFalse, reason: 'the live operation is still counted');

        live.complete();
        async.flushMicrotasks();
        expect(secondClosed, isTrue);
      });
    });

    test('an operation that never finishes only makes the next sign-out wait the full timeout', () {
      fakeAsync((async) {
        gate.run(() => Completer<void>().future);
        gate.closeForSignOut();
        async.elapse(const Duration(seconds: 5));
        gate.open();

        var closed = false;
        gate.closeForSignOut().then((_) => closed = true);
        async.elapse(const Duration(seconds: 4));
        expect(closed, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(closed, isTrue);
      });
    });
  });
}
