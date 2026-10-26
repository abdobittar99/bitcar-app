import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/features/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/features/car/car_form/ui/car_form_screen.dart';
import 'package:car_shop/features/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_bloc.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_event.dart';
import 'package:car_shop/features/car/my_cars/bloc/my_cars_bloc.dart';
import 'package:car_shop/features/car/my_cars/bloc/my_cars_event.dart';
import 'package:car_shop/features/compare/bloc/compare_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_event.dart';
import 'package:car_shop/features/feeds/bloc/feeds_bloc.dart';
import 'package:car_shop/features/feeds/bloc/feeds_event.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/home/bloc/home_event.dart';
import 'package:car_shop/features/home/bloc/home_state.dart';
import 'package:car_shop/features/home/ui/home_navigation.dart';
import 'package:car_shop/features/profile/bloc/profile_bloc.dart';
import 'package:car_shop/features/profile/bloc/profile_event.dart';
import 'package:car_shop/features/search/ui/search/search_screen.dart';
import 'package:car_shop/features/splash/ui/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeLayout extends StatelessWidget {
  const HomeLayout({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<HomeBloc>()..add(HomeStarted())),
        BlocProvider(
          create: (_) => sl<FeedsBloc>()
            ..add(LoadAds())
            ..add(LoadLatestCars()),
        ),
        BlocProvider(
          create: (_) => sl<CarFormBloc>()..add(UpdateCarSubmitted()),
        ),
        BlocProvider(create: (_) => CompareBloc()),
        BlocProvider(create: (_) => sl<CarsBloc>()..add(LoadInitialCars())),
        BlocProvider(create: (_) => sl<FavoriteBloc>()..add(FavoriteStarted())),

        BlocProvider(create: (_) => sl<ProfileBloc>()..add(ProfileRequested())),
        BlocProvider(create: (_) => sl<MyCarsBloc>()..add(MyCarsStarted())),
      ],
      child: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {},
        builder: (context, state) {
          final isSeller = state.role == UserRole.seller;
          if (state.isLoading) {
            return SplashScreen();
          }
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 10),

                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Bit',
                          style: TextStyle(
                            color: Color.fromARGB(255, 11, 63, 139),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),

                        TextSpan(
                          text: 'Car',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiBlocProvider(
                          providers: [
                            BlocProvider.value(value: context.read<HomeBloc>()),

                            BlocProvider.value(
                              value: context.read<FavoriteBloc>(),
                            ),

                            BlocProvider.value(value: context.read<CarsBloc>()),
                          ],
                          child: const SearchScreen(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  color: Color.fromARGB(255, 1, 37, 90),
                ),
              ],
            ),

            body: bottomNavTabs[state.currentIndex],
            floatingActionButton: isSeller
                ? FloatingActionButton(
                    backgroundColor: Color.fromARGB(255, 1, 37, 90),
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
                    child: const Icon(Icons.add, color: Colors.white54),
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: state.currentIndex,
                items: bottomNavItems,

                backgroundColor: Colors.white,

                selectedItemColor: Color.fromARGB(255, 2, 45, 110),

                unselectedItemColor: Colors.black45,

                selectedFontSize: 13,
                unselectedFontSize: 11,

                elevation: 10,

                onTap: (index) {
                  context.read<HomeBloc>().add(HomeTabChanged(index));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
