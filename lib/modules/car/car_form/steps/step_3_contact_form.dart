import 'package:car_shop/core/enums/car_form_mode.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_state.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/app_formfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddCarContactForm extends StatefulWidget {
  const AddCarContactForm({super.key});

  @override
  State<AddCarContactForm> createState() => _AddCarContactFormState();
}

class _AddCarContactFormState extends State<AddCarContactForm> {
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();

    final state = context.read<CarFormBloc>().state;
    phoneController = TextEditingController(text: state.phone);
  }

  void _sync(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CarFormBloc, CarFormState>(
      listener: (context, state) {
        if (state.isSuccess) {
          _sync(phoneController, state.phone);
          Navigator.pop(context, true);
        }
      },
      builder: (context, state) {
        final bloc = context.read<CarFormBloc>();
        return Scaffold(
          appBar: AppBar(),
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                AppFormField(
                  label: 'Phone Number',
                  prefixIcon: Icons.contact_phone_outlined,
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) {
                    bloc.add(AddCarContactChanged(v));
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: state.mode == CarFormMode.add
                            ? 'Add Car'
                            : 'Update Car',
                        isLoading: state.isLoading,
                        textStyle: TextStyle(color: Colors.black),
                        onPressed: () {
                          context.read<CarFormBloc>().add(
                            state.mode == CarFormMode.add
                                ? AddCarSubmitted()
                                : UpdateCarSubmitted(),
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

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }
}
