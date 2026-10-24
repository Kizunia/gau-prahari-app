/// Domain entity representing a registered veterinarian available for case reviews.
class VetProfile {
  final String uid;
  final String name;
  final String email;
  final String? designation;

  const VetProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.designation,
  });

  factory VetProfile.fromFirestore(Map<String, dynamic> data, String id) {
    return VetProfile(
      uid: id,
      name: data['name'] as String? ?? 'Veterinarian',
      email: data['email'] as String? ?? '',
      designation: data['designation'] as String? ?? 'Field Veterinary Officer',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'designation': designation,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VetProfile && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
