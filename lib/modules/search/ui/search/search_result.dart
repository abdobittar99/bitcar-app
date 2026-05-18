import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/modules/car/car_form/ui/car_form_screen.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_bloc.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_event.dart';
import 'package:car_shop/modules/home/bloc/home_bloc.dart';
import 'package:car_shop/modules/home/bloc/home_event.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_event.dart';
import 'package:car_shop/shared/componants/car_widget/horizontal_car_card.dart';
import 'package:car_shop/modules/search/bloc/search_bloc.dart';
import 'package:car_shop/modules/search/bloc/search_event.dart';
import 'package:car_shop/modules/search/bloc/search_state.dart';
import 'package:car_shop/shared/componants/general_widget/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ResultsList extends StatefulWidget {
  const ResultsList({super.key});

  @override
  State<ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends State<ResultsList> {
  late final ScrollController controller;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();

    controller.addListener(() {
      final state = context.read<SearchBloc>().state;

      if (controller.position.maxScrollExtent > 0 &&
          controller.position.pixels >=
              controller.position.maxScrollExtent - 200 &&
          !state.isLoadingMore &&
          state.hasMore) {
        context.read<SearchBloc>().add(LoadMoreResults());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CarFormBloc>(), child: AddCarScreen()),
      ],
      child: BlocConsumer<SearchBloc, SearchState>(
        listener: (context, state) {
          if (state.deletedCarId.isNotEmpty) {
            context.read<FavoriteBloc>().add(
              FavDeletedLocally(state.deletedCarId),
            );

            Navigator.of(context).popUntil((route) => route.isFirst);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = context;

              ctx.read<HomeBloc>().add(HomeTabChanged(2));
              ctx.read<CarsBloc>().add(LoadInitialCars());

              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('delete car Successfully')),
              );
            });
          }
        },
        builder: (_, state) {
          final roleState = context.read<HomeBloc>().state;
          final isAdmin = roleState.role == UserRole.admin;
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.isFirstSearch) {
            return const Center(child: Text('Start Search'));
          }
          if (state.results.isEmpty) {
            return const Center(child: Text('No results'));
          }

          return ListView.builder(
            controller: controller,
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.all(16),
            itemCount: state.results.length + (state.hasMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= state.results.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final car = state.results[i];
              return CarCardVertical(
                car: car,
                carId: car.id,
                isAdmin: isAdmin,
                onEdit: () async {
                  final car = state.results[i];
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
                    Navigator.of(context).popUntil((route) => route.isFirst);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final ctx = context;

                      ctx.read<HomeBloc>().add(HomeTabChanged(2));
                      ctx.read<CarsBloc>().add(LoadInitialCars());

                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Updated successfully')),
                      );
                    });
                  }
                },

                onDelete: () async {
                  final confirm = await confirmDelete(context);
                  if (!context.mounted) return;
                  if (confirm == true) {
                    context.read<SearchBloc>().add(
                      AdminDeleteCarInSearch(state.results[i].id),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
