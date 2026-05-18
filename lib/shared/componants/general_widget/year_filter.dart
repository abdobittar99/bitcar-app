import 'dart:math';
import 'package:flutter/material.dart';

class YearRangeSlider extends StatelessWidget {
  final int? startYear;
  final ValueChanged<int?> onChanged;

  const YearRangeSlider({
    super.key,
    required this.startYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start = startYear ?? 2000;
    final end = min(start + 9, DateTime.now().year);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("$start - $end"),
            if (startYear != null)
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text("Clear"),
              ),
          ],
        ),
        Slider(
          min: 1990,
          max: (DateTime.now().year - 9).toDouble(),
          value: start.toDouble(),
          divisions: (DateTime.now().year - 1990 - 9),
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }
}
