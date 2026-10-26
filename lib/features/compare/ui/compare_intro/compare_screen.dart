import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_bloc.dart';
import 'package:car_shop/features/compare/bloc/compare_bloc.dart';
import 'package:car_shop/features/compare/bloc/compare_event.dart';
import 'package:car_shop/features/compare/bloc/compare_state.dart';
import 'package:car_shop/features/compare/ui/compare_result/compare_result_screen.dart';
import 'package:car_shop/features/compare/ui/select_car/select_car_screen.dart';
import 'package:car_shop/features/search/bloc/search_bloc.dart';
import 'package:car_shop/shared/components/compare_widget/car_slot_card.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ComparePage extends StatelessWidget {
  const ComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const SectionHeader(title: 'Compare Cars')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<CompareBloc, CompareState>(
          builder: (context, state) {
            return Column(
              children: [
                CarSlotCard(
                  car: state.firstCar,
                  label: "First Car",
                  onSelect: () => _openSelector(context, true),
                  onClear: () =>
                      context.read<CompareBloc>().add(ClearFirstCar()),
                ),

                const SizedBox(height: 16),

                CarSlotCard(
                  car: state.secondCar,
                  label: "Second Car",
                  onSelect: () => _openSelector(context, false),
                  onClear: () =>
                      context.read<CompareBloc>().add(ClearSecondCar()),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: "Compare",
                    onPressed: state.isReady
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MultiBlocProvider(
                                  providers: [
                                    BlocProvider.value(
                                      value: context.read<CompareBloc>(),
                                    ),
                                  ],
                                  child: CompareResultPage(),
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openSelector(BuildContext context, bool isFirst) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<CompareBloc>()),
            BlocProvider.value(value: context.read<CarsBloc>()),
            BlocProvider(create: (_) => sl<SearchBloc>()),
          ],
          child: SelectCarPage(isFirst: isFirst),
        ),
      ),
    );
  }
}
