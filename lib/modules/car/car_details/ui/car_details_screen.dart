import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/modules/car/car_details/bloc/car_details_bloc.dart';
import 'package:car_shop/modules/car/car_details/bloc/car_details_event.dart';
import 'package:car_shop/modules/car/car_details/bloc/car_details_state.dart';
import 'package:car_shop/modules/car/car_details/ui/details_section.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_bloc.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_event.dart';
import 'package:car_shop/modules/favorite/bloc/favorite_state.dart';
import 'package:car_shop/shared/componants/car_widget/car_conditional_badge.dart';
import 'package:car_shop/shared/componants/car_widget/details_inforow.dart';
import 'package:car_shop/shared/componants/general_widget/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class CarDetailsScreen extends StatelessWidget {
  final String carId;
  const CarDetailsScreen({super.key, required this.carId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Car Details')),
      body: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => sl<CarDetailsBloc>()..add(CarDetailsStarted(carId)),
          ),
          // BlocProvider(create: (_) => FavoriteBloc()..add(FavoriteStarted())),
        ],

        child: BlocConsumer<CarDetailsBloc, CarDetailsState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final car = state.car;
            if (car == null) {
              return const SizedBox();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 230,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: car.images.isNotEmpty
                              ? car.images.length
                              : 1,
                          itemBuilder: (context, index) {
                            final image = car.images.isNotEmpty
                                ? car.images[index]
                                : 'assets/cars/car3.jpg';

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(image, fit: BoxFit.cover),
                            );
                          },
                        ),

                        Positioned(
                          top: 10,
                          left: 10,
                          child: CarConditionBadge(condition: car.carCondition),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "${car.brand} ${car.model}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        "\$${car.price.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  DetailsSection(
                    title: "Specifications",
                    child: Column(
                      children: [
                        InfoRow(label: 'Year', value: car.year.toString()),
                        InfoRow(
                          label: 'Mileage',
                          value: car.mileage.toString(),
                        ),
                        InfoRow(label: 'HP', value: car.horsePower.toString()),
                        InfoRow(label: 'Fuel', value: car.fuelType),
                        InfoRow(label: 'Body', value: car.bodyType),
                        InfoRow(label: 'Color', value: car.color),
                      ],
                    ),
                  ),

                  DetailsSection(
                    title: "Location",
                    child: InfoRow(label: 'City', value: car.location),
                  ),

                  DetailsSection(
                    title: "Description",
                    child: Text(
                      car.description,
                      style: const TextStyle(height: 1.4),
                    ),
                  ),

                  Row(
                    children: [
                      BlocBuilder<FavoriteBloc, FavoriteState>(
                        builder: (context, favState) {
                          final isFav = favState.favoriteCarIds.contains(carId);

                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : Colors.grey,
                            ),
                            onPressed: () {
                              context.read<FavoriteBloc>().add(
                                FavoriteToggled(carId: carId, car: car),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Contact Seller',
                      icon: Icons.phone,
                      onPressed: () async {
                        final Uri phoneUri = Uri(
                          scheme: 'tel',
                          path: car.phone,
                        );

                        if (await canLaunchUrl(phoneUri)) {
                          await launchUrl(phoneUri);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Future<void> _openWhatsApp(String url) async {
  //   final uri = Uri.parse(url);

  //   if (await canLaunchUrl(uri)) {
  //     await launchUrl(uri, mode: LaunchMode.externalApplication);
  //   }
  // }
}
