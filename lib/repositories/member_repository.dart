import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member_model.dart';

class MemberRepository {
  MemberRepository(this._client);
  final SupabaseClient _client;

  /// RLS only returns the row for ACTIVE members, so inactive or unknown
  /// accounts get null here and are shown the "no access" screen.
  Future<Member?> fetchMember(String userId) async {
    final row = await _client
        .from('members')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Member.fromMap(row);
  }
}
