import 'package:flutter/material.dart';

/// Temporary screen for sections built in later stages.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text('$title is coming in a later stage',
                style: TextStyle(color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}
