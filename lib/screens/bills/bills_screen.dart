import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/money.dart';
import '../../models/bill_filter.dart';
import '../../models/bill_model.dart';
import '../../models/event_model.dart';
import '../../providers/bill_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/bill_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';
import 'bill_filter_sheet.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final _search = TextEditingController();
  String _query = '';
  BillFilter _filter = const BillFilter();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters(List<Bill> all, List<EventModel> events) async {
    final seen = <String, String>{};
    for (final b in all) {
      seen[b.addedBy] = b.addedByName;
    }
    final people = seen.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final result = await showBillFilterSheet(context,
        current: _filter, events: events, people: people);
    if (result != null) setState(() => _filter = result);
  }

  void _clearAll() {
    _search.clear();
    setState(() {
      _query = '';
      _filter = const BillFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(billsProvider);
    final events = ref.watch(eventsProvider).value ?? const <EventModel>[];
    final names = {for (final e in events) e.id: e.name};
    final all = bills.value ?? const <Bill>[];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: all.isEmpty ? null : () => _openFilters(all, events),
            icon: Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: bills.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(billsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No bills yet. Treasurers can add the first one.');
          }
          final shown = _filter.apply(list, names, _query);
          final activeTotal = shown
              .where((b) => b.isActive)
              .fold<int>(0, (sum, b) => sum + b.amount);
          final filtering = _query.isNotEmpty || !_filter.isEmpty;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search reason, event, person or amount',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${shown.length} of ${list.length} bills  •  '
                            '${Money.format(activeTotal)} active',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (filtering)
                          TextButton(
                              onPressed: _clearAll,
                              child: const Text('Clear')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: shown.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            message: 'No bills match your search or filters.',
                            actionLabel: 'Clear filters',
                            onAction: _clearAll,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => BillCard(
                              bill: shown[i],
                              eventName: names[shown[i].eventId],
                              onTap: () =>
                                  context.push('/bill/${shown[i].id}'),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
