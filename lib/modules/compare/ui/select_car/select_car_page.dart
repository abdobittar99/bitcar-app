import 'package:car_shop/core/utils/search_utils.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_bloc.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_event.dart';
import 'package:car_shop/modules/compare/bloc/bloc.dart';
import 'package:car_shop/modules/compare/bloc/event.dart';
import 'package:car_shop/modules/search/bloc/search_bloc.dart';
import 'package:car_shop/modules/search/bloc/search_event.dart';
import 'package:car_shop/modules/search/bloc/search_state.dart';
import 'package:car_shop/modules/search/ui/filter/filter_button.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/app_formfield.dart';
import 'package:car_shop/shared/components/car_widget/selectable_vertical_car_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectCarPage extends StatefulWidget {
  final bool isFirst;
  const SelectCarPage({super.key, required this.isFirst});

  @override
  State<SelectCarPage> createState() => _SelectCarPageState();
}

class _SelectCarPageState extends State<SelectCarPage> {
  late final ScrollController searchController;
  late final ScrollController controller;

  final TextEditingController textController = TextEditingController();
  CarEntity? selectedCar;
  @override
  void initState() {
    super.initState();

    textController.addListener(() {
      setState(() {});
    });
    final carsState = context.read<CarsBloc>().state;
    if (carsState.cars.isEmpty) {
      context.read<CarsBloc>().add(LoadInitialCars());
    }
    controller = ScrollController();
    searchController = ScrollController();
    controller.addListener(() {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent - 200) {
        context.read<CarsBloc>().add(CarsLoadMore());
      }
    });

    searchController.addListener(() {
      final state = context.read<SearchBloc>().state;

      if (searchController.position.maxScrollExtent > 0 &&
          searchController.position.pixels >=
              searchController.position.maxScrollExtent - 200 &&
          !state.isLoadingMore &&
          state.hasMore) {
        context.read<SearchBloc>().add(LoadMoreResults());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirst ? "Select First Car" : "Select Second Car"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: AppFormField(
                    isSearcch: true,
                    label: "Search car...",
                    controller: textController,
                    prefixIcon: Icons.search,
                    suffixIcon: textController.text.isEmpty
                        ? null
                        : Icons.close_outlined,
                    onSuffixPressed: () {
                      textController.clear();
                      context.read<SearchBloc>().add(ClearSearch());
                    },
                    onSubmitted: (value) {
                      final keywords = normalizeSearchQuery(value);

                      _resetSelection();
                      context.read<SearchBloc>().add(
                        SearchSubmitted(
                          keywords,
                          context.read<SearchBloc>().state.filters,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterButton(
                  onFiltersChanged: () {
                    _resetSelection();
                  },
                ),
                const SizedBox(width: 8),

                BlocBuilder<SearchBloc, SearchState>(
                  builder: (context, state) {
                    final hasFilters = !state.filters.isEmpty;
                    // || state.keywords.isNotEmpty;

                    if (!hasFilters) return const SizedBox();

                    return IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _resetSelection();
                        context.read<SearchBloc>().add(ClearFilter());
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent()),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                text: "Select",
                onPressed: selectedCar == null
                    ? null
                    : () {
                        final compareBloc = context.read<CompareBloc>();

                        if (widget.isFirst) {
                          compareBloc.add(SelectFirstCar(selectedCar!));
                        } else {
                          compareBloc.add(SelectSecondCar(selectedCar!));
                        }

                        Navigator.pop(context);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final searchState = context.watch<SearchBloc>().state;

    final isSearching =
        searchState.keywords.isNotEmpty || !searchState.filters.isEmpty;

    if (isSearching) {
      if (searchState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (searchState.results.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text("No cars found"),
            ],
          ),
        );
      }

      return _buildList(searchState.results, controller: searchController);
    }

    final carsState = context.watch<CarsBloc>().state;

    if (carsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildList(carsState.cars, controller: controller);
  }

  Widget _buildList(
    List<CarEntity> cars, {
    required ScrollController controller,
  }) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cars.length,
      itemBuilder: (context, index) {
        final car = cars[index];

        return SelectableCarCardHorizontal(
          car: car,
          isSelected: selectedCar?.id == car.id,
          onTap: () {
            setState(() {
              selectedCar = car;
            });
          },
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    searchController.dispose();
    textController.dispose();
    super.dispose();
  }

  void _resetSelection() {
    setState(() {
      selectedCar = null;
    });
  }
}
