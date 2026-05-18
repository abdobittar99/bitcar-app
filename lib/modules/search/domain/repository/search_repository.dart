import 'package:car_shop/modules/search/domain/model/result_wrapper.dart';
import 'package:car_shop/modules/search/domain/model/search_page.dart';

abstract class SearchRepository {
  Future<SearchResult> search(SearchParams params);
}
