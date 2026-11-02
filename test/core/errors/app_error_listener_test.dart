import 'package:car_shop/core/errors/app_error_listener.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppErrorCubit cubit;

  setUp(() => cubit = AppErrorCubit());
  tearDown(() => cubit.close());

  Future<void> pumpListener(WidgetTester tester) {
    return tester.pumpWidget(
      BlocProvider<AppErrorCubit>.value(
        value: cubit,
        child: MaterialApp(
          builder: (context, child) => AppErrorListener(child: child!),
          home: const Scaffold(),
        ),
      ),
    );
  }

  testWidgets('showError shows a SnackBar with the message', (tester) async {
    await pumpListener(tester);

    cubit.showError('Network error');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Network error'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the cubit is reset to null after the error is shown', (
    tester,
  ) async {
    await pumpListener(tester);

    cubit.showError('Network error');
    await tester.pump();

    expect(cubit.state, isNull);
  });

  testWidgets('clear shows no SnackBar', (tester) async {
    await pumpListener(tester);

    cubit.clear();
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
