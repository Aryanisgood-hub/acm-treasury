import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill_model.dart';
import '../models/event_model.dart';
import 'bill_provider.dart';
import 'budget_provider.dart';
import 'event_provider.dart';

class DashboardData {
  const DashboardData({
    required this.budget,
    required this.spent,
    required this.activeBillCount,
    required this.eventSummaries,
    required this.recentBills,
  });

  final int budget; // paise
  final int spent; // paise, ACTIVE bills only
  final int activeBillCount;
  final List<EventSummary> eventSummaries; // highest spend first
  final List<Bill> recentBills;

  int get remaining => budget - spent;
  bool get overBudget => remaining < 0;
  double get utilization =>
      budget <= 0 ? 0 : (spent / budget).clamp(0.0, 1.0).toDouble();
}

/// Everything is derived from live data; no totals are stored or hard-coded.
final dashboardProvider = Provider<AsyncValue<DashboardData>>((ref) {
  final budget = ref.watch(totalBudgetProvider);
  final bills = ref.watch(billsProvider);
  final events = ref.watch(eventSummariesProvider);

  return budget.when(
    loading: () => const AsyncValue<DashboardData>.loading(),
    error: (e, s) => AsyncValue<DashboardData>.error(e, s),
    data: (b) => bills.when(
      loading: () => const AsyncValue<DashboardData>.loading(),
      error: (e, s) => AsyncValue<DashboardData>.error(e, s),
      data: (bs) => events.when(
        loading: () => const AsyncValue<DashboardData>.loading(),
        error: (e, s) => AsyncValue<DashboardData>.error(e, s),
        data: (es) {
          final active = bs.where((x) => x.isActive).toList();
          final sorted = [...es]
            ..sort((a, c) => c.totalSpent.compareTo(a.totalSpent));
          return AsyncValue<DashboardData>.data(DashboardData(
            budget: b,
            spent: active.fold<int>(0, (sum, x) => sum + x.amount),
            activeBillCount: active.length,
            eventSummaries: sorted,
            recentBills: active.take(5).toList(),
          ));
        },
      ),
    ),
  );
});
