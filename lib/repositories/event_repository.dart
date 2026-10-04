import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_model.dart';

class EventRepository {
  EventRepository(this._client);
  final SupabaseClient _client;

  Stream<List<EventModel>> watchEvents() => _client
      .from('events')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(EventModel.fromMap).toList());

  Future<void> createEvent({required String name, String? description}) async {
    final desc = description?.trim() ?? '';
    await _client.from('events').insert({
      'name': name.trim(),
      if (desc.isNotEmpty) 'description': desc,
    });
  }
}
