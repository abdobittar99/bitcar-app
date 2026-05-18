import 'package:flutter/material.dart';

class CompareSpecRow extends StatelessWidget {
  final String title;
  final String v1;
  final String v2;
  final bool isBetter1;
  final bool isBetter2;
  final bool isPlain;

  const CompareSpecRow({
    super.key,
    required this.title,
    required this.v1,
    required this.v2,
    required this.isBetter1,
    required this.isBetter2,
  }) : isPlain = false;

  const CompareSpecRow.plain({
    super.key,
    required this.title,
    required this.v1,
    required this.v2,
  }) : isBetter1 = false,
       isBetter2 = false,
       isPlain = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              v1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isBetter1 ? FontWeight.bold : FontWeight.normal,
                color: isBetter1 ? Colors.green : null,
              ),
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Text(title),
                if (!isPlain)
                  Text(
                    isBetter1
                        ? "Better"
                        : isBetter2
                        ? "Better"
                        : "Equal",
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Text(
              v2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isBetter2 ? FontWeight.bold : FontWeight.normal,
                color: isBetter2 ? Colors.green : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
