import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/car_list/domain/usecases/delete_cars.dart';
import 'package:car_shop/modules/search/bloc/search_event.dart';
import 'package:car_shop/modules/search/bloc/search_state.dart';
import 'package:car_shop/models/search_filters.dart';
import 'package:car_shop/modules/search/domain/model/search_page.dart';
import 'package:car_shop/modules/search/domain/repository/search_repository.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository repo;
  final AppErrorCubit appErrorCubit;
  final DeleteCar adminDeleteCar;

  SearchBloc({
    required this.repo,
    required this.appErrorCubit,
    required this.adminDeleteCar,
  }) : super(const SearchState()) {
    on<SearchSubmitted>(_onSubmitted);
    on<LoadMoreResults>(_onLoadMore);
    on<ClearAll>(_onClearAll);
    on<ClearSearch>(_onClearSearch);
    on<ClearFilter>(_onClearFilter);
    on<AdminDeleteCarInSearch>(_onDelete);
  }

  Future<void> _onSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final listEq = const ListEquality<String>();

    if (listEq.equals(event.keywords, state.keywords) &&
        event.filters == state.filters) {
      return;
    }
    emit(
      state.copyWith(
        isLoading: true,
        keywords: event.keywords,
        filters: event.filters,
        lastDoc: null,
        isFirstSearch: false,
        results: [],
        hasMore: true,
      ),
    );

    try {
      final result = await repo.search(
        SearchParams(
          keywords: event.keywords,
          filters: event.filters,
          lastDoc: null,
        ),
      );

      emit(
        state.copyWith(
          results: result.cars,
          isLoading: false,
          lastDoc: result.lastDoc,
          hasMore: result.hasMore,
        ),
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onLoadMore(
    LoadMoreResults event,
    Emitter<SearchState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final result = await repo.search(
        SearchParams(
          keywords: state.keywords,
          filters: state.filters,
          lastDoc: state.lastDoc,
        ),
      );

      emit(
        state.copyWith(
          isLoadingMore: false,

          results: [...state.results, ...result.cars],
          lastDoc: result.lastDoc,
          hasMore: result.hasMore,
        ),
      );
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onDelete(
    AdminDeleteCarInSearch event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(deletedCarId: ''));

    final oldList = List<CarEntity>.from(state.results);

    final newList = oldList.where((c) => c.id != event.carId).toList();

    emit(state.copyWith(results: newList));

    try {
      assert(event.carId.isNotEmpty);

      await adminDeleteCar(event.carId);

      emit(state.copyWith(deletedCarId: event.carId));
    } on AppException catch (e) {
      emit(state.copyWith(results: oldList, deletedCarId: ''));

      appErrorCubit.showError(e.message);
    }
  }

  void _onClearAll(ClearAll event, Emitter<SearchState> emit) {
    emit(
      state.copyWith(
        results: [],
        isLoading: false,
        isLoadingMore: false,
        hasMore: true,
        keywords: [],
        filters: SearchFilters(),
        lastDoc: null,
        error: null,
        isFirstSearch: true,
      ),
    );
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    final hasFilters = !state.filters.isEmpty;

    if (hasFilters) {
      add(SearchSubmitted([], state.filters));
    } else {
      emit(
        state.copyWith(
          keywords: [],
          results: [],
          isFirstSearch: true,
          lastDoc: null,
          error: null,
        ),
      );
    }
  }

  void _onClearFilter(ClearFilter event, Emitter<SearchState> emit) {
    final hasKeywords = state.keywords.isNotEmpty;

    if (hasKeywords) {
      add(SearchSubmitted(state.keywords, SearchFilters()));
    } else {
      emit(
        state.copyWith(
          filters: SearchFilters(),
          results: [],
          lastDoc: null,
          error: null,
        ),
      );
    }
  }
}
