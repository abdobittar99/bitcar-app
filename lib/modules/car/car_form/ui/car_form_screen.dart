import 'package:car_shop/core/enums/add_car_steps.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_state.dart';
import 'package:car_shop/modules/car/car_form/steps/step_3_contact_form.dart';
import 'package:car_shop/modules/car/car_form/steps/step_1_details_form.dart';
import 'package:car_shop/modules/car/car_form/steps/step_2_images_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hexcolor/hexcolor.dart';

class AddCarScreen extends StatelessWidget {
  const AddCarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CarFormBloc, CarFormState>(
      builder: (context, state) {
        return Stack(
          children: [
            switch (state.step) {
              AddCarStep.details => AddCarDetailsForm(),
              AddCarStep.images => AddCarImagesForm(),
              AddCarStep.contact => AddCarContactForm(),
            },

            if (state.isLoading)
              Container(
                color: HexColor('#cfcfe3'),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}
