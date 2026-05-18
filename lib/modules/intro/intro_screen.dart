import 'package:car_shop/core/cach/cache_helper.dart';
import 'package:car_shop/core/cach/cache_keys.dart';
import 'package:car_shop/modules/splash/bloc/splash_bloc.dart';
import 'package:car_shop/modules/splash/bloc/splash_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/cars/intro.png', fit: BoxFit.cover),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withAlpha(40)],
                ),
              ),
            ),
          ),

          /// Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 70, 111, 165),
                            Color.fromARGB(255, 4, 59, 143),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                            color: Colors.blue.withAlpha(80),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        onPressed: () async {
                          await CacheHelper.saveData(
                            key: CacheKeys.introSeen,
                            value: true,
                          );
                          if (!context.mounted) return;

                          context.read<SplashBloc>().add(GoToLoginPressed());
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),

                            SizedBox(width: 14),

                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
