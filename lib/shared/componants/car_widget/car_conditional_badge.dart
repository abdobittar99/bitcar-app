import 'package:flutter/material.dart';

class CarConditionBadge extends StatelessWidget {
  final String? condition;

  const CarConditionBadge({super.key, required this.condition});

  @override
  Widget build(BuildContext context) {
    final isZero = condition == 'zero';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isZero ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isZero ? 'NEW' : 'USED',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
