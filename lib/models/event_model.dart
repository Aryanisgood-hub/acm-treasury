class EventModel {
  const EventModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  factory EventModel.fromMap(Map<String, dynamic> m) => EventModel(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

/// Per-event totals computed from ACTIVE bills only.
class EventSummary {
  const EventSummary(this.event, this.billCount, this.totalSpent);
  final EventModel event;
  final int billCount;
  final int totalSpent; // paise
}
