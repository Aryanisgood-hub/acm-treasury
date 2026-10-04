import 'package:club_finance/core/utils/money.dart';
import 'package:club_finance/models/bill_filter.dart';
import 'package:club_finance/models/bill_model.dart';
import 'package:club_finance/models/event_model.dart';
import 'package:club_finance/providers/bill_provider.dart';
import 'package:club_finance/providers/budget_provider.dart';
import 'package:club_finance/providers/dashboard_provider.dart';
import 'package:club_finance/providers/event_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Bill bill(
  String id, {
  String event = 'e1',
  int amount = 100000,
  String status = 'active',
  String reason = 'Printing banners',
  String by = 'u1',
  String byName = 'Treasurer One',
  DateTime? date,
}) =>
    Bill(
      id: id,
      eventId: event,
      amount: amount,
      reason: reason,
      billDate: date ?? DateTime(2026, 9, 28),
      status: status,
      addedBy: by,
      addedByName: byName,
      addedByEmail: '$by@example.com',
      createdAt: DateTime(2026, 9, 28),
    );

final events = [
  EventModel(id: 'e1', name: 'Tech Fest 2026', createdAt: DateTime(2026, 9, 1)),
  EventModel(id: 'e2', name: 'Freshers 2026', createdAt: DateTime(2026, 9, 2)),
];

Future<DashboardData> dashboardFor(List<Bill> bills, int budget) async {
  final container = ProviderContainer(overrides: [
    totalBudgetProvider.overrideWith((ref) => Stream.value(budget)),
    eventsProvider.overrideWith((ref) => Stream.value(events)),
    billsProvider.overrideWith((ref) => Stream.value(bills)),
  ]);
  addTearDown(container.dispose);

  // Listen to the dashboard so it and everything it watches stay active.
  container.listen(dashboardProvider, (previous, next) {});
  for (var i = 0; i < 100; i++) {
    if (container.read(dashboardProvider).hasValue) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final state = container.read(dashboardProvider);
  expect(state.hasValue, isTrue, reason: 'dashboard state was $state');
  return state.value!;
}

void main() {
  group('Money', () {
    test('parses valid amounts into paise', () {
      expect(Money.parseToPaise('1250'), 125000);
      expect(Money.parseToPaise('1,250'), 125000);
      expect(Money.parseToPaise('1250.5'), 125050);
      expect(Money.parseToPaise('0.99'), 99);
    });

    test('rejects zero, negative and malformed amounts', () {
      for (final bad in ['', '0', '0.00', '-5', 'abc', '12.345', '.5', '1e5']) {
        expect(Money.parseToPaise(bad), isNull, reason: 'input "$bad"');
      }
    });

    test('formats paise as rupees with Indian grouping', () {
      expect(Money.format(5000000), contains('50,000'));
      expect(Money.format(12500000), contains('1,25,000'));
      expect(Money.format(125050), contains('1,250.50'));
    });

    test('toInputString round-trips', () {
      expect(Money.toInputString(125000), '1250');
      expect(Money.toInputString(125050), '1250.50');
    });
  });

  group('Dashboard totals', () {
    test('only ACTIVE bills count; remaining = budget - spent', () async {
      final d = await dashboardFor([
        bill('a', amount: 100000),
        bill('b', amount: 250000),
        bill('c', amount: 999999, status: 'voided'),
        bill('d', event: 'e2', amount: 50000),
      ], 5000000);
      expect(d.spent, 400000);
      expect(d.remaining, 4600000);
      expect(d.activeBillCount, 3);
      expect(d.overBudget, isFalse);
      final e1 = d.eventSummaries.firstWhere((s) => s.event.id == 'e1');
      final e2 = d.eventSummaries.firstWhere((s) => s.event.id == 'e2');
      expect(e1.billCount, 2);
      expect(e1.totalSpent, 350000);
      expect(e2.billCount, 1);
      expect(e2.totalSpent, 50000);
    });

    test('adding a bill raises spent and lowers remaining', () async {
      final before = await dashboardFor([bill('a')], 5000000);
      final after = await dashboardFor([bill('a'), bill('b')], 5000000);
      expect(after.spent - before.spent, 100000);
      expect(before.remaining - after.remaining, 100000);
    });

    test('editing 1000 -> 1500 raises spent by 500 rupees', () async {
      final before = await dashboardFor([bill('a', amount: 100000)], 5000000);
      final after = await dashboardFor([bill('a', amount: 150000)], 5000000);
      expect(after.spent - before.spent, 50000);
    });

    test('voiding a bill lowers spent and raises remaining', () async {
      final before = await dashboardFor([bill('a')], 5000000);
      final after = await dashboardFor([bill('a', status: 'voided')], 5000000);
      expect(before.spent - after.spent, 100000);
      expect(after.remaining - before.remaining, 100000);
    });

    test('spending above the budget is flagged', () async {
      final d = await dashboardFor([bill('a', amount: 150000)], 100000);
      expect(d.remaining, -50000);
      expect(d.overBudget, isTrue);
      expect(d.utilization, 1.0);
    });

    test('no budget set gives zero utilisation', () async {
      final d = await dashboardFor([bill('a')], 0);
      expect(d.utilization, 0);
    });
  });

  group('Bill search and filters', () {
    final names = {'e1': 'Tech Fest 2026', 'e2': 'Freshers 2026'};
    final all = [
      bill('a', reason: 'Printing banners', amount: 125000),
      bill('b', reason: 'Decoration', event: 'e2', by: 'u2', byName: 'Treasurer Two'),
      bill('c', reason: 'Stationery', status: 'voided', amount: 45000),
    ];

    List<String> ids(BillFilter f, [String q = '']) =>
        f.apply(all, names, q).map((b) => b.id).toList();

    test('empty filter returns everything', () {
      expect(ids(const BillFilter()), ['a', 'b', 'c']);
    });

    test('search matches reason, event, person and amount', () {
      expect(ids(const BillFilter(), 'print'), ['a']);
      expect(ids(const BillFilter(), 'freshers'), ['b']);
      expect(ids(const BillFilter(), 'two'), ['b']);
      expect(ids(const BillFilter(), '1250'), ['a']);
    });

    test('filters by event, person and status', () {
      expect(ids(const BillFilter(eventId: 'e2')), ['b']);
      expect(ids(const BillFilter(addedById: 'u2')), ['b']);
      expect(ids(const BillFilter(status: StatusFilter.voided)), ['c']);
      expect(ids(const BillFilter(status: StatusFilter.active)), ['a', 'b']);
    });

    test('filters by amount range and date range', () {
      expect(ids(const BillFilter(minPaise: 100000, maxPaise: 130000)), ['a', 'b']);
      expect(ids(const BillFilter(minPaise: 120000)), ['a']);
      final f = BillFilter(from: DateTime(2026, 9, 29), to: DateTime(2026, 10, 5));
      expect(ids(f), isEmpty);
    });

    test('counts active filters', () {
      expect(const BillFilter().activeCount, 0);
      expect(
          const BillFilter(eventId: 'e1', status: StatusFilter.voided).activeCount,
          2);
    });
  });
}
