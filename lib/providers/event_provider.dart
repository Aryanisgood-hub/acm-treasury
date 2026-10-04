import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_model.dart';
import '../repositories/event_repository.dart';
import 'auth_provider.dart';
import 'bill_provider.dart';

final eventRepositoryProvider = Provider<EventRepository>(
    (ref) => EventRepository(Supabase.instance.client));

final eventsProvider = StreamProvider<List<EventModel>>((ref) {
  ref.watch(userIdProvider); // resubscribe when the signed-in user changes
  final stream = ref.watch(eventRepositoryProvider).watchEvents();
  return stream.map((list) => [...list]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
});

/// Totals are derived from ACTIVE bills only; voided bills never count.
final eventSummariesProvider =
    Provider<AsyncValue<List<EventSummary>>>((ref) {
  final events = ref.watch(eventsProvider);
  final bills = ref.watch(billsProvider);
  return events.when(
    loading: () => const AsyncValue<List<EventSummary>>.loading(),
    error: (e, s) => AsyncValue<List<EventSummary>>.error(e, s),
    data: (evs) => bills.when(
      loading: () => const AsyncValue<List<EventSummary>>.loading(),
      error: (e, s) => AsyncValue<List<EventSummary>>.error(e, s),
      data: (bs) => AsyncValue<List<EventSummary>>.data([
        for (final ev in evs)
          () {
            final active = bs.where((b) => b.eventId == ev.id && b.isActive);
            return EventSummary(ev, active.length,
                active.fold<int>(0, (sum, b) => sum + b.amount));
          }(),
      ]),
    ),
  );
});
