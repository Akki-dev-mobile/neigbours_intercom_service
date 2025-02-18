import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No Members Found.\nSearch members by their name or flat',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
