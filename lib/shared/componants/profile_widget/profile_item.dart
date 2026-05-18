import 'package:flutter/material.dart';

class ProfileStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLoading;

  const ProfileStatItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28),

        const SizedBox(height: 6),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  value,
                  key: const ValueKey('value'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),

        const SizedBox(height: 2),

        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
