import 'package:car_shop/modules/feeds/bloc/feeds_bloc.dart';
import 'package:car_shop/modules/feeds/bloc/feeds_state.dart';
import 'package:car_shop/modules/home/bloc/home_bloc.dart';
import 'package:car_shop/modules/home/bloc/home_event.dart';
import 'package:car_shop/shared/components/car_widget/small_horizontal_car_card.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LatestCarsSection extends StatelessWidget {
  const LatestCarsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeedsBloc, FeedsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const SizedBox(
            height: 230,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.cars.isEmpty) {
          return const SizedBox();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionHeader(title: 'Latest Cars'),

                  TextButton(
                    onPressed: () {
                      context.read<HomeBloc>().add(HomeTabChanged(2));
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 235,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.cars.length,
                itemBuilder: (context, index) {
                  final car = state.cars[index];

                  return CarCardHorizontalSmall(car: car);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
