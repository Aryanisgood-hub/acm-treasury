import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.note,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = color ?? scheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: text.labelMedium?.copyWith(
                        letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
              ),
            ]),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: color)),
            ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note!, style: text.bodySmall?.copyWith(color: accent)),
            ],
          ],
        ),
      ),
    );
  }
}
