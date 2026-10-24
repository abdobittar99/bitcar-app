import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/shared/components/general_widget/confirm_delete_dialog.dart';
import 'package:car_shop/modules/car/car_form/ui/car_form_screen.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_bloc.dart';
import 'package:car_shop/modules/car/car_list/bloc/cars_event.dart';
import 'package:car_shop/shared/components/car_widget/horizontal_car_card.dart';
import 'package:car_shop/modules/car/my_cars/bloc/my_cars_bloc.dart';
import 'package:car_shop/modules/car/my_cars/bloc/my_cars_event.dart';
import 'package:car_shop/modules/car/my_cars/bloc/my_cars_state.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_event.dart';
import 'package:car_shop/shared/components/general_widget/empty_stete_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MyCarsScreen extends StatelessWidget {
  const MyCarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cars'),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => sl<CarFormBloc>(),
                    child: AddCarScreen(),
                  ),
                ),
              );
              if (!context.mounted) return;
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add Car Successfully')),
                );
                context.read<MyCarsBloc>().add(MyCarsReloaded());
              }
            },
            icon: Icon(Icons.add, color: Colors.blueGrey),
          ),
        ],
      ),

      body: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => sl<CarFormBloc>(), child: AddCarScreen()),
        ],
        child: BlocConsumer<MyCarsBloc, MyCarsState>(
          listener: (context, state) {
            if (state.deletedCarId.isNotEmpty) {
              context.read<CarsBloc>().add(
                CarDeletedLocally(state.deletedCarId),
              );
              context.read<FavoriteBloc>().add(
                FavDeletedLocally(state.deletedCarId),
              );
            }
          },

          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!state.isLoading && state.myCars.isEmpty) {
              return EmptyState(
                icon: Icons.directions_car_outlined,
                title: 'no cars added yet',
                subtitle: 'Cars you add will appear here',
                buttonText: 'Add your first car',
                onButtonPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => sl<CarFormBloc>(),
                        child: AddCarScreen(),
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add Car Successfully')),
                    );
                    context.read<MyCarsBloc>().add(MyCarsReloaded());
                  }
                },
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<MyCarsBloc>().add(MyCarsReloaded());
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: state.myCars.length,
                itemBuilder: (context, index) {
                  return CarCardVertical(
                    car: state.myCars[index],
                    carId: state.myCars[index].id,
                    isOwner: true,
                    onEdit: () async {
                      final car = state.myCars[index];
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
                        context.read<MyCarsBloc>().add(MyCarsReloaded());
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
                        context.read<MyCarsBloc>().add(
                          DeleteMyCarPressed(state.myCars[index].id),
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
    );
  }
}
