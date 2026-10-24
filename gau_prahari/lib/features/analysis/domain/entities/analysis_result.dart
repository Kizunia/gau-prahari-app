/// Domain entity representing the ML model prediction and mastitis risk assessment.
class AnalysisResult {
  final String cowId;
  final int prediction; // 0 = Healthy/Low Risk, 1 = Mastitis Risk
  final double? probability; // Optional model probability (0.0 to 1.0)
  final String riskLevel; // 'LOW', 'MODERATE', 'HIGH'
  final List<String> factors; // Significant contributing factors if provided
  final String recommendedAction; // Clinical guidance for farmer/vet
  final DateTime timestamp;

  AnalysisResult({
    required this.cowId,
    required this.prediction,
    this.probability,
    required this.riskLevel,
    this.factors = const [],
    required this.recommendedAction,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isHighRisk => riskLevel.toUpperCase() == 'HIGH' || prediction == 1;
  bool get isModerateRisk => riskLevel.toUpperCase() == 'MODERATE';
  bool get isLowRisk => riskLevel.toUpperCase() == 'LOW' && prediction == 0;

  Map<String, dynamic> toJson() {
    return {
      'cow_id': cowId,
      'prediction': prediction,
      'probability': probability,
      'risk_level': riskLevel,
      'factors': factors,
      'recommended_action': recommendedAction,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      cowId: json['cow_id'] as String,
      prediction: (json['prediction'] as num).toInt(),
      probability: (json['probability'] as num?)?.toDouble(),
      riskLevel: json['risk_level'] as String? ?? 'LOW',
      factors:
          (json['factors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      recommendedAction:
          json['recommended_action'] as String? ??
          'Maintain regular monitoring.',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }
}
