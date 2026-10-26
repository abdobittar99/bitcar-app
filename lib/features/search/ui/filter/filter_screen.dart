import 'package:car_shop/models/search_filters.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/app_choice_chip.dart';
import 'package:car_shop/shared/components/general_widget/app_dropdown.dart';
import 'package:car_shop/shared/components/general_widget/app_formfield.dart';
import 'package:car_shop/shared/components/general_widget/color_selector.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:car_shop/shared/components/general_widget/year_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FilterScreen extends StatefulWidget {
  final SearchFilters initialFilters;

  const FilterScreen({super.key, required this.initialFilters});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late SearchFilters filters;
  late TextEditingController minPriceController;
  late TextEditingController maxPriceController;

  @override
  void initState() {
    super.initState();
    filters = widget.initialFilters;
    minPriceController = TextEditingController(
      text: filters.minPrice != null ? '${filters.minPrice}' : '',
    );
    maxPriceController = TextEditingController(
      text: filters.maxPrice != null ? '${filters.maxPrice}' : '',
    );
  }

  void updateFilters(SearchFilters newFilters) {
    setState(() => filters = newFilters);
  }

  void resetFilters() {
    setState(() => filters = SearchFilters());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Filters"),
        actions: [
          TextButton(onPressed: resetFilters, child: const Text("Reset")),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(title: "Basic"),
          const SizedBox(height: 12),

          AppDropdown(
            label: 'Brand',
            hint: const Text('All Brands'),
            value: filters.brand,
            items: buildItems(CarData.brand),
            onChanged: (v) =>
                updateFilters(filters.copyWith(brand: () => normalizeValue(v))),
          ),
          const SizedBox(height: 12),

          AppDropdown(
            label: 'Location',
            hint: const Text('All Locations'),
            value: filters.location,
            items: buildItems(CarData.location),
            onChanged: (v) => updateFilters(
              filters.copyWith(location: () => normalizeValue(v)),
            ),
          ),
          const SizedBox(height: 12),

          AppDropdown(
            label: 'Body',
            hint: const Text('All Body types'),
            value: filters.bodyType,
            items: buildItems(CarData.bodyType),
            onChanged: (v) => updateFilters(
              filters.copyWith(bodyType: () => normalizeValue(v)),
            ),
          ),
          const SizedBox(height: 12),

          AppDropdown(
            label: 'Fuel',
            hint: const Text('All Fuel types'),
            value: filters.fuelType,
            items: buildItems(CarData.fuelType),
            onChanged: (v) => updateFilters(
              filters.copyWith(fuelType: () => normalizeValue(v)),
            ),
          ),

          const SizedBox(height: 24),

          SectionHeader(title: "Price"),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppFormField(
                  label: 'Min',
                  controller: minPriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => updateFilters(
                    filters.copyWith(
                      minPrice: v.isEmpty ? null : int.tryParse(v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(
                  controller: maxPriceController,
                  label: 'Max',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => updateFilters(
                    filters.copyWith(
                      maxPrice: v.isEmpty ? null : int.tryParse(v),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          SectionHeader(title: "Year"),
          const SizedBox(height: 12),

          YearRangeSlider(
            startYear: filters.minYear,
            onChanged: (v) => updateFilters(filters.copyWith(minYear: () => v)),
          ),

          const SizedBox(height: 24),

          SectionHeader(title: "Condition"),
          const SizedBox(height: 12),

          AppSelectableGroup<String>(
            items: const ['zero', 'used'],
            selected: filters.condition,
            labelBuilder: (v) => v,
            onChanged: (v) =>
                updateFilters(filters.copyWith(condition: () => v)),
          ),

          const SizedBox(height: 24),

          SectionHeader(title: "Color"),
          const SizedBox(height: 12),

          ColorSelector(
            selected: filters.color,
            onChanged: (v) => updateFilters(filters.copyWith(color: () => v)),
          ),

          const SizedBox(height: 30),

          AppButton(
            text: "Apply Filters",
            onPressed: () {
              if (filters.minPrice != null &&
                  filters.maxPrice != null &&
                  filters.minPrice! > filters.maxPrice!) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Min price must be less than Max price"),
                  ),
                );
                return;
              }

              Navigator.pop(context, filters);
            },
          ),
        ],
      ),
    );
  }

  void dispode() {
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }
}
