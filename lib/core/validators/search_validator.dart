import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/models/search_filters.dart';

void validateFilters(SearchFilters f) {
  if (f.activeFiltersCount > 7) {
    throw AppException(message: 'Too many filters', type: ErrorType.validation);
  }
}
