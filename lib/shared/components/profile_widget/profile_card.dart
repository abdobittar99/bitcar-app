import 'package:flutter/material.dart';

class ProfileStatsCard extends StatelessWidget {
  final Widget child;

  const ProfileStatsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: child,
    );
  }
}
