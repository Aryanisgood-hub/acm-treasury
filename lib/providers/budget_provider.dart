import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget_request_model.dart';
import '../repositories/budget_repository.dart';
import 'auth_provider.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
    (ref) => BudgetRepository(Supabase.instance.client));

final totalBudgetProvider = StreamProvider<int>((ref) {
  ref.watch(userIdProvider); // resubscribe when the signed-in user changes
  return ref.watch(budgetRepositoryProvider).watchTotalBudget();
});

final budgetRequestsProvider = StreamProvider<List<BudgetRequest>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(budgetRepositoryProvider).watchRequests();
});
