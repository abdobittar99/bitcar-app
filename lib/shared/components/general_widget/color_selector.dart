import 'package:flutter/material.dart';

class ColorSelector extends StatelessWidget {
  final String? selected;
  final Function(String?) onChanged;

  const ColorSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const colors = {
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'blue': Colors.blue,
    'grey': Colors.grey,
    'green': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: colors.entries.map((c) {
        final isSelected = selected == c.key;

        return GestureDetector(
          onTap: () {
            onChanged(isSelected ? null : c.key);
          },
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.value,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
