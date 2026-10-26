import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/features/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/features/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/features/car/car_form/ui/car_form_screen.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_bloc.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_event.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_state.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_event.dart';
import 'package:car_shop/shared/components/car_widget/horizontal_car_card.dart';
import 'package:car_shop/shared/components/general_widget/confirm_delete_dialog.dart';
import 'package:car_shop/shared/components/general_widget/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CarsScreen extends StatefulWidget {
  const CarsScreen({super.key});

  @override
  State<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends State<CarsScreen> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      if (_controller.position.pixels >=
          _controller.position.maxScrollExtent - 200) {
        context.read<CarsBloc>().add(CarsLoadMore());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CarFormBloc>(), child: AddCarScreen()),
      ],
      child: BlocConsumer<CarsBloc, CarsState>(
        listener: (context, state) {
          if (state.deletedCarId.isNotEmpty) {
            context.read<FavoriteBloc>().add(
              FavDeletedLocally(state.deletedCarId),
            );
          }
        },
        builder: (context, state) {
          final roleState = context.read<HomeBloc>().state.role;
          final isAdmin = roleState == UserRole.admin;

          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.cars.isEmpty) {
            return const EmptyState(
              icon: Icons.car_crash,
              title: "No Cars Found",
              subtitle: "Cars will appear here",
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<CarsBloc>().add(LoadInitialCars());
            },
            child: ListView.builder(
              controller: _controller,
              physics: AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: state.cars.length + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.cars.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final car = state.cars[index];

                return CarCardVertical(
                  car: car,
                  carId: car.id,
                  isAdmin: isAdmin,
                  onEdit: () async {
                    final car = state.cars[index];
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('update Car Successfully'),
                        ),
                      );
                      context.read<CarsBloc>().add(LoadInitialCars());
                    }
                  },

                  onDelete: () async {
                    final confirm = await confirmDelete(context);
                    if (!context.mounted) return;
                    if (confirm == true) {
                      if (state.deletedCarId.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('delete car Successfully'),
                          ),
                        );
                      }
                      context.read<CarsBloc>().add(
                        AdminDeleteCarPressed(state.cars[index].id),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
