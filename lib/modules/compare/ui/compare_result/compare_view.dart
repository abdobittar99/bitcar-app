import 'package:car_shop/entities/car.dart';
import 'package:car_shop/shared/componants/compare_widget/comparison_weight.dart';
import 'package:car_shop/shared/componants/compare_widget/compare_header.dart';
import 'package:car_shop/shared/componants/compare_widget/compare_score.dart';
import 'package:car_shop/shared/componants/compare_widget/compare_secthion.dart';
import 'package:car_shop/shared/componants/compare_widget/compare_spec_row.dart';
import 'package:flutter/material.dart';

class CompareView extends StatelessWidget {
  final CarEntity car1;
  final CarEntity car2;

  const CompareView({super.key, required this.car1, required this.car2});

  @override
  Widget build(BuildContext context) {
    final comparator = CarComparator();

    final score1 = comparator.scoreCar(car1, car2);
    final score2 = comparator.scoreCar(car2, car1);

    final winner = score1 > score2 ? 1 : (score2 > score1 ? 2 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CompareHeader(car1: car1, car2: car2, winner: winner),

          const SizedBox(height: 20),

          CompareScore(
            score1: score1,
            score2: score2,
            winner: winner,
            car1: car1,
            car2: car2,
          ),

          const SizedBox(height: 20),

          CompareSection(
            title: "Performance",
            children: [
              CompareSpecRow(
                title: "Price",
                v1: "${car1.price}\$",
                v2: "${car2.price}\$",
                isBetter1: comparator.isBetter("Price", car1, car2),
                isBetter2: comparator.isBetter("Price", car2, car1),
              ),
              CompareSpecRow(
                title: "Year",
                v1: "${car1.year}",
                v2: "${car2.year}",
                isBetter1: comparator.isBetter("Year", car1, car2),
                isBetter2: comparator.isBetter("Year", car2, car1),
              ),
              CompareSpecRow(
                title: "Mileage",
                v1: "${car1.mileage}",
                v2: "${car2.mileage}",
                isBetter1: comparator.isBetter("Mileage", car1, car2),
                isBetter2: comparator.isBetter("Mileage", car2, car1),
              ),
              CompareSpecRow(
                title: "HP",
                v1: "${car1.horsePower}",
                v2: "${car2.horsePower}",
                isBetter1: comparator.isBetter("HP", car1, car2),
                isBetter2: comparator.isBetter("HP", car2, car1),
              ),
            ],
          ),

          const SizedBox(height: 20),

          CompareSection(
            title: "General",
            children: [
              CompareSpecRow.plain(
                title: "Condition",
                v1: car1.carCondition ?? "-",
                v2: car2.carCondition ?? "-",
              ),
              CompareSpecRow.plain(
                title: "Color",
                v1: car1.color,
                v2: car2.color,
              ),
              CompareSpecRow.plain(
                title: "Fuel",
                v1: car1.fuelType,
                v2: car2.fuelType,
              ),
              CompareSpecRow.plain(
                title: "Body",
                v1: car1.bodyType,
                v2: car2.bodyType,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
