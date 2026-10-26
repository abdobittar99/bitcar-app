import 'package:car_shop/models/search_filters.dart';

abstract class SearchEvent {}

class SearchSubmitted extends SearchEvent {
  final List<String> keywords;
  final SearchFilters filters;

  SearchSubmitted(this.keywords, this.filters);
}

class AdminDeleteCarInSearch extends SearchEvent {
  final String carId;
  AdminDeleteCarInSearch(this.carId);
}

class LoadMoreResults extends SearchEvent {}

class ClearAll extends SearchEvent {}

class ClearSearch extends SearchEvent {}

class ClearFilter extends SearchEvent {}
