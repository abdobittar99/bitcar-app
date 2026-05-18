import 'package:firebase_auth/firebase_auth.dart';

abstract class SplashEvent {}

class SplashStarted extends SplashEvent {}

class AuthStatusChanged extends SplashEvent {
  final User? user;
  AuthStatusChanged(this.user);
}

class GoToRegisterPressed extends SplashEvent {}

class GoToLoginPressed extends SplashEvent {}
