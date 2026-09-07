/// User domain entity representing an authenticated user in Gau-Prahari.
class User {
  final String id;
  final String name;
  final String identifier; // Email or Staff/Farmer ID
  final String role; // 'Dairy Farmer', 'Field Veterinarian', 'System Admin'

  const User({
    required this.id,
    required this.name,
    required this.identifier,
    required this.role,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          identifier == other.identifier;

  @override
  int get hashCode => id.hashCode ^ identifier.hashCode;
}
