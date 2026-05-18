abstract class HomeEvent {}

class HomeStarted extends HomeEvent {}

class LogoutPressed extends HomeEvent {}

class HomeTabChanged extends HomeEvent {
  int currentIndex;
  HomeTabChanged(this.currentIndex);
}
