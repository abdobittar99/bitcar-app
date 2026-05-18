import 'package:car_shop/entities/car.dart';
import 'package:flutter/material.dart';

class CompareScore extends StatelessWidget {
  final double score1;
  final double score2;
  final int winner;
  final CarEntity car1;
  final CarEntity car2;

  const CompareScore({
    super.key,
    required this.score1,
    required this.score2,
    required this.winner,
    required this.car1,
    required this.car2,
  });

  @override
  Widget build(BuildContext context) {
    String resultText;

    if (winner == 0) {
      resultText = "Equal";
    } else if (winner == 1) {
      resultText = "${car1.brand} is better";
    } else {
      resultText = "${car2.brand} is better";
    }

    return Column(
      children: [
        const Text(
          "Final Score",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(resultText, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
