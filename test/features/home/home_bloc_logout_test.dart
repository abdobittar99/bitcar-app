import 'dart:async';

import 'package:car_shop/core/cache/cache_helper.dart';
import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/home/bloc/home_event.dart';
import 'package:car_shop/features/home/bloc/home_state.dart';
import 'package:car_shop/features/home/data/datasource/home_remote_datasource.dart';
import 'package:car_shop/features/home/data/repositories/home_repository_impl.dart';
import 'package:car_shop/features/home/domain/repositories/home_repository.dart';
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
import 'package:car_shop/features/home/domain/usecase/has_pending_writes.dart';
import 'package:car_shop/features/home/domain/usecase/logout.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_firebase.dart';

class FakeHomeRepository implements HomeRepository {
  bool pending = false;
  int checks = 0;
  int logOuts = 0;
  AppException? checkError;
  AppException? logOutError;
  Completer<void>? checkGate;
  Completer<void>? logOutGate;

  @override
  Future<UserEntity> getCurrentUser() async => UserEntity(
    fullName: 'Alice Buyer',
    id: 'alice',
    email: 'alice@test.dev',
    phone: '0790000000',
    role: UserRole.buyer,
  );

  @override
  Future<bool> hasPendingWrites() async {
    checks++;
    await checkGate?.future;
    if (checkError != null) throw checkError!;
    return pending;
  }

  @override
  Future<void> logOut() async {
    logOuts++;
    await logOutGate?.future;
    if (logOutError != null) throw logOutError!;
  }

  @override
  Future<void> completePendingSignOut() async {}
}

class RecordingErrorCubit extends AppErrorCubit {
  final shown = <String>[];

  @override
  void showError(String message) {
    shown.add(message);
    super.showError(message);
  }
}

HomeBloc buildBloc(HomeRepository repo, AppErrorCubit errors) => HomeBloc(
  loggout: LogOut(repo),
  hasPendingWrites: HasPendingWrites(repo),
  getCurrentUser: GetCurrentUser(repo),
  appErrorCubit: errors,
);

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeHomeRepository repo;
  late RecordingErrorCubit errors;
  late HomeBloc bloc;

  setUp(() {
    repo = FakeHomeRepository();
    errors = RecordingErrorCubit();
    bloc = buildBloc(repo, errors);
  });

  tearDown(() async {
    await bloc.close();
    await errors.close();
  });

  AppException failure(String message, ErrorType type) =>
      AppException(message: message, type: type);

  group('LogoutPressed', () {
    test('no pending writes: logs out directly, with no warning', () async {
      bloc.add(LogoutPressed());
      await settle();

      expect(repo.checks, 1);
      expect(repo.logOuts, 1);
      expect(bloc.state.showUnsyncedWarning, isFalse);
      expect(bloc.state.isCheckingPendingWrites, isFalse);
      expect(bloc.state.isSigningOut, isFalse);
      expect(bloc.state.isSuccess, isTrue);
    });

    test('pending writes: shows the warning and does not log out', () async {
      repo.pending = true;
      bloc.add(LogoutPressed());
      await settle();

      expect(bloc.state.showUnsyncedWarning, isTrue);
      expect(bloc.state.isCheckingPendingWrites, isFalse);
      expect(bloc.state.isSigningOut, isFalse);
      expect(repo.logOuts, 0);
      expect(bloc.state.isSuccess, isFalse);
    });

    test('isCheckingPendingWrites is true only during the check', () async {
      repo.checkGate = Completer<void>();
      bloc.add(LogoutPressed());
      await settle();
      expect(bloc.state.isCheckingPendingWrites, isTrue);
      expect(repo.logOuts, 0);

      repo.checkGate!.complete();
      await settle();
      expect(bloc.state.isCheckingPendingWrites, isFalse);
    });

    test('an error in the check is shown and nothing is signed out', () async {
      repo.checkError = failure(SessionGate.signOutIncompleteMessage, ErrorType.auth);
      bloc.add(LogoutPressed());
      await settle();

      expect(errors.shown, [SessionGate.signOutIncompleteMessage]);
      expect(repo.logOuts, 0);
      expect(bloc.state.isCheckingPendingWrites, isFalse);
      expect(bloc.state.isSuccess, isFalse);
    });
  });

  group('repeated presses', () {
    test('during the check they are ignored', () async {
      repo.checkGate = Completer<void>();
      bloc.add(LogoutPressed());
      bloc.add(LogoutPressed());
      await settle();
      bloc.add(LogoutPressed());
      await settle();
      expect(repo.checks, 1);

      repo.checkGate!.complete();
      await settle();
      expect(repo.checks, 1);
      expect(repo.logOuts, 1);
    });

    test('during the sign-out they are ignored', () async {
      repo.logOutGate = Completer<void>();
      bloc.add(LogoutPressed());
      await settle();
      expect(bloc.state.isSigningOut, isTrue);

      bloc.add(LogoutPressed());
      await settle();
      expect(repo.checks, 1);
      expect(repo.logOuts, 1);

      repo.logOutGate!.complete();
      await settle();
    });

    test('while the warning is open they are ignored', () async {
      repo.pending = true;
      bloc.add(LogoutPressed());
      await settle();

      bloc.add(LogoutPressed());
      await settle();

      expect(repo.checks, 1);
      expect(repo.logOuts, 0);
      expect(bloc.state.showUnsyncedWarning, isTrue);
    });

    test('a double confirm logs out once', () async {
      repo.pending = true;
      bloc.add(LogoutPressed());
      await settle();

      repo.logOutGate = Completer<void>();
      bloc.add(LogoutConfirmed());
      bloc.add(LogoutConfirmed());
      await settle();
      expect(repo.logOuts, 1);

      repo.logOutGate!.complete();
      await settle();
    });

    test('after the check ends Logout can be pressed again', () async {
      repo.checkError = failure('No internet connection', ErrorType.network);
      bloc.add(LogoutPressed());
      await settle();

      repo.checkError = null;
      bloc.add(LogoutPressed());
      await settle();

      expect(repo.checks, 2);
      expect(repo.logOuts, 1);
    });
  });

  group('LogoutCancelled', () {
    test('clears the warning, with no sign-out', () async {
      repo.pending = true;
      bloc.add(LogoutPressed());
      await settle();

      bloc.add(LogoutCancelled());
      await settle();

      expect(bloc.state.showUnsyncedWarning, isFalse);
      expect(bloc.state.isSigningOut, isFalse);
      expect(bloc.state.isSuccess, isFalse);
      expect(repo.logOuts, 0);
    });

    test('Logout can be pressed again afterwards', () async {
      repo.pending = true;
      bloc.add(LogoutPressed());
      await settle();
      bloc.add(LogoutCancelled());
      await settle();

      bloc.add(LogoutPressed());
      await settle();

      expect(repo.checks, 2);
      expect(bloc.state.showUnsyncedWarning, isTrue);
    });
  });

  group('LogoutConfirmed', () {
    test('with the warning open: isSigningOut during the sign-out, then success', () async {
      repo.pending = true;
      bloc.add(LogoutPressed());
      await settle();

      repo.logOutGate = Completer<void>();
      bloc.add(LogoutConfirmed());
      await settle();
      expect(bloc.state.isSigningOut, isTrue);
      expect(bloc.state.showUnsyncedWarning, isFalse);
      expect(bloc.state.isSuccess, isFalse);
      expect(repo.logOuts, 1);

      repo.logOutGate!.complete();
      await settle();
      expect(bloc.state.isSigningOut, isFalse);
      expect(bloc.state.isSuccess, isTrue);
    });

    test('with no warning open it does nothing', () async {
      bloc.add(LogoutConfirmed());
      await settle();

      expect(repo.logOuts, 0);
      expect(bloc.state.isSigningOut, isFalse);
    });

    test('an AppException is shown and isSuccess stays false', () async {
      repo.pending = true;
      repo.logOutError = failure(SessionGate.wipePendingMessage, ErrorType.cache);
      bloc.add(LogoutPressed());
      await settle();
      bloc.add(LogoutConfirmed());
      await settle();

      expect(errors.shown, [SessionGate.wipePendingMessage]);
      expect(bloc.state.isSigningOut, isFalse);
      expect(bloc.state.isSuccess, isFalse);
    });
  });

  // profile_screen.dart clears ProfileBloc, MyCarsBloc, CarsBloc and FavoriteBloc when isSuccess
  // changes to true, so it must never be true without a complete sign-out.
  group('isSuccess', () {
    Future<List<bool>> successValuesDuring(Future<void> Function() action) async {
      final values = <bool>[];
      final sub = bloc.stream.listen((s) => values.add(s.isSuccess));
      await action();
      await settle();
      await sub.cancel();
      return values;
    }

    test('stays false through check, warning and Cancel', () async {
      repo.pending = true;
      final values = await successValuesDuring(() async {
        bloc.add(LogoutPressed());
        await settle();
        bloc.add(LogoutCancelled());
      });

      expect(values, isNotEmpty);
      expect(values, everyElement(isFalse));
    });

    test('stays false when the sign-out fails', () async {
      repo.logOutError = failure(SessionGate.signOutIncompleteMessage, ErrorType.auth);
      final values = await successValuesDuring(() async {
        bloc.add(LogoutPressed());
      });

      expect(values, isNotEmpty);
      expect(values, everyElement(isFalse));
    });

    test('becomes true only as the last step of a complete sign-out', () async {
      final values = await successValuesDuring(() async {
        bloc.add(LogoutPressed());
      });

      expect(values.last, isTrue);
      expect(values.where((v) => v).length, 1);
    });
  });

  group('after close()', () {
    late List<HomeState> states;
    late StreamSubscription<HomeState> sub;

    setUp(() => states = []);

    Future<void> startCountingStates() async {
      sub = bloc.stream.listen(states.add);
      await settle();
    }

    test('closed during the check: no sign-out and no emit', () async {
      repo.checkGate = Completer<void>();
      bloc.add(LogoutPressed());
      await settle();
      await startCountingStates();

      await bloc.close();
      final before = states.length;
      repo.checkGate!.complete();
      await settle();

      expect(repo.logOuts, 0);
      expect(states.length, before);
      await sub.cancel();
    });

    test('closed during the sign-out, the normal path: no emit and no error', () async {
      repo.logOutGate = Completer<void>();
      bloc.add(LogoutPressed());
      await settle();
      await startCountingStates();

      await bloc.close();
      final before = states.length;
      repo.logOutGate!.complete();
      await settle();

      expect(states.length, before);
      expect(errors.shown, isEmpty);
      await sub.cancel();
    });

    test('a failure after close() is still shown, with no emit', () async {
      repo.logOutGate = Completer<void>();
      repo.logOutError = failure(SessionGate.wipePendingMessage, ErrorType.cache);
      bloc.add(LogoutPressed());
      await settle();
      await startCountingStates();

      await bloc.close();
      final before = states.length;
      repo.logOutGate!.complete();
      await settle();

      expect(states.length, before);
      expect(errors.shown, [SessionGate.wipePendingMessage]);
      await sub.cancel();
    });
  });

  // HomeBloc with the real repository, datasource and gate, on fake Firebase: the approved
  // sign-out path of research D18 and how its two failures differ.
  group('with the real sign-out path', () {
    late CallLog log;
    late FakeFirestore firestore;
    late FakeAuth auth;
    late RecordingGate gate;
    late RecordingErrorCubit realErrors;
    late HomeBloc realBloc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CacheHelper.init();
      log = CallLog();
      firestore = FakeFirestore(log);
      auth = FakeAuth(log);
      gate = RecordingGate(log);
      final dataSource = HomeRemoteDataSource(auth, firestore, gate);
      gate.retryWipe = () => dataSource.retryPendingWipe();
      realErrors = RecordingErrorCubit();
      realBloc = buildBloc(HomeRepositoryImpl(dataSource), realErrors);
    });

    tearDown(() async {
      await realBloc.close();
      await realErrors.close();
    });

    test('no pending writes: the whole D18 order, then success', () async {
      realBloc.add(LogoutPressed());
      await settle();

      expect(log.calls, [
        'waitForPendingWrites',
        'closeForSignOut',
        'terminate',
        'clearPersistence',
        'signOut',
        'open',
      ]);
      expect(log.markerAtSignOut, isTrue);
      expect(markerSet(), isFalse);
      expect(gate.isOpen, isTrue);
      expect(realBloc.state.isSuccess, isTrue);
      expect(realErrors.shown, isEmpty);
    });

    test('the check ends within 3 s with a warning when there is no answer', () {
      fakeAsync((async) {
        final l = CallLog();
        final f = FakeFirestore(l)..pendingWrites = Completer<void>().future;
        final g = RecordingGate(l);
        final b = buildBloc(
          HomeRepositoryImpl(HomeRemoteDataSource(FakeAuth(l), f, g)),
          RecordingErrorCubit(),
        );

        b.add(LogoutPressed());
        async.flushMicrotasks();
        expect(b.state.isCheckingPendingWrites, isTrue);

        async.elapse(const Duration(milliseconds: 2999));
        expect(b.state.isCheckingPendingWrites, isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(b.state.isCheckingPendingWrites, isFalse);
        expect(b.state.showUnsyncedWarning, isTrue);
        expect(l.calls, ['waitForPendingWrites']);

        b.close();
        async.flushMicrotasks();
      });
    });

    group('with pending writes', () {
      setUp(() async {
        // The 3 s timeout itself is tested with fakeAsync above.
        firestore.pendingWrites = Future<void>.error(TimeoutException('pending writes'))
          ..ignore();
        realBloc.add(LogoutPressed());
        await settle();
        expect(realBloc.state.showUnsyncedWarning, isTrue);
        firestore.pendingWrites = Future.value();
        log.calls.clear();
      });

      test('Cancel: no wipe, no sign-out, no marker, gate stays open', () async {
        realBloc.add(LogoutCancelled());
        await settle();

        expect(log.calls, isEmpty);
        expect(markerSet(), isFalse);
        expect(gate.isOpen, isTrue);
        expect(realBloc.state.isSuccess, isFalse);
        expect(await gate.run(() async => 'still works'), 'still works');
      });

      test('Confirm: the D18 sign-out runs', () async {
        realBloc.add(LogoutConfirmed());
        await settle();

        expect(log.calls, [
          'closeForSignOut',
          'terminate',
          'clearPersistence',
          'signOut',
          'open',
        ]);
        expect(realBloc.state.isSuccess, isTrue);
      });
    });

    group('the two failures differ', () {
      test('clearPersistence fails: signed out, wipe message, a retry can open the gate', () async {
        firestore.failClear = true;
        realBloc.add(LogoutPressed());
        await settle();

        expect(realErrors.shown, [SessionGate.wipePendingMessage]);
        expect(log.calls, contains('signOut'));
        expect(realBloc.state.isSuccess, isFalse);
        expect(realBloc.state.isSigningOut, isFalse);
        expect(gate.state, SessionGateState.wipePending);
        expect(gate.isSignOutIncomplete, isFalse);
        expect(markerSet(), isTrue);

        firestore.failClear = false;
        expect(await gate.run(() async => 'data'), 'data');
        expect(gate.isOpen, isTrue);
        expect(markerSet(), isFalse);
      });

      test('signOut fails: still signed in, sign-out message, Firestore stays refused', () async {
        auth.failSignOut = true;
        realBloc.add(LogoutPressed());
        await settle();

        expect(realErrors.shown, [SessionGate.signOutIncompleteMessage]);
        expect(realBloc.state.isSuccess, isFalse);
        expect(realBloc.state.isSigningOut, isFalse);
        expect(gate.state, SessionGateState.wipePending);
        expect(gate.isSignOutIncomplete, isTrue);
        expect(markerSet(), isTrue);

        await expectLater(
          gate.run(() async => 'data'),
          throwsA(
            isA<AppException>()
                .having((e) => e.type, 'type', ErrorType.auth)
                .having((e) => e.message, 'message', SessionGate.signOutIncompleteMessage),
          ),
        );
        expect(gate.isOpen, isFalse);
      });

      test('after a failed signOut, Logout again does nothing but show the error', () async {
        auth.failSignOut = true;
        realBloc.add(LogoutPressed());
        await settle();
        log.calls.clear();
        auth.failSignOut = false;

        realBloc.add(LogoutPressed());
        await settle();

        expect(log.calls, isEmpty);
        expect(realErrors.shown, [
          SessionGate.signOutIncompleteMessage,
          SessionGate.signOutIncompleteMessage,
        ]);
        expect(realBloc.state.isCheckingPendingWrites, isFalse);
        expect(realBloc.state.isSigningOut, isFalse);
        expect(realBloc.state.isSuccess, isFalse);
        expect(gate.isSignOutIncomplete, isTrue);
      });
    });
  });
}
