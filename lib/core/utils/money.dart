import 'package:intl/intl.dart';

/// All money is stored as integer paise. Convert only at the UI edge.
class Money {
  static final _whole = NumberFormat.currency(
      locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _fraction = NumberFormat.currency(
      locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static String format(int paise) {
    final rupees = paise / 100;
    return paise % 100 == 0 ? _whole.format(rupees) : _fraction.format(rupees);
  }

  /// Plain number for text fields: 125000 -> "1250", 125050 -> "1250.50".
  static String toInputString(int paise) =>
      paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);

  /// "1,250" or "1250.50" -> paise. Returns null if invalid or not > 0.
  static int? parseToPaise(String input) {
    final s = input.trim().replaceAll(',', '');
    final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(s);
    if (m == null) return null;
    final rupees = int.parse(m.group(1)!);
    final frac = (m.group(2) ?? '').padRight(2, '0');
    final paise = rupees * 100 + int.parse(frac.isEmpty ? '0' : frac);
    return paise > 0 ? paise : null;
  }
}
