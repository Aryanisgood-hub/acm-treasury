import '../core/utils/money.dart';
import 'bill_model.dart';

enum StatusFilter { all, active, voided }

class BillFilter {
  const BillFilter({
    this.eventId,
    this.addedById,
    this.status = StatusFilter.all,
    this.from,
    this.to,
    this.minPaise,
    this.maxPaise,
  });

  final String? eventId;
  final String? addedById;
  final StatusFilter status;
  final DateTime? from;
  final DateTime? to;
  final int? minPaise;
  final int? maxPaise;

  int get activeCount => [
        eventId != null,
        addedById != null,
        status != StatusFilter.all,
        from != null || to != null,
        minPaise != null || maxPaise != null,
      ].where((x) => x).length;

  bool get isEmpty => activeCount == 0;

  /// [query] matches reason, event name, added-by name or the amount text.
  List<Bill> apply(
      List<Bill> bills, Map<String, String> eventNames, String query) {
    final q = query.trim().toLowerCase();
    return bills.where((b) {
      if (eventId != null && b.eventId != eventId) return false;
      if (addedById != null && b.addedBy != addedById) return false;
      if (status == StatusFilter.active && !b.isActive) return false;
      if (status == StatusFilter.voided && !b.isVoided) return false;
      if (from != null && b.billDate.isBefore(from!)) return false;
      if (to != null && b.billDate.isAfter(to!)) return false;
      if (minPaise != null && b.amount < minPaise!) return false;
      if (maxPaise != null && b.amount > maxPaise!) return false;
      if (q.isNotEmpty) {
        final haystack = [
          b.reason,
          b.addedByName,
          eventNames[b.eventId] ?? '',
          Money.toInputString(b.amount),
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }
}
