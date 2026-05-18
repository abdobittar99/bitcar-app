import 'package:car_shop/entities/car.dart';

class FavoriteState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Set<String> favoriteCarIds;
  final List<CarEntity> favoriteCars;
  final bool hasMore;
  final int page;

  const FavoriteState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.favoriteCarIds = const {},
    this.favoriteCars = const [],
    this.hasMore = true,
    this.page = 0,
  });

  FavoriteState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    Set<String>? favoriteCarIds,
    List<CarEntity>? favoriteCars,
    bool? hasMore,
    int? page,
  }) {
    return FavoriteState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      favoriteCarIds: favoriteCarIds ?? this.favoriteCarIds,
      favoriteCars: favoriteCars ?? this.favoriteCars,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}
