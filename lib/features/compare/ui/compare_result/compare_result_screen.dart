import 'package:car_shop/features/compare/bloc/compare_bloc.dart';
import 'package:car_shop/features/compare/bloc/compare_state.dart';
import 'package:car_shop/features/compare/ui/compare_result/compare_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CompareResultPage extends StatelessWidget {
  const CompareResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Cars')),
      body: BlocBuilder<CompareBloc, CompareState>(
        builder: (context, state) {
          final car1 = state.firstCar;
          final car2 = state.secondCar;

          if (car1 == null || car2 == null) {
            return const Center(child: Text("Select two cars first"));
          }

          return CompareView(car1: car1, car2: car2);
        },
      ),
    );
  }
}
