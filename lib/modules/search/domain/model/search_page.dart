import 'package:car_shop/models/search_filters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchParams {
  final List<String> keywords;
  final SearchFilters filters;
  final DocumentSnapshot? lastDoc;

  const SearchParams({
    required this.keywords,
    required this.filters,
    required this.lastDoc,
  });
}
