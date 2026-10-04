import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/utils/money.dart';
import '../models/bill_model.dart';

class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.bill,
    required this.onTap,
    this.eventName,
  });
  final Bill bill;
  final String? eventName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = bill.isVoided ? scheme.outline : null;
    final deco = bill.isVoided ? TextDecoration.lineThrough : null;
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
                    Text(bill.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: muted,
                            decoration: deco)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        ?eventName,
                        fmtDate(bill.billDate),
                        bill.addedByName,
                      ].join('  •  '),
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Money.format(bill.amount),
                      style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: muted,
                          decoration: deco)),
                  if (bill.isVoided)
                    Text('VOIDED',
                        style: text.labelSmall?.copyWith(
                            color: scheme.error, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
