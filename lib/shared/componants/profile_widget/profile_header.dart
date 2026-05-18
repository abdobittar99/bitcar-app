import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final VoidCallback onEdit;

  const ProfileHeader({super.key, required this.name, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            const CircleAvatar(
              backgroundColor: Color.fromARGB(255, 190, 210, 241),
              radius: 45,
              child: Icon(
                Icons.person,
                color: Color.fromARGB(255, 1, 37, 90),
                size: 45,
              ),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: Color.fromARGB(255, 85, 125, 185),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                color: Colors.white,
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
