import 'package:flutter/material.dart';

import '../core/utils/money.dart';
import '../models/event_model.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.summary, required this.onTap});
  final EventSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.event.name,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        '${summary.billCount} bill${summary.billCount == 1 ? '' : 's'}',
                        style: text.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Text(Money.format(summary.totalSpent),
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
