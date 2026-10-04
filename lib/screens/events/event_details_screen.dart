import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/money.dart';
import '../../models/bill_model.dart';
import '../../models/event_model.dart';
import '../../providers/bill_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/bill_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';

class EventDetailsScreen extends ConsumerWidget {
  const EventDetailsScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(eventSummariesProvider);
    final bills = ref.watch(billsProvider);

    return summaries.when(
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(appBar: AppBar(), body: ErrorView(message: friendlyError(e))),
      data: (list) {
        EventSummary? summary;
        for (final s in list) {
          if (s.event.id == eventId) summary = s;
        }
        if (summary == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const ErrorView(message: 'This event could not be found.'));
        }
        final eventBills = (bills.value ?? const <Bill>[])
            .where((b) => b.eventId == eventId)
            .toList();
        return Scaffold(
          appBar: AppBar(title: Text(summary.event.name)),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(summary: summary),
                  const SizedBox(height: 16),
                  if (eventBills.isEmpty)
                    const SizedBox(
                      height: 240,
                      child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: 'No bills for this event yet.'),
                    )
                  else
                    for (final b in eventBills)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BillCard(
                            bill: b,
                            onTap: () => context.push('/bill/${b.id}')),
                      ),
                  if (eventBills.isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('EVENT TOTAL',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(Money.format(summary.totalSpent),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});
  final EventSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value,
                  style: text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((summary.event.description ?? '').isNotEmpty) ...[
              Text(summary.event.description!),
              const SizedBox(height: 16),
            ],
            Row(children: [
              stat('Total bills', '${summary.billCount}'),
              stat('Total spent', Money.format(summary.totalSpent)),
            ]),
          ],
        ),
      ),
    );
  }
}
