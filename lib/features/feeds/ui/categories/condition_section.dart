import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/models/search_filters.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/feeds/ui/categories/filtered_cars_screen.dart';
import 'package:car_shop/features/search/bloc/search_bloc.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConditionsSection extends StatelessWidget {
  const ConditionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(title: 'Conditions'),
        ),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _ConditionButton(title: 'Zero', condition: 'zero'),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _ConditionButton(title: 'Used', condition: 'used'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConditionButton extends StatelessWidget {
  final String title;
  final String condition;

  const _ConditionButton({required this.title, required this.condition});

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
                BlocProvider(create: (_) => sl<SearchBloc>()),
              ],
              child: FilteredCarsScreen(
                title: title,
                filters: SearchFilters(condition: condition),
              ),
            ),
          ),
        );
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: const Color(0xFF0D47A1).withAlpha(40)),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 3),
              color: Colors.black.withAlpha(10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
