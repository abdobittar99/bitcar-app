import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/utils/search_utils.dart';
import 'package:car_shop/models/search_filters.dart';
import 'package:car_shop/features/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/features/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/features/car/car_form/ui/car_form_screen.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_event.dart';
import 'package:car_shop/features/search/bloc/search_bloc.dart';
import 'package:car_shop/features/search/bloc/search_event.dart';
import 'package:car_shop/features/search/bloc/search_state.dart';
import 'package:car_shop/shared/components/car_widget/horizontal_car_card.dart';
import 'package:car_shop/shared/components/general_widget/app_formfield.dart';
import 'package:car_shop/shared/components/general_widget/confirm_delete_dialog.dart';
import 'package:car_shop/shared/components/general_widget/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FilteredCarsScreen extends StatefulWidget {
  final String title;
  final SearchFilters filters;

  const FilteredCarsScreen({
    super.key,
    required this.title,
    required this.filters,
  });

  @override
  State<FilteredCarsScreen> createState() => _FilteredCarsScreenState();
}

class _FilteredCarsScreenState extends State<FilteredCarsScreen> {
  final controller = ScrollController();

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SearchBloc>().add(SearchSubmitted([], widget.filters));
    controller.addListener(() {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent - 200) {
        context.read<SearchBloc>().add(LoadMoreResults());
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    final keywords = normalizeSearchQuery(value);

    context.read<SearchBloc>().add(SearchSubmitted(keywords, widget.filters));
  }

  @override
  Widget build(BuildContext context) {
    final roleState = context.read<HomeBloc>().state;
    final isAdmin = roleState.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title.toUpperCase())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),

            child: AppFormField(
              controller: searchController,
              prefixIcon: Icons.search,
              onChanged: (_) {
                setState(() {});
              },
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : Icons.close_outlined,
              onSuffixPressed: () {
                searchController.clear();

                setState(() {});

                context.read<SearchBloc>().add(ClearSearch());
              },
              onSubmitted: _search,
              label: 'Search inside',
            ),
          ),

          Expanded(
            child: BlocConsumer<SearchBloc, SearchState>(
              listener: (context, state) {
                if (state.deletedCarId.isNotEmpty) {
                  context.read<FavoriteBloc>().add(
                    FavDeletedLocally(state.deletedCarId),
                  );
                }
              },
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.results.isEmpty) {
                  return const EmptyState(
                    icon: Icons.car_crash,
                    title: "No Cars Found",
                    subtitle: "Cars will appear here",
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<SearchBloc>().add(
                      SearchSubmitted([], widget.filters),
                    );
                  },
                  child: ListView.builder(
                    controller: controller,
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        state.results.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.results.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final car = state.results[index];

                      return CarCardVertical(
                        car: car,
                        carId: car.id,
                        isAdmin: isAdmin,

                        onEdit: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider(
                                create: (_) =>
                                    sl<CarFormBloc>()..add(EditCarStarted(car)),
                                child: AddCarScreen(),
                              ),
                            ),
                          );

                          if (!context.mounted) return;

                          if (result == true) {
                            context.read<SearchBloc>().add(
                              SearchSubmitted(state.keywords, state.filters),
                            );
                          }
                        },

                        onDelete: () async {
                          final confirm = await confirmDelete(context);

                          if (!context.mounted) return;

                          if (confirm == true) {
                            context.read<SearchBloc>().add(
                              AdminDeleteCarInSearch(car.id),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
