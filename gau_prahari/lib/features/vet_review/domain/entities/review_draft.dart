/// Domain entity representing a locally saved review request draft.
class ReviewDraft {
  final String id;
  final String farmerUid;
  final String cowId;
  final String cowTagNumber;
  final String predictionLabel;
  final String riskLevel;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReviewDraft({
    required this.id,
    required this.farmerUid,
    required this.cowId,
    required this.cowTagNumber,
    required this.predictionLabel,
    required this.riskLevel,
    required this.snapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmerUid': farmerUid,
      'cowId': cowId,
      'cowTagNumber': cowTagNumber,
      'predictionLabel': predictionLabel,
      'riskLevel': riskLevel,
      'snapshot': snapshot,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReviewDraft.fromJson(Map<String, dynamic> json) {
    return ReviewDraft(
      id: json['id'] as String,
      farmerUid: json['farmerUid'] as String,
      cowId: json['cowId'] as String,
      cowTagNumber: json['cowTagNumber'] as String? ?? json['cowId'] as String,
      predictionLabel: json['predictionLabel'] as String? ?? 'Analysis Result',
      riskLevel: json['riskLevel'] as String? ?? 'LOW',
      snapshot: Map<String, dynamic>.from(json['snapshot'] as Map? ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
