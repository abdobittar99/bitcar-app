import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/image_source/image_source.dart';
import 'package:car_shop/core/session/session_gate.dart';
import 'package:car_shop/features/auth/data/datasource/auth_remote_datasource.dart';
import 'package:car_shop/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:car_shop/features/auth/domain/repositories/auth_repository.dart';
import 'package:car_shop/features/auth/domain/usecase/login.dart';
import 'package:car_shop/features/auth/domain/usecase/register.dart';
import 'package:car_shop/features/auth/login/bloc/login_bloc.dart';
import 'package:car_shop/features/auth/register/bloc/register_bloc.dart';
import 'package:car_shop/features/car/car_details/bloc/car_details_bloc.dart';
import 'package:car_shop/features/chat/data/datasource/chat_remote_datasource.dart';
import 'package:car_shop/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:car_shop/features/chat/domain/repositories/chat_repository.dart';
import 'package:car_shop/features/chat/chat_room/bloc/chat_bloc.dart';
import 'package:car_shop/features/chat/conversations/bloc/conversations_bloc.dart';
import 'package:car_shop/features/chat/domain/usecase/create_message_id.dart';
import 'package:car_shop/features/chat/domain/usecase/delete_conversation.dart';
import 'package:car_shop/features/chat/domain/usecase/delete_message.dart';
import 'package:car_shop/features/chat/domain/usecase/fill_own_placeholder_name.dart';
import 'package:car_shop/features/chat/domain/usecase/get_chat_target.dart';
import 'package:car_shop/features/chat/domain/usecase/get_current_user_id.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_conversations.dart';
import 'package:car_shop/features/chat/domain/usecase/load_older_messages.dart';
import 'package:car_shop/features/chat/domain/usecase/mark_conversation_read.dart';
import 'package:car_shop/features/chat/domain/usecase/open_chat_with_seller.dart';
import 'package:car_shop/features/chat/domain/usecase/send_message.dart';
import 'package:car_shop/features/chat/domain/usecase/sync_public_profile.dart';
import 'package:car_shop/features/chat/domain/usecase/watch_latest_messages.dart';
import 'package:car_shop/features/car/domain/usecase/get_car_details.dart';
import 'package:car_shop/features/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/features/car/domain/usecase/add_car.dart';
import 'package:car_shop/features/car/domain/usecase/get_initial_cars.dart';
import 'package:car_shop/features/car/domain/usecase/update_car.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_bloc.dart';
import 'package:car_shop/features/car/data/datasource/cars_remote_datasource.dart';
import 'package:car_shop/features/car/data/repositories/cars_repository_impl.dart';
import 'package:car_shop/features/car/domain/repositories/cars_repository.dart';
import 'package:car_shop/features/car/domain/usecase/load_more_cars.dart';
import 'package:car_shop/features/car/domain/usecase/update_car_details.dart';
import 'package:car_shop/features/car/my_cars/bloc/my_cars_bloc.dart';
import 'package:car_shop/features/car/domain/usecase/delete_cars.dart';
import 'package:car_shop/features/car/domain/usecase/get_my_cars.dart';
import 'package:car_shop/features/feeds/bloc/feeds_bloc.dart';
import 'package:car_shop/features/feeds/data/datasource/feeds_remote_datasource.dart';
import 'package:car_shop/features/feeds/data/repositories/feeds_repository_impl.dart';
import 'package:car_shop/features/feeds/domain/repositories/feeds_repository.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/home/data/datasource/home_remote_datasource.dart';
import 'package:car_shop/features/home/data/repositories/home_repository_impl.dart';
import 'package:car_shop/features/home/domain/repositories/home_repository.dart';
import 'package:car_shop/features/feeds/domain/usecase/add_ad.dart';
import 'package:car_shop/features/feeds/domain/usecase/delete_ad.dart';
import 'package:car_shop/features/feeds/domain/usecase/get_ads.dart';
import 'package:car_shop/features/home/domain/usecase/complete_pending_sign_out.dart';
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
import 'package:car_shop/features/home/domain/usecase/has_pending_writes.dart';
import 'package:car_shop/features/home/domain/usecase/logout.dart';
import 'package:car_shop/features/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/features/favorite/data/datasource/favorite_remote_datasource.dart';
import 'package:car_shop/features/favorite/data/repositories/favorite_repository_impl.dart';
import 'package:car_shop/features/favorite/domain/repositories/favorite_repository.dart';
import 'package:car_shop/features/favorite/domain/usecase/favorite_page.dart';
import 'package:car_shop/features/favorite/domain/usecase/get_favorite_ids.dart';
import 'package:car_shop/features/favorite/domain/usecase/toggle_favorite.dart';
import 'package:car_shop/features/favorite/domain/usecase/refresh_favorite.dart';
import 'package:car_shop/features/profile/bloc/profile_bloc.dart';
import 'package:car_shop/features/profile/data/datasource/user_remote_datasource.dart';
import 'package:car_shop/features/profile/data/repositories/user_repository_impl.dart';
import 'package:car_shop/features/profile/domain/repositories/profile_repository.dart';
import 'package:car_shop/features/profile/domain/usecase/get_user_profile.dart';
import 'package:car_shop/features/profile/domain/usecase/update_user_profile.dart';
import 'package:car_shop/features/search/bloc/search_bloc.dart';
import 'package:car_shop/features/search/data/repositories/search_repository_impl.dart';
import 'package:car_shop/features/search/domain/repositories/search_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Session gate: every Firestore call goes through it (sign-out cleanup, research D18)
  sl.registerLazySingleton(() => SessionGate());

  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  sl.registerLazySingleton<AppErrorCubit>(() => AppErrorCubit());

  // Home Layout
  sl.registerLazySingleton(() => HomeRemoteDataSource(sl(), sl(), sl()));

  sl.registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(sl()));

  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => LogOut(sl()));
  sl.registerLazySingleton(() => HasPendingWrites(sl()));
  sl.registerLazySingleton(() => CompletePendingSignOut(sl()));
  // The gate's retry only wipes and never signs out (research D18 step 4).
  sl<SessionGate>().retryWipe = () => sl<HomeRemoteDataSource>().retryPendingWipe();

  sl.registerFactory(
    () => HomeBloc(
      loggout: sl(),
      hasPendingWrites: sl(),
      getCurrentUser: sl(),
      appErrorCubit: sl(),
    ),
  );
  // Feeds
  sl.registerLazySingleton(() => FeedsRemoteDataSource(sl(), sl()));
  sl.registerLazySingleton<FeedsRepository>(() => FeedsRepositoryImpl(sl()));
  sl.registerLazySingleton(() => AddAd(sl()));
  sl.registerLazySingleton(() => GetAds(sl()));
  sl.registerLazySingleton(() => DeleteAd(sl()));
  sl.registerFactory(
    () => FeedsBloc(
      getInitialCars: sl(),
      appErrorCubit: sl(),
      addAd: sl(),
      getAds: sl(),
      deleteAd: sl(),
    ),
  );

  // Auth

  sl.registerLazySingleton(() => AuthRemoteDatasource(sl(), sl(), sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton(() => Register(sl()));
  sl.registerLazySingleton(() => Login(sl()));

  sl.registerFactory(() => LoginBloc(login: sl(), appErrorCubit: sl()));

  sl.registerFactory(() => RegisterBloc(register: sl(), appErrorCubit: sl()));

  // Cars
  sl.registerLazySingleton(() => CarsRemoteDataSource(sl(), sl(), sl()));
  sl.registerLazySingleton<CarsRepository>(() => CarsRepositoryImpl(sl()));
  sl.registerLazySingleton(() => AddCar(sl()));
  sl.registerLazySingleton(() => UpdateCarDetails(sl()));
  sl.registerLazySingleton(() => DeleteCar(sl()));
  sl.registerLazySingleton(() => GetCarDetails(sl()));
  sl.registerLazySingleton(() => LoadMoreCars(sl()));
  sl.registerLazySingleton(() => UpdateCar(sl()));
  sl.registerLazySingleton(() => GetInitialCars(sl()));
  sl.registerLazySingleton(() => GetMyCars(sl()));
  sl.registerLazySingleton<ImageSource>(() => AssetImageSource());

  sl.registerFactory(
    () => CarFormBloc(
      addCar: sl(),
      updateCarDetails: sl(),
      imageSource: sl(),
      getCurrentUser: sl(),
      appErrorCubit: sl(),
    ),
  );

  sl.registerFactory(
    () => CarDetailsBloc(
      getCarDetails: sl(),
      getCurrentUser: sl(),
      appErrorCubit: sl(),
    ),
  );

  sl.registerFactory(
    () => CarsBloc(
      adminDeleteCar: sl(),
      loadMoreCars: sl(),
      getInitialCars: sl(),
      updateCar: sl(),
      appErrorCubit: sl(),
    ),
  );

  sl.registerFactory(
    () => MyCarsBloc(
      getMyCars: sl(),
      deleteMyCar: sl(),
      getCurrentUser: sl(),
      appErrorCubit: sl(),
    ),
  );

  // Favorite
  sl.registerLazySingleton(() => FavoriteRemoteDataSource(sl(), sl(), sl()));

  sl.registerLazySingleton<FavoriteRepository>(
    () => FavoriteRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton(() => GetFavoritesPage(sl()));
  sl.registerLazySingleton(() => ToggleFavorite(sl()));
  sl.registerLazySingleton(() => GetFavoriteIds(sl()));
  sl.registerLazySingleton(() => RefreshFavorites(sl()));

  sl.registerFactory(
    () => FavoriteBloc(
      getFavIds: sl(),
      getPage: sl(),
      toggle: sl(),
      refresh: sl(),
      appErrorCubit: sl(),
    ),
  );

  // Search
  sl.registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(sl(), sl()));

  sl.registerFactory(
    () => SearchBloc(appErrorCubit: sl(), repo: sl(), adminDeleteCar: sl()),
  );

  // profile
  sl.registerLazySingleton(() => UserRemoteDatasource(sl(), sl(), sl()));
  sl.registerLazySingleton<ProfileRepository>(() => UserRepositoryImpl(sl()));
  sl.registerLazySingleton(() => GetUserProfile(sl()));
  sl.registerLazySingleton(() => UpdateUserProfile(sl()));

  sl.registerFactory(
    () => ProfileBloc(
      appErrorCubit: sl(),
      getUserProfile: sl(),
      updateUserProfile: sl(),
      syncPublicProfile: sl(),
    ),
  );

  // Chat
  sl.registerLazySingleton(() => ChatRemoteDataSource(sl(), sl(), sl()));
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(sl()));
  sl.registerLazySingleton(() => GetCurrentUserId(sl()));
  sl.registerLazySingleton(() => SyncPublicProfile(sl()));
  sl.registerLazySingleton(() => OpenChatWithSeller(sl()));
  sl.registerLazySingleton(() => CreateMessageId(sl()));
  sl.registerLazySingleton(() => SendMessage(sl()));
  sl.registerLazySingleton(() => WatchLatestMessages(sl()));
  sl.registerLazySingleton(() => LoadOlderMessages(sl()));
  sl.registerLazySingleton(() => MarkConversationRead(sl()));
  sl.registerLazySingleton(() => WatchConversations(sl()));
  sl.registerLazySingleton(() => GetChatTarget(sl()));
  sl.registerLazySingleton(() => FillOwnPlaceholderName(sl()));
  sl.registerLazySingleton(() => DeleteMessage(sl()));
  sl.registerLazySingleton(() => DeleteConversation(sl()));

  sl.registerFactory(
    () => ConversationsBloc(
      getCurrentUser: sl(),
      getCurrentUserId: sl(),
      syncPublicProfile: sl(),
      watchConversations: sl(),
      deleteConversation: sl(),
      appErrorCubit: sl(),
    ),
  );

  sl.registerFactory(
    () => ChatBloc(
      openChatWithSeller: sl(),
      getChatTarget: sl(),
      fillOwnPlaceholderName: sl(),
      watchLatestMessages: sl(),
      loadOlderMessages: sl(),
      createMessageId: sl(),
      sendMessage: sl(),
      markConversationRead: sl(),
      deleteMessage: sl(),
      getCurrentUserId: sl(),
      appErrorCubit: sl(),
    ),
  );
}
