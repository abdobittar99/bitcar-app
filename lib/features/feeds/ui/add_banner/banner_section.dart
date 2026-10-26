import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/core/image_source/image_source.dart';
import 'package:car_shop/entities/ad.dart';
import 'package:car_shop/features/feeds/bloc/feeds_bloc.dart';
import 'package:car_shop/features/feeds/bloc/feeds_event.dart';
import 'package:car_shop/features/feeds/bloc/feeds_state.dart';
import 'package:car_shop/features/home/bloc/home_bloc.dart';
import 'package:car_shop/features/feeds/ui/add_banner/add_ad_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeBannerSection extends StatefulWidget {
  const HomeBannerSection({super.key});

  @override
  State<HomeBannerSection> createState() => _HomeBannerSectionState();
}

class _HomeBannerSectionState extends State<HomeBannerSection> {
  final CarouselSliderController controller = CarouselSliderController();

  int currentIndex = 0;

  bool autoPlay = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeedsBloc, FeedsState>(
      builder: (context, state) {
        final ads = state.ads;
        final roleState = context.read<HomeBloc>().state.role;
        final isAdmin = roleState == UserRole.admin;
        if (state.isAdLoading) {
          return const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (ads.isEmpty) {
          if (isAdmin) {
            return _EmptyAdsPlaceholder();
          }

          return const SizedBox();
        }

        return Column(
          children: [
            GestureDetector(
              onTapDown: (_) {
                setState(() {
                  autoPlay = false;
                });
              },
              onTapUp: (_) {
                setState(() {
                  autoPlay = true;
                });
              },
              child: CarouselSlider.builder(
                carouselController: controller,
                itemCount: ads.length,
                itemBuilder: (context, index, realIndex) {
                  final ad = ads[index];

                  return _AdBannerWidget(ad: ad, role: roleState);
                },
                options: CarouselOptions(
                  height: 190,
                  autoPlay: autoPlay,
                  enlargeCenterPage: true,
                  viewportFraction: 0.92,
                  autoPlayInterval: const Duration(seconds: 4),
                  onPageChanged: (index, reason) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                ads.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentIndex == index
                        ? const Color(0xFF0D47A1)
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdBannerWidget extends StatelessWidget {
  final AdEntity ad;
  final UserRole? role;

  const _AdBannerWidget({required this.ad, required this.role});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openWhatsApp(ad.whatsappLink),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              ad.image,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withAlpha(80), Colors.transparent],
              ),
            ),
          ),

          Positioned(
            bottom: 12,
            right: 12,
            child: _circleButton(
              icon: Icons.chat,
              onTap: () {
                _openWhatsApp(ad.whatsappLink);
              },
            ),
          ),

          if (role == UserRole.admin)
            Positioned(
              top: 12,
              left: 12,
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.add,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<FeedsBloc>(),
                            child: AddAdScreen(imageSource: sl<ImageSource>()),
                          ),
                        ),
                      );

                      if (!context.mounted) return;

                      if (result == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add Ad Successfully')),
                        );
                        context.read<FeedsBloc>().add(LoadAds());
                      }
                    },
                  ),

                  const SizedBox(width: 8),

                  _circleButton(
                    icon: Icons.delete,
                    onTap: () {
                      context.read<FeedsBloc>().add(DeleteAdPressed(ad.id));
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

Future<void> _openWhatsApp(String url) async {
  final uri = Uri.parse(url);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _EmptyAdsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Center(
        child: IconButton(
          iconSize: 45,
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<FeedsBloc>(),
                  child: AddAdScreen(imageSource: sl<ImageSource>()),
                ),
              ),
            );

            if (!context.mounted) return;

            if (result == true) {
              context.read<FeedsBloc>().add(LoadAds());
            }
          },
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }
}
