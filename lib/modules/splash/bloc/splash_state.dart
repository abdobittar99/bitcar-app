import 'package:car_shop/core/enums/spalsh_destination.dart';

class SplashState {
  final SplashDestination destination;

  const SplashState({this.destination = SplashDestination.none});

  SplashState copyWith({SplashDestination? destination}) {
    return SplashState(destination: destination ?? this.destination);
  }
}
