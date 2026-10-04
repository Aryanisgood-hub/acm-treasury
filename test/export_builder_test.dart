import 'package:club_finance/core/utils/export_builder.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

Rec bill(String id, int amount, {String status = 'active'}) => {
      'id': id,
      'event_id': 'e1',
      'amount': amount,
      'reason': 'Printing',
      'bill_date': '2026-09-28',
      'status': status,
      'added_by_name': 'Treasurer One',
      'added_by_email': 't1@example.com',
      'created_at': '2026-09-28T10:00:00Z',
    };

void main() {
  final events = [
    {'id': 'e1', 'name': 'Tech Fest', 'created_at': '2026-09-01T10:00:00Z'},
  ];

  test('full backup has every sheet and one row per bill', () {
    final bytes = buildFullBackup(
      bills: [bill('a', 100000), bill('b', 50000, status: 'voided')],
      events: events,
      requests: [],
      history: [],
      members: [],
      budgetPaise: 5000000,
    );
    final book = Excel.decodeBytes(bytes);
    expect(
      book.tables.keys,
      containsAll([
        'Summary',
        'Bills',
        'Events',
        'Budget requests',
        'Bill history',
        'Members',
      ]),
    );
    expect(book.tables['Bills']!.maxRows, 3); // header + 2 bills
  });

  test('event and monthly reports are created', () {
    final eventBytes = buildEventReport(
        eventName: 'Tech Fest', bills: [bill('a', 100000)]);
    expect(Excel.decodeBytes(eventBytes).tables.keys, contains('Event report'));

    final monthBytes = buildMonthlyReport(
      monthLabel: 'September 2026',
      bills: [bill('a', 100000)],
      eventNames: {'e1': 'Tech Fest'},
    );
    expect(
        Excel.decodeBytes(monthBytes).tables.keys, contains('Monthly report'));
  });
}
