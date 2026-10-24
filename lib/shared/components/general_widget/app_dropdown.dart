import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  final Widget? hint;
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    this.hint,
    this.validator,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      hint: hint,
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}

List<DropdownMenuItem<String>> buildItems(List<String> list) {
  return list
      .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
      .toList();
}

class CarData {
  static const brand = [
    'all',
    'toyota',
    'bmw',
    'mercedes',
    'audi',
    'kia',
    'hyundai',
    'nissan',
    'ford',
    'honda',
  ];
  static const location = [
    'all',
    'aleppo',
    'damascus',
    'homs',
    'hama',
    'edlep',
  ];
  static const bodyType = ['all', 'suv', 'sedan', 'pickup'];
  static const fuelType = ['all', 'petrol', 'diesel', 'hybrid', 'electric'];
}

class YearDropdown extends StatelessWidget {
  final int? selectedYear;
  final Function(int?) onChanged;

  const YearDropdown({
    super.key,
    required this.selectedYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    final years = List.generate(30, (index) => currentYear - index);

    return AppDropdown<int>(
      label: 'Year',
      value: selectedYear,
      items: years
          .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
          .toList(),
      onChanged: onChanged,
    );
  }
}

T? normalizeValue<T>(T? v) {
  if (v == null || v == 'all') return null;
  return v;
}
