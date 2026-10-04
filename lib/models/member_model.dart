import '../core/constants/roles.dart';

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final AppRole role;

  /// Returns null if the row has a role this app version doesn't know.
  static Member? fromMap(Map<String, dynamic> map) {
    final role = AppRole.fromDb(map['role'] as String?);
    if (role == null) return null;
    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: role,
    );
  }
}
