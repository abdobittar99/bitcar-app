import 'package:car_shop/features/search/bloc/search_bloc.dart';
import 'package:car_shop/features/search/bloc/search_event.dart';
import 'package:car_shop/features/search/bloc/search_state.dart';
import 'package:car_shop/models/search_filters.dart';
import 'package:car_shop/features/search/ui/filter/filter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FilterButton extends StatelessWidget {
  final VoidCallback? onFiltersChanged;
  const FilterButton({super.key, this.onFiltersChanged});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        return IconButton(
          icon: const Icon(Icons.tune),
          onPressed: () async {
            final result = await Navigator.push<SearchFilters>(
              context,
              MaterialPageRoute(
                builder: (_) => FilterScreen(initialFilters: state.filters),
              ),
            );
            if (!context.mounted) return;
            if (result != null) {
              context.read<SearchBloc>().add(
                SearchSubmitted(state.keywords, result),
              );
              onFiltersChanged?.call();
            }
          },
        );
      },
    );
  }
}
