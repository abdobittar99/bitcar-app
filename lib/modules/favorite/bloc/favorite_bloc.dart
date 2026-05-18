import 'dart:async';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_event.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_state.dart';
import 'package:car_shop/modules/favorite/domain/usecases/favorite_page.dart';
import 'package:car_shop/modules/favorite/domain/usecases/get_favorite_ids.dart';
import 'package:car_shop/modules/favorite/domain/usecases/refresh_favorite.dart';
import 'package:car_shop/modules/favorite/domain/usecases/toggle_favorite.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavoriteBloc extends Bloc<FavoriteEvent, FavoriteState> {
  final GetFavoritesPage getPage;
  final ToggleFavorite toggle;
  final GetFavoriteIds getFavIds;
  final RefreshFavorites refresh;
  final AppErrorCubit appErrorCubit;

  static const limit = 10;

  FavoriteBloc({
    required this.toggle,
    required this.getPage,
    required this.getFavIds,
    required this.refresh,
    required this.appErrorCubit,
  }) : super(const FavoriteState()) {
    on<FavoriteStarted>(_onStarted);
    on<FavoriteToggled>(_onToggled);
    on<ClearFavorite>(_onClear);
    on<LoadMoreFavorite>(_onloadMore);
    on<FavCarUpdateLocally>((event, emit) {
      final updatedList = state.favoriteCars.map((car) {
        return car.id == event.updatedCar.id ? event.updatedCar : car;
      }).toList();
      emit(state.copyWith(favoriteCars: updatedList));
    });
    on<FavDeletedLocally>((event, emit) {
      final ids = {...state.favoriteCarIds}..remove(event.carId);

      final cars = state.favoriteCars
          .where((c) => c.id != event.carId)
          .toList();

      emit(state.copyWith(favoriteCarIds: ids, favoriteCars: cars));
    });
  }

  Future<void> _onStarted(
    FavoriteStarted event,
    Emitter<FavoriteState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isLoading: true,
          favoriteCars: [],
          page: 0,
          hasMore: true,
        ),
      );
      await refresh();
      final ids = await getFavIds();
      final res = await getPage(0, limit);

      emit(
        state.copyWith(
          favoriteCars: res.cars,
          page: 0,
          hasMore: res.hasMore,
          favoriteCarIds: ids,
          isLoading: false,
        ),
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onloadMore(LoadMoreFavorite event, Emitter<FavoriteState> emit) async {
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final nextPage = state.page + 1;

      final res = await getPage(nextPage, limit);

      emit(
        state.copyWith(
          favoriteCars: [...state.favoriteCars, ...res.cars],
          page: nextPage,
          hasMore: res.hasMore,
          isLoadingMore: false,
        ),
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onToggled(
    FavoriteToggled event,
    Emitter<FavoriteState> emit,
  ) async {
    assert(event.carId.isNotEmpty);

    final oldIds = Set<String>.from(state.favoriteCarIds);
    final oldCars = List<CarEntity>.from(state.favoriteCars);

    final isFav = oldIds.contains(event.carId);

    final newIds = Set<String>.from(oldIds);
    final newCars = List<CarEntity>.from(oldCars);

    if (isFav) {
      newIds.remove(event.carId);
      newCars.removeWhere((c) => c.id == event.carId);
    } else {
      newIds.add(event.carId);

      final car = event.car;
      if (car != null) {
        newCars.add(car);
      }
    }

    emit(state.copyWith(favoriteCarIds: newIds, favoriteCars: newCars));

    try {
      await toggle(event.carId);
    } on AppException catch (e) {
      emit(state.copyWith(favoriteCarIds: oldIds, favoriteCars: oldCars));
      appErrorCubit.showError(e.message);
    }
  }

  void _onClear(FavoriteEvent event, Emitter<FavoriteState> emit) {
    emit(
      state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        favoriteCars: [],
        favoriteCarIds: {},
        page: 0,
        hasMore: true,
      ),
    );
  }
}
