import 'package:car_shop/features/feeds/bloc/feeds_bloc.dart';
import 'package:car_shop/features/feeds/bloc/feeds_event.dart';
import 'package:car_shop/features/feeds/ui/add_banner/banner_section.dart';
import 'package:car_shop/features/feeds/ui/categories/brands_section.dart';
import 'package:car_shop/features/feeds/ui/categories/condition_section.dart';
import 'package:car_shop/features/feeds/ui/latest_cars/latest_cars_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final feedsBloc = context.read<FeedsBloc>();

        feedsBloc
          ..add(LoadAds())
          ..add(LoadLatestCars());

        await Future.delayed(const Duration(milliseconds: 700));
      },
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            const HomeBannerSection(),
            SizedBox(height: 15),

            const BrandSection(),
            const SizedBox(height: 15),
            const ConditionsSection(),
            const SizedBox(height: 20),
            const LatestCarsSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
