import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_bloc.dart';
import 'package:car_shop/features/car/cars_list/bloc/cars_list_event.dart';
import 'package:car_shop/features/car/my_cars/bloc/my_cars_bloc.dart';
import 'package:car_shop/features/car/my_cars/bloc/my_cars_event.dart';
import 'package:car_shop/features/car/my_cars/bloc/my_cars_state.dart';
import 'package:car_shop/features/car/my_cars/ui/my_cars_screen.dart';
import 'package:car_shop/features/home/bloc/home_event.dart';
import 'package:car_shop/features/home/bloc/home_state.dart';
import 'package:car_shop/features/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/features/favorite/bloc/favorite_event.dart';
import 'package:car_shop/features/favorite/bloc/favorite_state.dart';
import 'package:car_shop/features/profile/ui/edit_profile_screen.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/profile/bloc/profile_bloc.dart';
import 'package:car_shop/features/profile/bloc/profile_event.dart';
import 'package:car_shop/features/profile/bloc/profile_state.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:car_shop/shared/components/profile_widget/profile_item.dart';
import 'package:car_shop/shared/components/profile_widget/profile_card.dart';
import 'package:car_shop/shared/components/profile_widget/profile_header.dart';
import 'package:car_shop/shared/components/profile_widget/profile_info_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final roleState = context.read<HomeBloc>().state.role;
        final isSeller = roleState == UserRole.seller;
        if (state.isLoading || state.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = state.user!;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<ProfileBloc>().add(
              ProfileRequested(forceRefresh: true),
            );
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ProfileHeader(
                name: user.fullName,
                onEdit: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ProfileBloc>(),
                        child: const EditProfileScreen(),
                      ),
                    ),
                  );

                  if (!context.mounted) return;

                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Update User Successfully')),
                    );
                    context.read<ProfileBloc>().add(
                      ProfileRequested(forceRefresh: true),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              SectionHeader(title: "Activity"),
              const SizedBox(height: 12),

              ProfileStatsCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (isSeller)
                      BlocSelector<MyCarsBloc, MyCarsState, MyCarsState>(
                        selector: (s) => s,
                        builder: (_, s) => ProfileStatItem(
                          icon: Icons.directions_car,
                          label: "My Cars",
                          value: s.myCars.length.toString(),
                          isLoading: s.isLoading,
                        ),
                      ),
                    BlocSelector<FavoriteBloc, FavoriteState, FavoriteState>(
                      selector: (s) => s,
                      builder: (_, s) => ProfileStatItem(
                        icon: Icons.favorite,
                        label: "Favorites",
                        value: s.favoriteCarIds.length.toString(),
                        isLoading: s.isLoading,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SectionHeader(title: "Personal Info"),
              const SizedBox(height: 12),

              ProfileStatsCard(
                child: Column(
                  children: [
                    ProfileInfoTile(icon: Icons.email, value: user.email),
                    const SizedBox(height: 12),
                    ProfileInfoTile(icon: Icons.phone, value: user.phone),
                    const SizedBox(height: 12),
                    ProfileInfoTile(icon: Icons.person, value: user.role.name),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (isSeller)
                AppButton(
                  text: "My Cars",
                  icon: Icons.directions_car,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiBlocProvider(
                          providers: [
                            BlocProvider.value(
                              value: context.read<MyCarsBloc>(),
                            ),

                            // BlocProvider(
                            //   create: (_) =>
                            //       sl<MyCarsBloc>()..add(MyCarsStarted()),
                            // ),
                            BlocProvider.value(
                              value: context.read<FavoriteBloc>(),
                            ),

                            BlocProvider.value(value: context.read<CarsBloc>()),
                          ],
                          child: const MyCarsScreen(),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 16),

              BlocListener<HomeBloc, HomeState>(
                listenWhen: (prev, curr) => prev.isSuccess != curr.isSuccess,
                listener: (context, state) {
                  if (state.isSuccess) {
                    context.read<ProfileBloc>().add(ProfileCleared());
                    context.read<MyCarsBloc>().add(ClearMycars());
                    context.read<CarsBloc>().add(ClearCars());
                    context.read<FavoriteBloc>().add(ClearFavorite());
                  }
                },
                child: AppButton(
                  text: "Logout",
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  textStyle: const TextStyle(color: Colors.red),
                  isLoading: state.isLoading,
                  onPressed: () {
                    context.read<HomeBloc>().add(LogoutPressed());
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
