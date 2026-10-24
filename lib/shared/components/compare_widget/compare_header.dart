import 'package:car_shop/entities/car.dart';
import 'package:flutter/material.dart';

class CompareHeader extends StatelessWidget {
  final CarEntity car1;
  final CarEntity car2;
  final int winner;

  const CompareHeader({
    super.key,
    required this.car1,
    required this.car2,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildCar(CarEntity car, bool isWinner) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              car.images.first,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            car.brand,
            style: TextStyle(
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              color: isWinner ? Colors.green : null,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: buildCar(car1, winner == 1)),
        const SizedBox(width: 12),
        Expanded(child: buildCar(car2, winner == 2)),
      ],
    );
  }
}
