import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/image_source/image_source.dart';
import 'package:car_shop/modules/auth/data/datasource/auth_remote_datasource.dart';
import 'package:car_shop/modules/auth/data/repositories/auth_repository_impl.dart';
import 'package:car_shop/modules/auth/domain/repositories/auth_repository.dart';
import 'package:car_shop/modules/auth/domain/usecase/login.dart';
import 'package:car_shop/modules/auth/domain/usecase/register.dart';
import 'package:car_shop/modules/auth/login/bloc/login_bloc.dart';
import 'package:car_shop/modules/auth/register/bloc/register_bloc.dart';
import 'package:car_shop/modules/car/car_details/bloc/car_details_bloc.dart';
import 'package:car_shop/modules/car/domain/usecases/get_car_details.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/modules/car/domain/usecases/add_car.dart';
import 'package:car_shop/modules/car/domain/usecases/get_initial_cars.dart';
import 'package:car_shop/modules/car/domain/usecases/update_car.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_bloc.dart';
import 'package:car_shop/modules/car/data/datasource/cars_datasource.dart';
import 'package:car_shop/modules/car/data/repositories/cars_repositoryimpl.dart';
import 'package:car_shop/modules/car/domain/repositories/cars_repository.dart';
import 'package:car_shop/modules/car/domain/usecases/load_more_cars.dart';
import 'package:car_shop/modules/car/domain/usecases/update_car_details.dart';
import 'package:car_shop/modules/car/my_cars/bloc/my_cars_bloc.dart';
import 'package:car_shop/modules/car/domain/usecases/delete_cars.dart';
import 'package:car_shop/modules/car/domain/usecases/get_my_cars.dart';
import 'package:car_shop/modules/feeds/bloc/feeds_bloc.dart';
import 'package:car_shop/modules/feeds/data/datasource/feeds_remote_datasource.dart';
import 'package:car_shop/modules/feeds/data/repositoryimpl/feeds_repositoryimpl.dart';
import 'package:car_shop/modules/feeds/domian/repository/feeds_repository.dart';
import 'package:car_shop/modules/home/bloc/home_bloc.dart';
import 'package:car_shop/modules/home/data/datasources/home_remote_datasource.dart';
import 'package:car_shop/modules/home/data/repositories/home_repository_impl.dart';
import 'package:car_shop/modules/home/domain/repositories/home_repository.dart';
import 'package:car_shop/modules/feeds/domian/usecase/add_ad.dart';
import 'package:car_shop/modules/feeds/domian/usecase/delete_ad.dart';
import 'package:car_shop/modules/feeds/domian/usecase/get_ads.dart';
import 'package:car_shop/modules/home/domain/usecases/get_current_user.dart';
import 'package:car_shop/modules/home/domain/usecases/logout.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/modules/favorite/data/datasources/favorite_remote_datasource.dart';
import 'package:car_shop/modules/favorite/data/repositories/favorite_repository_impl.dart';
import 'package:car_shop/modules/favorite/domain/repositories/favorite_repository.dart';
import 'package:car_shop/modules/favorite/domain/usecases/favorite_page.dart';
import 'package:car_shop/modules/favorite/domain/usecases/get_favorite_ids.dart';
import 'package:car_shop/modules/favorite/domain/usecases/toggle_favorite.dart';
import 'package:car_shop/modules/favorite/domain/usecases/refresh_favorite.dart';
import 'package:car_shop/modules/profile/bloc/profile_bloc.dart';
import 'package:car_shop/modules/profile/data/datasource/user_remote_datasource.dart';
import 'package:car_shop/modules/profile/data/repositoryImpl/user_repository_impl.dart';
import 'package:car_shop/modules/profile/domain/repository/profile_repository.dart';
import 'package:car_shop/modules/profile/domain/usecases/get_user_profile.dart';
import 'package:car_shop/modules/profile/domain/usecases/update_user_profile.dart';
import 'package:car_shop/modules/search/bloc/search_bloc.dart';
import 'package:car_shop/modules/search/data/repository/search_repository_impl.dart';
import 'package:car_shop/modules/search/domain/repository/search_repository.dart';
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
