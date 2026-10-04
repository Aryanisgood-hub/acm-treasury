import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'formatters.dart';

/// A raw database row (snake_case column names).
typedef Rec = Map<String, dynamic>;

String _s(dynamic v) => v == null ? '' : v.toString();
double _rs(dynamic paise) => ((paise as num?) ?? 0) / 100;
String _dt(dynamic iso) =>
    iso == null ? '' : fmtDateTime(DateTime.parse(iso as String).toLocal());
String _d(dynamic iso) =>
    iso == null ? '' : fmtDate(DateTime.parse(iso as String));
bool _isActive(Rec b) => b['status'] == 'active';
int _sumActive(Iterable<Rec> bills) => bills
    .where(_isActive)
    .fold<int>(0, (sum, b) => sum + (b['amount'] as num).toInt());

CellValue _t(dynamic v) => TextCellValue(_s(v));
CellValue _m(dynamic paise) => DoubleCellValue(_rs(paise));
CellValue _i(int v) => IntCellValue(v);

List<Rec> _sorted(List<Rec> bills) => [...bills]
  ..sort((a, b) {
    final byDate = _s(a['bill_date']).compareTo(_s(b['bill_date']));
    return byDate != 0
        ? byDate
        : _s(a['created_at']).compareTo(_s(b['created_at']));
  });

/// Appends rows to a sheet and remembers the current row for bold styling.
class _Page {
  _Page(this.sheet);
  final Sheet sheet;
  int _row = 0;

  void add(List<CellValue?> cells, {bool bold = false}) {
    sheet.appendRow(cells);
    if (bold) {
      final style = CellStyle(bold: true);
      for (var c = 0; c < cells.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: _row))
            .cellStyle = style;
      }
    }
    _row++;
  }

  void blank() => add([TextCellValue('')]);

  void widths(List<double> w) {
    for (var i = 0; i < w.length; i++) {
      sheet.setColumnWidth(i, w[i]);
    }
  }
}

Uint8List _encode(Excel excel) {
  final bytes = excel.encode();
  if (bytes == null) throw StateError('Could not create the spreadsheet');
  return Uint8List.fromList(bytes);
}

Excel _newBook(String firstSheet) {
  final excel = Excel.createExcel();
  final first = excel.getDefaultSheet();
  if (first != null) excel.rename(first, firstSheet);
  return excel;
}

/// Everything in one workbook: summary, bills, events, requests, history, members.
Uint8List buildFullBackup({
  required List<Rec> bills,
  required List<Rec> events,
  required List<Rec> requests,
  required List<Rec> history,
  required List<Rec> members,
  required int budgetPaise,
}) {
  final excel = _newBook('Summary');
  final eventName = {for (final e in events) _s(e['id']): _s(e['name'])};
  final spent = _sumActive(bills);

  final sum = _Page(excel['Summary']);
  sum.widths([32, 22, 20]);
  sum.add([_t('ACM Treasury - full backup')], bold: true);
  sum.add([_t('Generated'), _t(fmtDateTime(DateTime.now()))]);
  sum.blank();
  sum.add([_t('Official budget (Rs)'), _m(budgetPaise)]);
  sum.add([_t('Total spent (Rs)'), _m(spent)]);
  sum.add([_t('Remaining (Rs)'), _m(budgetPaise - spent)]);
  sum.add([_t('Active bills'), _i(bills.where(_isActive).length)]);
  sum.add([_t('Voided bills'), _i(bills.where((b) => !_isActive(b)).length)]);
  sum.blank();
  sum.add([_t('Spending by event')], bold: true);
  sum.add([_t('Event'), _t('Bills'), _t('Total spent (Rs)')], bold: true);
  final sortedEvents = [...events]..sort((a, b) =>
      _s(a['name']).toLowerCase().compareTo(_s(b['name']).toLowerCase()));
  for (final e in sortedEvents) {
    final mine = bills.where((b) => b['event_id'] == e['id']).toList();
    sum.add([
      _t(e['name']),
      _i(mine.where(_isActive).length),
      _m(_sumActive(mine)),
    ]);
  }

  final bs = _Page(excel['Bills']);
  bs.widths([38, 24, 12, 34, 14, 10, 20, 28, 20, 20, 20, 20, 20, 28, 48]);
  bs.add([
    _t('Bill ID'), _t('Event'), _t('Date'), _t('Reason'), _t('Amount (Rs)'),
    _t('Status'), _t('Added by'), _t('Added by email'), _t('Created at'),
    _t('Last modified by'), _t('Last modified at'), _t('Voided by'),
    _t('Voided at'), _t('Void reason'), _t('Receipt file (in Supabase Storage)'),
  ], bold: true);
  for (final b in bills) {
    bs.add([
      _t(b['id']),
      _t(eventName[_s(b['event_id'])] ?? ''),
      _t(_d(b['bill_date'])),
      _t(b['reason']),
      _m(b['amount']),
      _t(b['status']),
      _t(b['added_by_name']),
      _t(b['added_by_email']),
      _t(_dt(b['created_at'])),
      _t(b['last_modified_by_name']),
      _t(_dt(b['last_modified_at'])),
      _t(b['voided_by_name']),
      _t(_dt(b['voided_at'])),
      _t(b['void_reason']),
      _t(b['receipt_path']),
    ]);
  }

  final ev = _Page(excel['Events']);
  ev.widths([38, 30, 40, 20]);
  ev.add([_t('Event ID'), _t('Name'), _t('Description'), _t('Created at')],
      bold: true);
  for (final e in events) {
    ev.add([
      _t(e['id']), _t(e['name']), _t(e['description']), _t(_dt(e['created_at'])),
    ]);
  }

  final rq = _Page(excel['Budget requests']);
  rq.widths([22, 18, 18, 16, 40, 12, 20, 22, 20]);
  rq.add([
    _t('Requested by'), _t('Budget then (Rs)'), _t('Requested (Rs)'),
    _t('Change (Rs)'), _t('Reason'), _t('Status'), _t('Requested at'),
    _t('Reviewed by'), _t('Reviewed at'),
  ], bold: true);
  for (final r in requests) {
    rq.add([
      _t(r['requested_by_name']),
      _m(r['current_budget']),
      _m(r['requested_budget']),
      DoubleCellValue(_rs(r['requested_budget']) - _rs(r['current_budget'])),
      _t(r['reason']),
      _t(r['status']),
      _t(_dt(r['created_at'])),
      _t(r['reviewed_by_name']),
      _t(_dt(r['reviewed_at'])),
    ]);
  }

  final hs = _Page(excel['Bill history']);
  hs.widths([38, 12, 22, 20, 18, 18, 34, 12]);
  hs.add([
    _t('Bill ID'), _t('Action'), _t('By'), _t('At'), _t('Amount before (Rs)'),
    _t('Amount after (Rs)'), _t('Reason after'), _t('Status after'),
  ], bold: true);
  for (final h in history) {
    final before = h['before'] is Map ? h['before'] as Map : null;
    final after = h['after'] is Map ? h['after'] as Map : null;
    hs.add([
      _t(h['bill_id']),
      _t(h['action']),
      _t(h['actor_name']),
      _t(_dt(h['at'])),
      before == null ? _t('') : _m(before['amount']),
      after == null ? _t('') : _m(after['amount']),
      _t(after?['reason']),
      _t(after?['status']),
    ]);
  }

  final mb = _Page(excel['Members']);
  mb.widths([24, 32, 20, 10]);
  mb.add([_t('Name'), _t('Email'), _t('Role'), _t('Active')], bold: true);
  for (final m in members) {
    mb.add([
      _t(m['name']), _t(m['email']), _t(m['role']),
      _t(m['active'] == true ? 'yes' : 'no'),
    ]);
  }

  return _encode(excel);
}

/// One event: its bills and an EVENT TOTAL (active bills only).
Uint8List buildEventReport({
  required String eventName,
  required List<Rec> bills,
}) {
  final excel = _newBook('Event report');
  final p = _Page(excel['Event report']);
  p.widths([14, 40, 16, 22, 10, 30]);
  p.add([_t('Event: $eventName')], bold: true);
  p.add([_t('Generated'), _t(fmtDateTime(DateTime.now()))]);
  p.add([_t('Total bills (active)'), _i(bills.where(_isActive).length)]);
  p.add([_t('Total spent (Rs)'), _m(_sumActive(bills))]);
  p.blank();
  p.add([
    _t('Date'), _t('Reason'), _t('Amount (Rs)'), _t('Added by'), _t('Status'),
    _t('Void reason'),
  ], bold: true);
  for (final b in _sorted(bills)) {
    p.add([
      _t(_d(b['bill_date'])),
      _t(b['reason']),
      _m(b['amount']),
      _t(b['added_by_name']),
      _t(b['status']),
      _t(b['void_reason']),
    ]);
  }
  p.blank();
  p.add([
    _t('EVENT TOTAL (active bills only)'),
    _t(''),
    _m(_sumActive(bills)),
  ], bold: true);
  return _encode(excel);
}

/// One calendar month across all events.
Uint8List buildMonthlyReport({
  required String monthLabel,
  required List<Rec> bills,
  required Map<String, String> eventNames,
}) {
  final excel = _newBook('Monthly report');
  final p = _Page(excel['Monthly report']);
  p.widths([14, 28, 40, 16, 22, 10]);
  p.add([_t('Monthly report: $monthLabel')], bold: true);
  p.add([_t('Generated'), _t(fmtDateTime(DateTime.now()))]);
  p.add([_t('Total bills (active)'), _i(bills.where(_isActive).length)]);
  p.add([_t('Total spent (Rs)'), _m(_sumActive(bills))]);
  p.blank();

  p.add([_t('By event')], bold: true);
  p.add([_t('Event'), _t('Bills'), _t('Total spent (Rs)')], bold: true);
  final ids = bills.map((b) => _s(b['event_id'])).toSet().toList()
    ..sort((a, b) => (eventNames[a] ?? '')
        .toLowerCase()
        .compareTo((eventNames[b] ?? '').toLowerCase()));
  for (final id in ids) {
    final mine = bills.where((b) => _s(b['event_id']) == id).toList();
    p.add([
      _t(eventNames[id] ?? ''),
      _i(mine.where(_isActive).length),
      _m(_sumActive(mine)),
    ]);
  }
  p.blank();

  p.add([
    _t('Date'), _t('Event'), _t('Reason'), _t('Amount (Rs)'), _t('Added by'),
    _t('Status'),
  ], bold: true);
  for (final b in _sorted(bills)) {
    p.add([
      _t(_d(b['bill_date'])),
      _t(eventNames[_s(b['event_id'])] ?? ''),
      _t(b['reason']),
      _m(b['amount']),
      _t(b['added_by_name']),
      _t(b['status']),
    ]);
  }
  p.blank();
  p.add([
    _t('MONTH TOTAL (active bills only)'),
    _t(''),
    _t(''),
    _m(_sumActive(bills)),
  ], bold: true);
  return _encode(excel);
}
