import 'dart:async';

import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/home/bloc/home_event.dart';
import 'package:car_shop/features/home/bloc/home_state.dart';
import 'package:car_shop/features/home/domain/repositories/home_repository.dart';
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
import 'package:car_shop/features/home/domain/usecase/has_pending_writes.dart';
import 'package:car_shop/features/home/domain/usecase/logout.dart';
import 'package:car_shop/features/home/domain/usecase/prepare_sign_out.dart';
import 'package:car_shop/features/home/ui/home_logout_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const warningText =
    "Some changes haven't been saved to the server yet and will be lost. Log out anyway?";

class FakeHomeRepository implements HomeRepository {
  bool pending = false;
  int logOuts = 0;
  AppException? prepareError;
  AppException? logOutError;
  Completer<void>? prepareGate;
  Completer<void>? logOutGate;

  @override
  Future<void> prepareSignOut() async {
    await prepareGate?.future;
    if (prepareError != null) throw prepareError!;
  }

  @override
  Future<UserEntity> getCurrentUser() async => UserEntity(
    fullName: 'Alice Buyer',
    id: 'alice',
    email: 'alice@test.dev',
    phone: '0790000000',
    role: UserRole.buyer,
  );

  @override
  Future<bool> hasPendingWrites() async => pending;

  @override
  Future<void> logOut() async {
    logOuts++;
    await logOutGate?.future;
    if (logOutError != null) throw logOutError!;
  }

  @override
  Future<void> completePendingSignOut() async {}
}

void main() {
  late FakeHomeRepository repo;
  late AppErrorCubit errors;
  late HomeBloc bloc;
  late int clears;
  late int childTaps;

  setUp(() {
    repo = FakeHomeRepository();
    errors = AppErrorCubit();
    clears = 0;
    childTaps = 0;
    bloc = HomeBloc(
      loggout: LogOut(repo),
      hasPendingWrites: HasPendingWrites(repo),
      prepareSignOut: PrepareSignOut(repo),
      getCurrentUser: GetCurrentUser(repo),
      appErrorCubit: errors,
    );
  });

  tearDown(() async {
    await bloc.close();
    await errors.close();
  });

  // The child has the same listener as profile_screen.dart: it clears user data on isSuccess.
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: HomeLogoutGate(
            child: Scaffold(
              body: BlocListener<HomeBloc, HomeState>(
                listenWhen: (prev, curr) => prev.isSuccess != curr.isSuccess,
                listener: (context, state) {
                  if (state.isSuccess) clears++;
                },
                child: Center(
                  child: TextButton(
                    onPressed: () => childTaps++,
                    child: const Text('Home content'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The bloc runs in real time, outside the fake time of testWidgets.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pressLogout(WidgetTester tester) async {
    bloc.add(LogoutPressed());
    await settle(tester);
  }

  testWidgets('no pending writes: no warning', (tester) async {
    await show(tester);
    await pressLogout(tester);

    expect(find.text(warningText), findsNothing);
    expect(repo.logOuts, 1);
  });

  testWidgets('pending writes: the warning shows, with Cancel and Log out', (tester) async {
    repo.pending = true;
    await show(tester);
    await pressLogout(tester);

    expect(find.text(warningText), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(repo.logOuts, 0);
  });

  testWidgets('the warning cannot be dismissed by tapping outside', (tester) async {
    repo.pending = true;
    await show(tester);
    await pressLogout(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(warningText), findsOneWidget);
  });

  testWidgets('Cancel: back in the app, no sign-out, nothing cleared', (tester) async {
    repo.pending = true;
    await show(tester);
    await pressLogout(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text(warningText), findsNothing);
    expect(find.text('Home content'), findsOneWidget);
    expect(find.text('Signing out…'), findsNothing);
    expect(repo.logOuts, 0);
    expect(clears, 0);
    expect(bloc.state.showUnsyncedWarning, isFalse);
  });

  testWidgets('Log out: the blocking view shows during the sign-out, then user data is cleared', (tester) async {
    repo.pending = true;
    repo.logOutGate = Completer<void>();
    await show(tester);
    await pressLogout(tester);

    await tester.tap(find.text('Log out'));
    await settle(tester);

    expect(find.text(warningText), findsNothing);
    expect(find.text('Signing out…'), findsOneWidget);
    expect(repo.logOuts, 1);
    expect(clears, 0);

    repo.logOutGate!.complete();
    await settle(tester);

    expect(clears, 1);
    expect(find.text('Signing out…'), findsOneWidget, reason: 'stays up until HomeLayout is disposed');
  });

  testWidgets('no blocking view while the marker is being saved', (tester) async {
    repo.prepareGate = Completer<void>();
    await show(tester);
    await pressLogout(tester);

    expect(find.text('Signing out…'), findsNothing);
    expect(repo.logOuts, 0);

    repo.logOutGate = Completer<void>();
    repo.prepareGate!.complete();
    await settle(tester);

    expect(find.text('Signing out…'), findsOneWidget);
    repo.logOutGate!.complete();
    await settle(tester);
  });

  testWidgets('a failed marker save: no blocking view, the error shows, nothing cleared', (tester) async {
    const message = 'Could not start signing out. Please try again.';
    repo.prepareError = AppException(message: message, type: ErrorType.cache);
    await show(tester);
    await pressLogout(tester);

    expect(find.text('Signing out…'), findsNothing);
    expect(find.text('Home content'), findsOneWidget);
    expect(errors.state, message);
    expect(repo.logOuts, 0);
    expect(clears, 0);
  });

  testWidgets('the blocking view blocks the app underneath', (tester) async {
    repo.logOutGate = Completer<void>();
    await show(tester);
    await pressLogout(tester);
    expect(find.text('Signing out…'), findsOneWidget);

    await tester.tap(find.text('Home content'), warnIfMissed: false);
    await settle(tester);

    expect(childTaps, 0);
    expect(repo.logOuts, 1);
    repo.logOutGate!.complete();
    await settle(tester);
  });

  for (final (name, message, type) in [
    ('clearPersistence', SessionGate.wipePendingMessage, ErrorType.cache),
    ('signOut', SessionGate.signOutIncompleteMessage, ErrorType.auth),
  ]) {
    testWidgets('$name failure: back in the app with the error, nothing cleared', (tester) async {
      repo.logOutError = AppException(message: message, type: type);
      await show(tester);
      await pressLogout(tester);

      expect(find.text('Signing out…'), findsNothing);
      expect(find.text('Home content'), findsOneWidget);
      expect(errors.state, message);
      expect(clears, 0);
      expect(bloc.state.isSuccess, isFalse);
    });
  }

  testWidgets('the child stays mounted during the sign-out, so its state survives a failure', (tester) async {
    repo.logOutGate = Completer<void>();
    repo.logOutError = AppException(
      message: SessionGate.signOutIncompleteMessage,
      type: ErrorType.auth,
    );
    await show(tester);
    final before = tester.element(find.text('Home content'));
    await pressLogout(tester);

    repo.logOutGate!.complete();
    await settle(tester);

    expect(tester.element(find.text('Home content')), same(before));
  });
}
