// ignore_for_file: unused_import

import 'package:car_shop/core/image_source/image_source.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_state.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddCarImagesForm extends StatelessWidget {
  const AddCarImagesForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CarFormBloc, CarFormState>(
      builder: (context, state) {
        final images = state.images ?? [];

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Add car images'),
                const SizedBox(height: 16),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final hasImage = index < images.length;

                    return GestureDetector(
                      onTap: () {
                        context.read<CarFormBloc>().add(
                          AddCarPickImagesPressed(),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                          color: Colors.grey.shade100,
                        ),
                        child: hasImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  images[index],
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Next',
                        textStyle: TextStyle(color: Colors.black),
                        onPressed: () {
                          context.read<CarFormBloc>().add(
                            AddCarNextStepPressed(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'Back',
                        textStyle: TextStyle(color: Colors.red),
                        onPressed: () {
                          context.read<CarFormBloc>().add(
                            AddCarPreviousStepPressed(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
