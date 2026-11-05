import 'package:flutter/material.dart';

// Shown while the chat only has data from the device cache (FR-014b).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade300,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: Colors.black54),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're offline. Showing saved messages.",
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
