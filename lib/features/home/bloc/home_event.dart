abstract class HomeEvent {}

class HomeStarted extends HomeEvent {}

class LogoutPressed extends HomeEvent {}

// The user chose to log out from the unsynced changes warning (FR-052).
class LogoutConfirmed extends HomeEvent {}

// The user stayed signed in from the unsynced changes warning (FR-052).
class LogoutCancelled extends HomeEvent {}

class HomeTabChanged extends HomeEvent {
  int currentIndex;
  HomeTabChanged(this.currentIndex);
}
