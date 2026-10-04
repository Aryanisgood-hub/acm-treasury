import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill_model.dart';
import '../repositories/bill_repository.dart';
import 'auth_provider.dart';

final billRepositoryProvider =
    Provider<BillRepository>((ref) => BillRepository(Supabase.instance.client));

/// Live list of all bills (active first, then newest bill date).
final billsProvider = StreamProvider<List<Bill>>((ref) {
  ref.watch(userIdProvider); // resubscribe when the signed-in user changes
  final stream = ref.watch(billRepositoryProvider).watchBills();
  return stream.map((list) => [...list]..sort(_compareBills));
});

int _compareBills(Bill a, Bill b) {
  if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
  final byDate = b.billDate.compareTo(a.billDate);
  return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
}
