import 'package:car_shop/modules/profile/bloc/profile_bloc.dart';
import 'package:car_shop/modules/profile/bloc/profile_event.dart';
import 'package:car_shop/modules/profile/bloc/profile_state.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/app_formfield.dart';
import 'package:car_shop/shared/components/general_widget/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();

    final user = context.read<ProfileBloc>().state.user;

    nameController = TextEditingController(text: user?.fullName ?? '');
    phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listenWhen: (p, c) => p.isSuccess != c.isSuccess,
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Edit Profile")),

        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 40,
                      child: Icon(Icons.person, size: 40),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SectionHeader(title: "Personal Info"),
                  const SizedBox(height: 12),

                  AppFormField(
                    label: "Full Name",
                    controller: nameController,
                    validator: AppValidators.required,
                  ),

                  const SizedBox(height: 12),

                  AppFormField(
                    label: "Phone",
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    validator: AppValidators.phone,
                  ),

                  const SizedBox(height: 30),

                  BlocBuilder<ProfileBloc, ProfileState>(
                    builder: (context, state) {
                      return AppButton(
                        text: "Save",
                        isLoading: state.isLoading,
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;

                          context.read<ProfileBloc>().add(
                            ProfileUpdated(
                              fullName: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
