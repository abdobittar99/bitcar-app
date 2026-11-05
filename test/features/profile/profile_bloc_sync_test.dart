import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/features/chat/domain/usecase/sync_public_profile.dart';
import 'package:car_shop/features/profile/bloc/profile_bloc.dart';
import 'package:car_shop/features/profile/bloc/profile_event.dart';
import 'package:car_shop/features/profile/domain/repositories/profile_repository.dart';
import 'package:car_shop/features/profile/domain/usecase/get_user_profile.dart';
import 'package:car_shop/features/profile/domain/usecase/update_user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/fakes/fake_chat_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  AppException? updateError;

  @override
  Future<UserEntity> getCurrentUserProfile() async => UserEntity(
    fullName: 'Old Name',
    id: 'alice',
    email: 'alice@test.dev',
    phone: '0790000000',
    role: UserRole.buyer,
  );

  @override
  Future<UserEntity> updateUser(UserEntity user) async {
    if (updateError != null) throw updateError!;
    return user;
  }
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeProfileRepository profile;
  late FakeChatRepository chat;
  late AppErrorCubit errors;
  late ProfileBloc bloc;

  setUp(() async {
    profile = FakeProfileRepository();
    chat = FakeChatRepository();
    errors = AppErrorCubit();
    bloc = ProfileBloc(
      getUserProfile: GetUserProfile(profile),
      updateUserProfile: UpdateUserProfile(profile),
      syncPublicProfile: SyncPublicProfile(chat),
      appErrorCubit: errors,
    );
    bloc.add(ProfileRequested());
    await settle();
  });

  tearDown(() async {
    await bloc.close();
    await errors.close();
  });

  test('a changed name is synced once', () async {
    bloc.add(ProfileUpdated(fullName: 'New Name', phone: '0790000000'));
    await settle();

    expect(chat.calls['syncPublicProfile'], [
      ['New Name'],
    ]);
    expect(bloc.state.isSuccess, isTrue);
    expect(bloc.state.user?.fullName, 'New Name');
  });

  test('an unchanged name is not synced', () async {
    bloc.add(ProfileUpdated(fullName: 'Old Name', phone: '0799999999'));
    await settle();

    expect(chat.callCount('syncPublicProfile'), 0);
    expect(bloc.state.isSuccess, isTrue);
  });

  test('a failed sync is shown but the profile save still counts as successful', () async {
    chat.errors['syncPublicProfile'] = AppException(
      message: 'You do not have permission to perform this action',
      type: ErrorType.permission,
    );
    bloc.add(ProfileUpdated(fullName: 'New Name', phone: '0790000000'));
    await settle();

    expect(errors.state, 'You do not have permission to perform this action');
    expect(bloc.state.isSuccess, isTrue);
    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.user?.fullName, 'New Name');
  });

  test('a failed profile save is not synced and is not a success', () async {
    profile.updateError = AppException(
      message: 'Service temporarily unavailable',
      type: ErrorType.network,
    );
    bloc.add(ProfileUpdated(fullName: 'New Name', phone: '0790000000'));
    await settle();

    expect(chat.callCount('syncPublicProfile'), 0);
    expect(bloc.state.isSuccess, isFalse);
    expect(errors.state, 'Service temporarily unavailable');
  });
}
