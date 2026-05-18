import 'package:car_shop/core/enums/spalsh_destination.dart';
import 'package:car_shop/modules/auth/register/ui/register_screen.dart';
import 'package:car_shop/modules/home/ui/home_layout.dart';
import 'package:car_shop/modules/intro/intro_screen.dart';
import 'package:car_shop/modules/auth/login/ui/login_screen.dart';
import 'package:car_shop/modules/splash/bloc/splash_bloc.dart';
import 'package:car_shop/modules/splash/bloc/splash_state.dart';
import 'package:car_shop/modules/splash/ui/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // print(" SplashView BUILT");
    return BlocBuilder<SplashBloc, SplashState>(
      builder: (context, state) {
        //  const SplashScreen();
        switch (state.destination) {
          case SplashDestination.intro:
            return const IntroScreen();

          case SplashDestination.login:
            return const LoginScreen();

          case SplashDestination.register:
            return const RegisterScreen();

          case SplashDestination.home:
            return const HomeLayout();

          case SplashDestination.none:
            return const SplashScreen();
        }
      },
    );
  }
}
