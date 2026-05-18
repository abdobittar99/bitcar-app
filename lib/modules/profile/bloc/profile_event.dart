abstract class ProfileEvent {}

class ProfileRequested extends ProfileEvent {
  final bool forceRefresh;
  ProfileRequested({this.forceRefresh = false});
}

class ProfileUpdated extends ProfileEvent {
  final String fullName;
  final String phone;
  ProfileUpdated({required this.fullName, required this.phone});
}

class ProfileCleared extends ProfileEvent {}
