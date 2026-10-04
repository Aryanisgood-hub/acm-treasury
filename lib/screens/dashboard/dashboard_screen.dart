import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_info.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/money.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/bill_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/event_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final member = ref.watch(currentMemberProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text(AppInfo.appName)),
      body: dash.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () {
            ref.invalidate(totalBudgetProvider);
            ref.invalidate(billsProvider);
            ref.invalidate(eventsProvider);
          },
        ),
        data: (d) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          final Color remainingColor = d.overBudget
              ? scheme.error
              : d.utilization >= 0.8
                  ? Colors.orange
                  : Colors.green;
          final names = {
            for (final s in d.eventSummaries) s.event.id: s.event.name
          };

          final cards = [
            StatCard(
                label: 'TOTAL BUDGET',
                value: Money.format(d.budget),
                icon: Icons.account_balance_outlined),
            StatCard(
                label: 'TOTAL SPENT',
                value: Money.format(d.spent),
                icon: Icons.payments_outlined,
                note: '${d.activeBillCount} active bill'
                    '${d.activeBillCount == 1 ? '' : 's'}'),
            StatCard(
                label: 'REMAINING BALANCE',
                value: Money.format(d.remaining),
                icon: Icons.savings_outlined,
                color: remainingColor,
                note: d.overBudget ? 'Over budget' : null),
          ];

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (member != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Hello, ${member.name} (${member.role.label})',
                        style: text.titleMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  LayoutBuilder(builder: (context, c) {
                    if (c.maxWidth >= 640) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < cards.length; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    right: i == cards.length - 1 ? 0 : 12),
                                child: cards[i],
                              ),
                            ),
                        ],
                      );
                    }
                    return Column(children: [
                      for (final card in cards)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card),
                    ]);
                  }),
                  const SizedBox(height: 4),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.budget <= 0
                                ? 'No budget has been set yet'
                                : '${(d.utilization * 100).toStringAsFixed(0)}% of budget used',
                            style: text.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: d.utilization,
                              minHeight: 10,
                              color: remainingColor,
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Spending by event',
                    action: 'View all',
                    onAction: () => context.go('/events'),
                  ),
                  if (d.eventSummaries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No events yet.'),
                    )
                  else
                    for (final s in d.eventSummaries.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EventCard(
                          summary: s,
                          onTap: () => context.push('/event/${s.event.id}'),
                        ),
                      ),
                  const SizedBox(height: 12),
                  _SectionHeader(
                    title: 'Recent bills',
                    action: 'View all',
                    onAction: () => context.go('/bills'),
                  ),
                  if (d.recentBills.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No bills yet.'),
                    )
                  else
                    for (final b in d.recentBills)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BillCard(
                          bill: b,
                          eventName: names[b.eventId],
                          onTap: () => context.push('/bill/${b.id}'),
                        ),
                      ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title, required this.action, required this.onAction});
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      );
}
