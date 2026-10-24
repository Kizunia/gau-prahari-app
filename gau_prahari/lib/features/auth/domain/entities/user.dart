/// User domain entity representing an authenticated user in Gau-Prahari.
class User {
  final String id;
  final String name;
  final String identifier; // Email or Staff/Farmer ID
  final String role; // 'farmer', 'veterinarian', or legacy display strings
  final bool isDemo;

  const User({
    required this.id,
    required this.name,
    required this.identifier,
    required this.role,
    this.isDemo = false,
  });

  /// Convenience display name
  String get displayName => name.trim().isNotEmpty ? name : identifier;

  /// True if the user has the Farmer role.
  bool get isFarmer {
    final lower = role.toLowerCase();
    return lower == 'farmer' || lower.contains('farmer') || lower.contains('supervisor') || lower.contains('dairy');
  }

  /// True if the user has the Veterinarian role.
  bool get isVeterinarian {
    final lower = role.toLowerCase();
    return lower == 'veterinarian' || lower.contains('vet');
  }

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
