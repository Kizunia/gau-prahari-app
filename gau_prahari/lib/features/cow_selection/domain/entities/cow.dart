/// Domain entity representing a dairy cow in the Gau-Prahari system.
class Cow {
  final String id; // Unique ID, e.g., COW-104
  final String tagNumber; // RFID / Ear tag
  final String breed; // e.g., Gir, Sahiwal, Murrah
  final int ageYears;
  final String lactationStage; // e.g., Early Lactation (Day 42)
  final String status; // 'Ready for Test', 'Testing', 'At Risk', etc.
  final String? name; // Optional farmer-assigned name, e.g., 'Ganga'

  const Cow({
    required this.id,
    required this.tagNumber,
    required this.breed,
    required this.ageYears,
    required this.lactationStage,
    this.status = 'Ready for Test',
    this.name,
  });

  /// Returns a display label: farmer name if set, otherwise the cow ID.
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name! : id;

  /// Returns a copy of this cow with the given fields replaced.
  Cow copyWith({
    String? id,
    String? tagNumber,
    String? breed,
    int? ageYears,
    String? lactationStage,
    String? status,
    String? name,
    bool clearName = false,
  }) {
    return Cow(
      id: id ?? this.id,
      tagNumber: tagNumber ?? this.tagNumber,
      breed: breed ?? this.breed,
      ageYears: ageYears ?? this.ageYears,
      lactationStage: lactationStage ?? this.lactationStage,
      status: status ?? this.status,
      name: clearName ? null : (name ?? this.name),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag_number': tagNumber,
      'breed': breed,
      'age_years': ageYears,
      'lactation_stage': lactationStage,
      'status': status,
      if (name != null) 'name': name,
    };
  }

  factory Cow.fromJson(Map<String, dynamic> json) {
    return Cow(
      id: json['id'] as String,
      tagNumber: json['tag_number'] as String? ?? json['id'] as String,
      breed: json['breed'] as String? ?? 'Indigenous',
      ageYears: (json['age_years'] as num?)?.toInt() ?? 4,
      lactationStage: json['lactation_stage'] as String? ?? 'Lactating',
      status: json['status'] as String? ?? 'Ready for Test',
      name: json['name'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cow && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
