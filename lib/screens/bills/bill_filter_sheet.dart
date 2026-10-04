import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../models/bill_filter.dart';
import '../../models/event_model.dart';

/// Returns the new filter, or null if dismissed without applying.
Future<BillFilter?> showBillFilterSheet(
  BuildContext context, {
  required BillFilter current,
  required List<EventModel> events,
  required List<MapEntry<String, String>> people, // id -> name
}) {
  return showModalBottomSheet<BillFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _FilterSheet(current: current, events: events, people: people),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(
      {required this.current, required this.events, required this.people});
  final BillFilter current;
  final List<EventModel> events;
  final List<MapEntry<String, String>> people;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _eventId;
  String? _personId;
  late StatusFilter _status;
  DateTime? _from;
  DateTime? _to;
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final f = widget.current;
    _eventId = f.eventId;
    _personId = f.addedById;
    _status = f.status;
    _from = f.from;
    _to = f.to;
    _min = TextEditingController(
        text: f.minPaise == null ? '' : Money.toInputString(f.minPaise!));
    _max = TextEditingController(
        text: f.maxPaise == null ? '' : Money.toInputString(f.maxPaise!));
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange:
          _from != null && _to != null ? DateTimeRange(start: _from!, end: _to!) : null,
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  void _apply() {
    var min = Money.parseToPaise(_min.text);
    var max = Money.parseToPaise(_max.text);
    if (min != null && max != null && min > max) {
      final t = min;
      min = max;
      max = t;
    }
    Navigator.pop(
      context,
      BillFilter(
        eventId: _eventId,
        addedById: _personId,
        status: _status,
        from: _from,
        to: _to,
        minPaise: min,
        maxPaise: max,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter bills',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _eventId,
              decoration: const InputDecoration(labelText: 'Event'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All events')),
                for (final e in widget.events)
                  DropdownMenuItem<String?>(value: e.id, child: Text(e.name)),
              ],
              onChanged: (v) => setState(() => _eventId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _personId,
              decoration: const InputDecoration(labelText: 'Added by'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Anyone')),
                for (final p in widget.people)
                  DropdownMenuItem<String?>(value: p.key, child: Text(p.value)),
              ],
              onChanged: (v) => setState(() => _personId = v),
            ),
            const SizedBox(height: 16),
            const Text('Status'),
            const SizedBox(height: 8),
            SegmentedButton<StatusFilter>(
              segments: const [
                ButtonSegment(value: StatusFilter.all, label: Text('All')),
                ButtonSegment(value: StatusFilter.active, label: Text('Active')),
                ButtonSegment(value: StatusFilter.voided, label: Text('Voided')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(_from == null || _to == null
                  ? 'Any date'
                  : '${fmtDate(_from!)} – ${fmtDate(_to!)}'),
              onPressed: _pickRange,
            ),
            if (_from != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                    child: const Text('Clear dates')),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Min amount', prefixText: '₹ '),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _max,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Max amount', prefixText: '₹ '),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, const BillFilter()),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                    onPressed: _apply, child: const Text('Apply')),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
