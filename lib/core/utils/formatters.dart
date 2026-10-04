import 'package:intl/intl.dart';

final _date = DateFormat('dd/MM/yyyy');
final _dateTime = DateFormat('dd/MM/yyyy, hh:mm a');

String fmtDate(DateTime d) => _date.format(d);
String fmtDateTime(DateTime d) => _dateTime.format(d);
