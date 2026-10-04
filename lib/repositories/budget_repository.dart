import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget_request_model.dart';

class BudgetRepository {
  BudgetRepository(this._client);
  final SupabaseClient _client;

  /// The official budget in paise. Only changes via President-approved requests.
  Stream<int> watchTotalBudget() =>
      _client.from('settings').stream(primaryKey: ['id']).map((rows) =>
          rows.isEmpty ? 0 : (rows.first['total_budget'] as num).toInt());

  Stream<List<BudgetRequest>> watchRequests() => _client
      .from('budget_requests')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(BudgetRequest.fromMap).toList());

  /// requested_by, current_budget, status and timestamps are set by a database
  /// trigger; the database also rejects budgets below total spent.
  Future<void> createRequest({
    required int requestedBudget,
    required String reason,
  }) async {
    await _client.from('budget_requests').insert({
      'requested_budget': requestedBudget,
      'reason': reason.trim(),
    });
  }

  /// The ONLY way the budget changes. The database function checks that the
  /// caller is the President and updates the budget atomically.
  Future<void> reviewRequest(String id, {required bool approve}) async {
    await _client.rpc('review_budget_request',
        params: {'p_id': id, 'p_approve': approve});
  }
}
