import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/image_source/image_source.dart';
import 'package:car_shop/features/auth/data/datasource/auth_remote_datasource.dart';
import 'package:car_shop/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:car_shop/features/auth/domain/repositories/auth_repository.dart';
import 'package:car_shop/features/auth/domain/usecase/login.dart';
import 'package:car_shop/features/auth/domain/usecase/register.dart';
import 'package:car_shop/features/auth/login/bloc/login_bloc.dart';
import 'package:car_shop/features/auth/register/bloc/register_bloc.dart';
import 'package:car_shop/features/car/car_details/bloc/car_details_bloc.dart';
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
import 'package:car_shop/features/home/domain/usecase/get_current_user.dart';
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
  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  sl.registerLazySingleton<AppErrorCubit>(() => AppErrorCubit());

  // Home Layout
  sl.registerLazySingleton(() => HomeRemoteDataSource(sl(), sl()));

  sl.registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(sl()));

  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => LogOut(sl()));

  sl.registerFactory(
    () => HomeBloc(loggout: sl(), getCurrentUser: sl(), appErrorCubit: sl()),
  );
  // Feeds
  sl.registerLazySingleton(() => FeedsRemoteDataSource(sl()));
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

  sl.registerLazySingleton(() => AuthRemoteDatasource(sl(), sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton(() => Register(sl()));
  sl.registerLazySingleton(() => Login(sl()));

  sl.registerFactory(() => LoginBloc(login: sl(), appErrorCubit: sl()));

  sl.registerFactory(() => RegisterBloc(register: sl(), appErrorCubit: sl()));

  // Cars
  sl.registerLazySingleton(() => CarsRemoteDataSource(sl(), sl()));
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
    () => CarDetailsBloc(getCarDetails: sl(), appErrorCubit: sl()),
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
  sl.registerLazySingleton(() => FavoriteRemoteDataSource(sl(), sl()));

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
  sl.registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(sl()));

  sl.registerFactory(
    () => SearchBloc(appErrorCubit: sl(), repo: sl(), adminDeleteCar: sl()),
  );

  // profile
  sl.registerLazySingleton(() => UserRemoteDatasource(sl(), sl()));
  sl.registerLazySingleton<ProfileRepository>(() => UserRepositoryImpl(sl()));
  sl.registerLazySingleton(() => GetUserProfile(sl()));
  sl.registerLazySingleton(() => UpdateUserProfile(sl()));

  sl.registerFactory(
    () => ProfileBloc(
      appErrorCubit: sl(),
      getUserProfile: sl(),
      updateUserProfile: sl(),
    ),
  );
}
