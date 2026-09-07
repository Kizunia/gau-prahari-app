/// Domain entity representing a dairy cow in the Gau-Prahari system.
class Cow {
  final String id; // Unique ID, e.g., COW-104
  final String tagNumber; // RFID / Ear tag
  final String breed; // e.g., Gir, Sahiwal, Murrah
  final int ageYears;
  final String lactationStage; // e.g., Early Lactation (Day 42)
  final String status; // 'Ready for Test', 'Testing', 'At Risk', etc.

  const Cow({
    required this.id,
    required this.tagNumber,
    required this.breed,
    required this.ageYears,
    required this.lactationStage,
    this.status = 'Ready for Test',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag_number': tagNumber,
      'breed': breed,
      'age_years': ageYears,
      'lactation_stage': lactationStage,
      'status': status,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cow && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
