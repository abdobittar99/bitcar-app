import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';

enum SessionGateState { open, closing, wipePending }

// Every Firestore future goes through run() and every Firestore stream through watch(),
// so sign-out can stop all user listeners and refuse new work before the local cache is wiped
// (research D18, FR-053).
class SessionGate {
  static const signOutIncompleteMessage =
      'Could not finish signing out. Please restart the app to complete it.';
  static const wipePendingMessage =
      'Previous session data could not be cleared. Please try again.';

  SessionGateState _state = SessionGateState.open;
  bool _signOutIncomplete = false;
  int _inFlight = 0;
  Completer<void>? _drained;
  Future<void>? _retrying;
  final Set<_ActiveStream> _streams = {};

  // Set at DI time to the datasource method that completes a pending wipe.
  // It opens the gate on success and marks the wipe pending again on failure.
  Future<void> Function()? retryWipe;

  SessionGateState get state => _state;

  bool get isOpen => _state == SessionGateState.open;

  bool get isSignOutIncomplete => _signOutIncomplete;

  Future<T> run<T>(Future<T> Function() op) async {
    // Count the operation synchronously while open, so a sign-out starting right after sees it.
    if (!isOpen) await _ensureOpen();
    _inFlight++;
    try {
      return await op();
    } finally {
      _inFlight--;
      if (_inFlight == 0 && !(_drained?.isCompleted ?? true)) {
        _drained!.complete();
      }
    }
  }

  Stream<T> watch<T>(Stream<T> Function() open) {
    late final StreamController<T> controller;
    _ActiveStream? active;

    controller = StreamController<T>(
      onListen: () {
        if (!isOpen) {
          controller.addError(_refusal());
          controller.close();
          return;
        }
        final sub = open().listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            _streams.remove(active);
            controller.close();
          },
        );
        active = _ActiveStream(sub, controller);
        _streams.add(active!);
      },
      onPause: () => active?.subscription.pause(),
      onResume: () => active?.subscription.resume(),
      onCancel: () async {
        _streams.remove(active);
        await active?.subscription.cancel();
      },
    );
    return controller.stream;
  }

  // Refuses new work, cancels every registered stream (listeners receive done, not an error)
  // and waits for in-flight operations, at most [drainTimeout].
  Future<void> closeForSignOut({
    Duration drainTimeout = const Duration(seconds: 5),
  }) async {
    _state = SessionGateState.closing;

    final active = _streams.toList();
    _streams.clear();
    for (final stream in active) {
      await stream.close();
    }

    if (_inFlight > 0) {
      _drained = Completer<void>();
      await _drained!.future.timeout(drainTimeout, onTimeout: () {});
      _drained = null;
    }
  }

  void markWipePending() => _state = SessionGateState.wipePending;

  // auth.signOut() failed, so the user is still signed in: nothing may reach Firestore, and no
  // wipe retry may open the gate, until the next app start finishes the sign-out (research D18).
  void markSignOutIncomplete() {
    _signOutIncomplete = true;
    _state = SessionGateState.wipePending;
  }

  void open() {
    _signOutIncomplete = false;
    _state = SessionGateState.open;
  }

  Future<void> _ensureOpen() async {
    if (isOpen) return;
    if (_state == SessionGateState.wipePending &&
        !_signOutIncomplete &&
        retryWipe != null) {
      _retrying ??= retryWipe!().whenComplete(() => _retrying = null);
      await _retrying;
      if (isOpen) return;
    }
    throw _refusal();
  }

  AppException _refusal() {
    if (_signOutIncomplete) {
      return AppException(
        message: signOutIncompleteMessage,
        type: ErrorType.auth,
      );
    }
    if (_state == SessionGateState.wipePending) {
      return AppException(
        message: wipePendingMessage,
        type: ErrorType.cache,
      );
    }
    return AppException(
      message: 'Signing out, please wait',
      type: ErrorType.auth,
    );
  }
}

class _ActiveStream {
  final StreamSubscription<dynamic> subscription;
  final StreamController<dynamic> controller;

  _ActiveStream(this.subscription, this.controller);

  Future<void> close() async {
    await subscription.cancel();
    await controller.close();
  }
}
