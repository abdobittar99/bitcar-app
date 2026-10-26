import 'package:car_shop/shared/components/car_widget/horizontal_car_card.dart';
import 'package:car_shop/features/car/cars_list/ui/cars_screen.dart';
import 'package:car_shop/features/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_event.dart';

import 'package:car_shop/features/favorite/bloc/favorite_state.dart';
import 'package:car_shop/shared/components/general_widget/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ScrollController _controller = ScrollController();
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels >=
          _controller.position.maxScrollExtent - 200) {
        context.read<FavoriteBloc>().add(LoadMoreFavorite());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<FavoriteBloc, FavoriteState>(
        builder: (context, state) {
          if (state.isLoading && state.favoriteCars.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!state.isLoading && state.favoriteCars.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: "No favorites yet",
              subtitle: "Cars you like will appear here",
              buttonText: 'Browse Cars',
              onButtonPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarsScreen()),
                );
              },
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<FavoriteBloc>().add(FavoriteStarted());
            },
            child: ListView.builder(
              controller: _controller,
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              itemCount:
                  state.favoriteCars.length + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.favoriteCars.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final car = state.favoriteCars[index];
                return CarCardVertical(car: car, carId: car.id);
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
