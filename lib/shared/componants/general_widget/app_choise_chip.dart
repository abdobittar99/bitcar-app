import 'package:flutter/material.dart';

class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: Theme.of(context).primaryColor.withAlpha(51),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class AppSelectableGroup<T> extends StatelessWidget {
  final List<T> items;
  final T? selected;
  final String Function(T) labelBuilder;

  final ValueChanged<T?> onChanged;

  const AppSelectableGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: items.map((item) {
        final isSelected = item == selected;

        return ChoiceChip(
          selectedColor: Theme.of(context).colorScheme.primary.withAlpha(40),
          label: Text(labelBuilder(item)),
          selected: isSelected,
          onSelected: (_) => onChanged(isSelected ? null : item),
        );
      }).toList(),
    );
  }
}
