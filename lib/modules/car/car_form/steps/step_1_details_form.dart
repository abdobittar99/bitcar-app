import 'package:car_shop/modules/car/car_form/bloc/car_form_bloc.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_state.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/app_choise_chip.dart';
import 'package:car_shop/shared/components/general_widget/app_dropdown.dart';
import 'package:car_shop/shared/components/general_widget/app_formfield.dart';
import 'package:car_shop/shared/components/general_widget/color_selector.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddCarDetailsForm extends StatefulWidget {
  const AddCarDetailsForm({super.key});

  @override
  State<AddCarDetailsForm> createState() => _AddCarDetailsFormState();
}

class _AddCarDetailsFormState extends State<AddCarDetailsForm> {
  late TextEditingController modelController;
  late TextEditingController priceController;
  late TextEditingController descriptionController;
  late TextEditingController mileageController;
  late TextEditingController horsePowerController;

  @override
  void initState() {
    super.initState();
    final state = context.read<CarFormBloc>().state;

    modelController = TextEditingController(text: state.model);
    priceController = TextEditingController(
      text: state.price != 0 ? '${state.price}' : '',
    );
    descriptionController = TextEditingController(text: state.description);
    mileageController = TextEditingController(
      text: state.mileage != 0 ? '${state.mileage}' : '',
    );
    horsePowerController = TextEditingController(
      text: state.horsePower != 0 ? '${state.horsePower}' : '',
    );
  }

  void _sync(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CarFormBloc, CarFormState>(
      listener: (context, state) {
        _sync(modelController, state.model);
        _sync(priceController, state.price != 0 ? '${state.price}' : '');
        _sync(descriptionController, state.description);
        _sync(mileageController, state.mileage != 0 ? '${state.mileage}' : '');
        _sync(
          horsePowerController,
          state.horsePower != 0 ? '${state.horsePower}' : '',
        );
      },
      builder: (context, state) {
        final bloc = context.read<CarFormBloc>();
        return Scaffold(
          appBar: AppBar(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: "Basic Info"),
                const SizedBox(height: 12),

                AppDropdown(
                  label: 'Brand',
                  value:
                      state.brand.isNotEmpty &&
                          CarData.brand.contains(state.brand)
                      ? state.brand
                      : null,

                  items: buildItems(CarData.brand),
                  onChanged: (v) {
                    bloc.add(AddCarBrandChanged(v ?? ''));
                  },
                ),

                const SizedBox(height: 12),

                AppFormField(
                  label: 'Model',
                  controller: modelController,
                  onChanged: (v) => bloc.add(AddCarModelChanged(v)),
                ),
                const SizedBox(height: 12),

                YearDropdown(
                  selectedYear: state.year == 0 ? null : state.year,
                  onChanged: (v) => bloc.add(AddCarYearChanged(v ?? 0)),
                ),
                const SizedBox(height: 12),

                AppDropdown(
                  label: 'Location',
                  value:
                      state.location.isNotEmpty &&
                          CarData.location.contains(state.location)
                      ? state.location
                      : null,
                  items: buildItems(CarData.location),
                  onChanged: (v) => bloc.add(AddCarLocationChanged(v ?? '')),
                ),

                const SizedBox(height: 24),

                SectionHeader(title: "Details"),
                const SizedBox(height: 12),

                AppFormField(
                  label: 'Price',
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      bloc.add(AddCarPriceChanged(int.tryParse(v) ?? 0)),
                ),
                const SizedBox(height: 12),

                AppFormField(
                  label: 'Mileage',
                  controller: mileageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) =>
                      bloc.add(AddCarMileageChanged(int.tryParse(v) ?? 0)),
                ),
                const SizedBox(height: 12),

                AppFormField(
                  label: 'Horsepower',
                  controller: horsePowerController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) =>
                      bloc.add(AddCarHorsePowerChanged(int.tryParse(v) ?? 0)),
                ),

                const SizedBox(height: 24),

                SectionHeader(title: "Description"),
                const SizedBox(height: 12),

                AppFormField(
                  label: "Description",
                  controller: descriptionController,
                  maxLines: 3,
                  onChanged: (v) => bloc.add(AddCarDescriptionChanged(v)),
                ),

                const SizedBox(height: 24),

                SectionHeader(title: "Appearance"),
                const SizedBox(height: 12),

                AppDropdown(
                  label: 'Body Type',
                  value:
                      state.bodyType.isNotEmpty &&
                          CarData.bodyType.contains(state.bodyType)
                      ? state.bodyType
                      : null,
                  items: buildItems(CarData.bodyType),
                  onChanged: (v) => bloc.add(AddCarBodyTypeChanged(v ?? '')),
                ),
                const SizedBox(height: 12),

                AppDropdown(
                  label: 'Fuel Type',
                  value:
                      state.fuelType.isNotEmpty &&
                          CarData.fuelType.contains(state.fuelType)
                      ? state.fuelType
                      : null,
                  items: buildItems(CarData.fuelType),
                  onChanged: (v) => bloc.add(AddCarFuelTypeChanged(v ?? '')),
                ),
                const SizedBox(height: 12),

                const Text("Color"),
                const SizedBox(height: 8),

                ColorSelector(
                  selected: state.color,
                  onChanged: (c) => bloc.add(AddCarColorChanged(c)),
                ),

                const SizedBox(height: 12),

                AppSelectableGroup<String>(
                  items: const ['zero', 'used'],
                  selected: state.carCondition,
                  labelBuilder: (v) => v,
                  onChanged: (v) => bloc.add(AddCarConditionChanged(v)),
                ),

                const SizedBox(height: 24),

                AppButton(
                  text: 'Next',
                  onPressed: () => bloc.add(AddCarNextStepPressed()),
                ),

                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
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
    modelController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    mileageController.dispose();
    horsePowerController.dispose();
    super.dispose();
  }
}
