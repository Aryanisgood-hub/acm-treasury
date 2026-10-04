import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member_model.dart';
import '../repositories/member_repository.dart';
import '../services/auth_service.dart';

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(Supabase.instance.client));

final memberRepositoryProvider = Provider<MemberRepository>(
    (ref) => MemberRepository(Supabase.instance.client));

/// Emits the signed-in user id (or null). Token refreshes keep the same id,
/// so they do not trigger a reload of the member profile.
final userIdProvider = StreamProvider<String?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange.map((s) => s.session?.user.id).distinct();
});

/// The signed-in user's club membership (name + role), or null if none.
final currentMemberProvider = FutureProvider<Member?>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  if (uid == null) return null;
  return ref.watch(memberRepositoryProvider).fetchMember(uid);
});
