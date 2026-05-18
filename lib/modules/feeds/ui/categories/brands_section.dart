import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/models/search_filters.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_bloc.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/modules/home/bloc/home_bloc.dart';
import 'package:car_shop/modules/feeds/model/brana_data.dart';
import 'package:car_shop/modules/feeds/model/brand_item.dart';
import 'package:car_shop/modules/feeds/ui/categories/filtered_cars_screen.dart';
import 'package:car_shop/modules/search/bloc/search_bloc.dart';
import 'package:car_shop/modules/search/bloc/search_event.dart';
import 'package:car_shop/shared/componants/general_widget/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BrandSection extends StatelessWidget {
  const BrandSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(title: 'Popular Brands'),
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final brand = brands[index];

              return _BrandCard(brand: brand);
            },
          ),
        ),
      ],
    );
  }
}

class _BrandCard extends StatelessWidget {
  final BrandItem brand;

  const _BrandCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<HomeBloc>()),
                BlocProvider.value(value: context.read<CarsBloc>()),
                BlocProvider.value(value: context.read<FavoriteBloc>()),
                BlocProvider(
                  create: (_) => sl<SearchBloc>()
                    ..add(
                      SearchSubmitted([], SearchFilters(brand: brand.name)),
                    ),
                ),
              ],
              child: FilteredCarsScreen(
                title: brand.name.toUpperCase(),
                filters: SearchFilters(brand: brand.name),
              ),
            ),
          ),
        );
      },
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withAlpha(30)),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 3),
              color: Colors.black.withAlpha(12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 38,
              child: Image.asset(brand.image, fit: BoxFit.contain),
            ),

            const SizedBox(height: 10),

            Text(
              brand.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
