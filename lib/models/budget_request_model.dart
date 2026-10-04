class BudgetRequest {
  const BudgetRequest({
    required this.id,
    required this.requestedByName,
    required this.currentBudget,
    required this.requestedBudget,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reviewedByName,
    this.reviewedAt,
  });

  final String id;
  final String requestedByName;
  final int currentBudget; // paise, snapshot at request time
  final int requestedBudget; // paise
  final String reason;
  final String status; // pending | approved | rejected
  final DateTime createdAt;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  int get change => requestedBudget - currentBudget;

  factory BudgetRequest.fromMap(Map<String, dynamic> m) => BudgetRequest(
        id: m['id'] as String,
        requestedByName: m['requested_by_name'] as String,
        currentBudget: (m['current_budget'] as num).toInt(),
        requestedBudget: (m['requested_budget'] as num).toInt(),
        reason: m['reason'] as String,
        status: m['status'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        reviewedByName: m['reviewed_by_name'] as String?,
        reviewedAt: m['reviewed_at'] == null
            ? null
            : DateTime.parse(m['reviewed_at'] as String).toLocal(),
      );
}
