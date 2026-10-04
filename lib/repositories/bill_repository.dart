import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill_model.dart';

class BillRepository {
  BillRepository(this._client);
  final SupabaseClient _client;

  static const _bucket = 'receipts';

  Stream<List<Bill>> watchBills() => _client
      .from('bills')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Bill.fromMap).toList());

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String contentTypeFor(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Uploads to receipts/{eventId}/{billId}/{timestamp}_{name}; returns the path.
  /// Old receipts are never deleted (audit trail).
  Future<String> uploadReceipt({
    required String eventId,
    required String billId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$eventId/$billId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentTypeFor(fileName)),
        );
    return path;
  }

  /// Short-lived link; receipts bucket is private.
  Future<String> receiptUrl(String path) =>
      _client.storage.from(_bucket).createSignedUrl(path, 300);

  /// added_by / timestamps are set by database triggers, not by the client.
  Future<void> addBill({
    required String id,
    required String eventId,
    required int amount,
    required String reason,
    required DateTime date,
    required String receiptPath,
    required String receiptType,
  }) async {
    await _client.from('bills').insert({
      'id': id,
      'event_id': eventId,
      'amount': amount,
      'reason': reason.trim(),
      'bill_date': _dateOnly(date),
      'receipt_path': receiptPath,
      'receipt_type': receiptType,
    });
  }

  Future<void> updateBill({
    required String id,
    required String eventId,
    required int amount,
    required String reason,
    required DateTime date,
    String? receiptPath,
    String? receiptType,
  }) async {
    final rows = await _client
        .from('bills')
        .update({
          'event_id': eventId,
          'amount': amount,
          'reason': reason.trim(),
          'bill_date': _dateOnly(date),
         'receipt_path': ?receiptPath,
         'receipt_type': ?receiptType,
        })
        .eq('id', id)
        .select();
    _requireRows(rows);
  }

  Future<void> voidBill(String id, String reason) async {
    final rows = await _client
        .from('bills')
        .update({'status': 'voided', 'void_reason': reason.trim()})
        .eq('id', id)
        .select();
    _requireRows(rows);
  }

  // RLS silently filters blocked updates to zero rows; surface that as an error.
  void _requireRows(List<dynamic> rows) {
    if (rows.isEmpty) {
      throw const PostgrestException(
          message: 'No rows updated', code: '42501');
    }
  }
}
