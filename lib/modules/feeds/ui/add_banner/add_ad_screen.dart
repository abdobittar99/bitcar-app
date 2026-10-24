import 'package:car_shop/core/image_source/image_source.dart';
import 'package:car_shop/entities/ad.dart';
import 'package:car_shop/modules/feeds/bloc/feeds_bloc.dart';
import 'package:car_shop/modules/feeds/bloc/feeds_event.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/app_dropdown.dart';
import 'package:car_shop/shared/components/general_widget/app_formfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AddAdScreen extends StatefulWidget {
  final ImageSource imageSource;

  const AddAdScreen({super.key, required this.imageSource});

  @override
  State<AddAdScreen> createState() => _AddAdScreenState();
}

class _AddAdScreenState extends State<AddAdScreen> {
  final formKey = GlobalKey<FormState>();

  final linkController = TextEditingController();
  final orderController = TextEditingController();

  DateTime? expiryDate;

  String? selectedImage;

  List<String> images = [];

  @override
  void initState() {
    super.initState();

    _loadImages();
  }

  Future<void> _loadImages() async {
    final result = await widget.imageSource.pickImages();

    setState(() {
      images = result;
    });
  }

  @override
  void dispose() {
    linkController.dispose();
    orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addState = context.read<FeedsBloc>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Advertisement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              AppDropdown(
                label: 'select image',
                value: selectedImage,
                items: images.map((image) {
                  return DropdownMenuItem(
                    value: image,
                    child: Text(image.split('/').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedImage = value;
                  });
                },
                validator: (_) {
                  if (selectedImage == null) {
                    return 'Please select image';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),
              AppFormField(
                controller: linkController,
                keyboardType: TextInputType.text,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter contact link';
                  }

                  return null;
                },
                label: 'contact link',
              ),

              const SizedBox(height: 20),

              AppFormField(
                controller: orderController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter order';
                  }

                  if (int.tryParse(value) == null) {
                    return 'Order must be number';
                  }

                  return null;
                },
                label: 'Ad Order',
              ),

              const SizedBox(height: 20),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  expiryDate == null
                      ? 'Select Expiry Date'
                      : DateFormat('dd / MM / yyyy').format(expiryDate!),
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    initialDate: DateTime.now(),
                  );

                  if (picked != null) {
                    setState(() {
                      expiryDate = picked;
                    });
                  }
                },
              ),

              if (expiryDate == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Please select expiry date',
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 30),
              AppButton(
                text: 'Add Advertisement',
                isLoading: addState.isAdLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final isValid = formKey.currentState!.validate();

    if (!isValid) return;

    if (expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expiry date')),
      );
      return;
    }

    if (expiryDate!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry date cannot be in the past')),
      );
      return;
    }

    final phone = linkController.text.trim();

    final link = phone;

    final ad = AdEntity(
      id: '',
      image: selectedImage!,
      whatsappLink: link,
      order: int.parse(orderController.text),
      expiryDate: expiryDate!,
    );

    context.read<FeedsBloc>().add(AddAdPressed(ad));

    Navigator.pop(context, true);
  }
}
