import 'package:car_shop/core/utils/search_utils.dart';
import 'package:car_shop/features/search/bloc/search_bloc.dart';
import 'package:car_shop/features/search/bloc/search_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchField extends StatefulWidget {
  const SearchField({super.key});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        final keywords = normalizeSearchQuery(value);

        context.read<SearchBloc>().add(
          SearchSubmitted(keywords, context.read<SearchBloc>().state.filters),
        );
      },
      decoration: InputDecoration(
        hintText: 'Search cars...',
        border: InputBorder.none,

        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();

                  context.read<SearchBloc>().add(ClearSearch());
                },
                icon: const Icon(Icons.close_outlined),
              ),
      ),
    );
  }
}
