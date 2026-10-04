import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/export_builder.dart';

/// Reads data straight from the database (not the live streams) so a backup
/// is complete, then builds an Excel workbook from it.
class ExportService {
  ExportService(this._client);
  final SupabaseClient _client;

  /// Supabase returns at most 1000 rows per request, so page through.
  Future<List<Rec>> _all(String table, {String orderBy = 'created_at'}) async {
    final out = <Rec>[];
    var from = 0;
    const page = 1000;
    while (true) {
      final rows = await _client
          .from(table)
          .select()
          .order(orderBy)
          .order('id')
          .range(from, from + page - 1);
      out.addAll(rows);
      if (rows.length < page) break;
      from += page;
    }
    return out;
  }

  Future<Uint8List> fullBackup() async {
    final bills = await _all('bills');
    final events = await _all('events');
    final requests = await _all('budget_requests');
    final history = await _all('bill_history', orderBy: 'id');
    final members = await _all('members');
    final settings =
        await _client.from('settings').select('total_budget').maybeSingle();
    final budget = (settings?['total_budget'] as num?)?.toInt() ?? 0;
    return buildFullBackup(
      bills: bills,
      events: events,
      requests: requests,
      history: history,
      members: members,
      budgetPaise: budget,
    );
  }

  Future<Uint8List> eventReport(String eventId, String eventName) async {
    final bills = await _all('bills');
    return buildEventReport(
      eventName: eventName,
      bills: bills.where((b) => b['event_id'] == eventId).toList(),
    );
  }

  Future<Uint8List> monthlyReport(DateTime month) async {
    final bills = await _all('bills');
    final events = await _all('events');
    final inMonth = bills.where((b) {
      final d = DateTime.parse(b['bill_date'] as String);
      return d.year == month.year && d.month == month.month;
    }).toList();
    return buildMonthlyReport(
      monthLabel: DateFormat('MMMM yyyy').format(month),
      bills: inMonth,
      eventNames: {
        for (final e in events) e['id'] as String: e['name'] as String,
      },
    );
  }
}
