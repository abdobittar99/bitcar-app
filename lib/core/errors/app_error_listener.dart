import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppErrorListener extends StatelessWidget {
  final Widget child;
  const AppErrorListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppErrorCubit, String?>(
      listener: (context, error) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error, style: TextStyle(color: Colors.redAccent)),
            ),
          );

          context.read<AppErrorCubit>().clear();
        }
      },
      child: child,
    );
  }
}
