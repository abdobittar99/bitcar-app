import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/home/bloc/home_event.dart';
import 'package:car_shop/features/home/bloc/home_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// The visible part of signing out (research D18 steps 6 and 7): the unsynced changes warning and
// a view that blocks the app. The view covers the child instead of replacing it, so the tabs keep
// their state if the sign-out fails, and profile_screen.dart stays mounted to clear the other blocs
// on isSuccess. It stays up after success, until the auth stream disposes HomeLayout.
class HomeLogoutGate extends StatelessWidget {
  final Widget child;

  const HomeLogoutGate({super.key, required this.child});

  Future<void> _showWarning(BuildContext context) {
    final bloc = context.read<HomeBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text(
            "Some changes haven't been saved to the server yet and will be "
            'lost. Log out anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                bloc.add(LogoutCancelled());
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                bloc.add(LogoutConfirmed());
              },
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listenWhen: (previous, current) =>
          !previous.showUnsyncedWarning && current.showUnsyncedWarning,
      listener: (context, state) => _showWarning(context),
      buildWhen: (previous, current) =>
          _isCovered(previous) != _isCovered(current),
      builder: (context, state) {
        final isCovered = _isCovered(state);
        return PopScope(
          canPop: !isCovered,
          child: Stack(
            fit: StackFit.expand,
            children: [child, if (isCovered) const _SigningOutView()],
          ),
        );
      },
    );
  }

  bool _isCovered(HomeState state) => state.isSigningOut || state.isSuccess;
}

class _SigningOutView extends StatelessWidget {
  const _SigningOutView();

  @override
  Widget build(BuildContext context) {
    return const BlockSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ModalBarrier(dismissible: false, color: Colors.white),
          Material(
            type: MaterialType.transparency,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Signing out…'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
