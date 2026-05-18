import 'dart:async';
import 'dart:ui';
import 'package:car_shop/app_root.dart';
import 'package:car_shop/core/cach/cache_helper.dart';
import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/errors/app_error_listener.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/modules/splash/bloc/splash_bloc.dart';
import 'package:car_shop/modules/splash/bloc/splash_event.dart';
import 'package:car_shop/modules/splash/data/splash_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp();
      await CacheHelper.init();
      await init();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        PlatformDispatcher.instance.onError;
        sl<AppErrorCubit>().showError(details.exceptionAsString());
      };
      runApp(const MyApp());
    },
    (error, stack) {
      sl<AppErrorCubit>().showError(error.toString());
    },
  );
}

final splashService = SplashService();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AppErrorCubit>()),
        BlocProvider(
          create: (_) => SplashBloc(splashService)..add(SplashStarted()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Car App',
        debugShowCheckedModeBanner: false,
        home: const AppRoot(),
        builder: (context, child) {
          return AppErrorListener(child: child!);
        },
      ),
    );
  }
}
