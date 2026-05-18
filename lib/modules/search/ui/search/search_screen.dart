import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/modules/search/bloc/search_bloc.dart';
import 'package:car_shop/modules/search/bloc/search_event.dart';
import 'package:car_shop/modules/search/bloc/search_state.dart';
import 'package:car_shop/modules/search/ui/filter/filter_button.dart';
import 'package:car_shop/modules/search/ui/search/search_field.dart';
import 'package:car_shop/modules/search/ui/search/search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SearchBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: const SearchField(),
          actions: [
            const FilterButton(),

            BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                if (state.filters.isEmpty) return const SizedBox();

                return IconButton(
                  icon: const Icon(Icons.filter_alt_off),
                  onPressed: () {
                    context.read<SearchBloc>().add(ClearFilter());
                  },
                );
              },
            ),
          ],
        ),
        body: const ResultsList(),
      ),
    );
  }
}
