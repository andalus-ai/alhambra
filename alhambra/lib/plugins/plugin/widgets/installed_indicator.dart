import 'package:flutter/material.dart';

class InstalledIndicator extends StatelessWidget {
  const InstalledIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green[300], size: 16),
          const SizedBox(width: 4),
          Text(
            'Installed',
            style: TextStyle(color: Colors.green[300], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
