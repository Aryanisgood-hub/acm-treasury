class Bill {
  const Bill({
    required this.id,
    required this.eventId,
    required this.amount,
    required this.reason,
    required this.billDate,
    this.receiptPath,
    required this.status,
    required this.addedBy,
    required this.addedByName,
    required this.addedByEmail,
    required this.createdAt,
    this.lastModifiedByName,
    this.lastModifiedAt,
    this.voidedByName,
    this.voidedAt,
    this.voidReason,
  });

  final String id;
  final String eventId;
  final int amount; // paise
  final String reason;
  final DateTime billDate;
  final String? receiptPath;
  final String status; // 'active' | 'voided'
  final String addedBy;
  final String addedByName;
  final String addedByEmail;
  final DateTime createdAt;
  final String? lastModifiedByName;
  final DateTime? lastModifiedAt;
  final String? voidedByName;
  final DateTime? voidedAt;
  final String? voidReason;

  bool get isVoided => status == 'voided';
  bool get isActive => !isVoided;

  static DateTime? _ts(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory Bill.fromMap(Map<String, dynamic> m) => Bill(
        id: m['id'] as String,
        eventId: m['event_id'] as String,
        amount: (m['amount'] as num).toInt(),
        reason: m['reason'] as String,
        billDate: DateTime.parse(m['bill_date'] as String),
        receiptPath: m['receipt_path'] as String?,
        status: m['status'] as String,
        addedBy: m['added_by'] as String,
        addedByName: m['added_by_name'] as String,
        addedByEmail: m['added_by_email'] as String,
        createdAt: _ts(m['created_at'])!,
        lastModifiedByName: m['last_modified_by_name'] as String?,
        lastModifiedAt: _ts(m['last_modified_at']),
        voidedByName: m['voided_by_name'] as String?,
        voidedAt: _ts(m['voided_at']),
        voidReason: m['void_reason'] as String?,
      );
}
