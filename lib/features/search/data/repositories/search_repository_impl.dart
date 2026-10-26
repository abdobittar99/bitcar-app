import 'package:car_shop/models/car_model.dart';
import 'package:car_shop/features/search/domain/model/result_wrapper.dart';
import 'package:car_shop/features/search/domain/model/search_page.dart';
import 'package:car_shop/features/search/domain/repositories/search_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchRepositoryImpl implements SearchRepository {
  final FirebaseFirestore firestore;
  SearchRepositoryImpl(this.firestore);

  @override
  Future<SearchResult> search(SearchParams params) async {
    Query q = firestore.collection('cars');

    if (params.keywords.isNotEmpty) {
      q = q.where('searchKeywords', arrayContainsAny: params.keywords);
    }

    final f = params.filters;

    if (f.brand != null) {
      q = q.where('brand', isEqualTo: f.brand!.toLowerCase());
    }
    if (f.color != null) {
      q = q.where('color', isEqualTo: f.color);
    }

    if (f.location != null) {
      q = q.where('location', isEqualTo: f.location);
    }

    if (f.minPrice != null) {
      q = q.where('price', isGreaterThanOrEqualTo: f.minPrice);
    }

    if (f.maxPrice != null) {
      q = q.where('price', isLessThanOrEqualTo: f.maxPrice);
    }

    if (f.minYear != null) {
      final currentYear = DateTime.now().year;

      final years = List.generate(
        10,
        (i) => f.minYear! + i,
      ).where((y) => y <= currentYear).toList();

      q = q.where('year', whereIn: years);
    }

    if (f.condition != null) {
      q = q.where('condition', isEqualTo: f.condition);
    }
    if (f.bodyType != null) {
      q = q.where('bodyType', isEqualTo: f.bodyType);
    }
    if (f.fuelType != null) {
      q = q.where('fuelType', isEqualTo: f.fuelType);
    }

    final hasPriceRange = f.minPrice != null || f.maxPrice != null;
    final hasYearRange = f.minYear != null;
    if (hasPriceRange) {
      q = q.orderBy('price');
    } else if (hasYearRange) {
      q = q.orderBy('year');
    }

    q = q.orderBy('createdAt', descending: true).limit(10);

    if (params.lastDoc != null) {
      q = q.startAfterDocument(params.lastDoc!);
    }

    final snap = await q.get();

    final cars = snap.docs
        .map((d) => CarModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
    // print("reeesult $cars");

    return SearchResult(
      cars: cars,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == 10,
    );
  }
}
