import 'package:car_shop/entities/car.dart';
import 'package:car_shop/models/search_filters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchState {
  final List<CarEntity> results;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final List<String> keywords;
  final SearchFilters filters;
  final DocumentSnapshot? lastDoc;
  final String? error;
  final bool isFirstSearch;
  final String deletedCarId;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.keywords = const [],
    this.filters = const SearchFilters(),
    this.lastDoc,
    this.error,
    this.isFirstSearch = true,
    this.deletedCarId = '',
  });

  SearchState copyWith({
    List<CarEntity>? results,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    List<String>? keywords,
    SearchFilters? filters,
    DocumentSnapshot? lastDoc,
    String? error,
    bool? isFirstSearch,
    String? deletedCarId,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      keywords: keywords ?? this.keywords,
      filters: filters ?? this.filters,
      lastDoc: lastDoc ?? this.lastDoc,
      error: error,
      isFirstSearch: isFirstSearch ?? this.isFirstSearch,
      deletedCarId: deletedCarId ?? this.deletedCarId,
    );
  }
}

// List<Object?> get props => [results, isLoading, isFirstSearch, filters];
