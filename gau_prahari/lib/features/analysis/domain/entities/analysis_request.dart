import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';

/// Request payload sent from the mobile application to FastAPI for ML inference.
class AnalysisRequest {
  final String cowId;
  final List<CollarTelemetry> collarData;
  final MilkMeasurement milkData;

  const AnalysisRequest({
    required this.cowId,
    required this.collarData,
    required this.milkData,
  });

  Map<String, dynamic> toJson() {
    return {
      'cow_id': cowId,
      'collar_data': collarData.map((e) => e.toJson()).toList(),
      'milk_data': {
        'milk_temperature': milkData.milkTemperature,
        'ph': milkData.ph,
        'conductivity': milkData.conductivity,
        'scc': milkData.scc,
        'fat': milkData.fat,
        'snf': milkData.snf,
      },
    };
  }

  factory AnalysisRequest.fromJson(Map<String, dynamic> json) {
    final rawCollar = json['collar_data'] as List<dynamic>? ?? [];
    return AnalysisRequest(
      cowId: json['cow_id'] as String,
      collarData: rawCollar
          .map((c) => CollarTelemetry.fromJson(c as Map<String, dynamic>))
          .toList(),
      milkData: MilkMeasurement.fromJson({
        'cow_id': json['cow_id'],
        ...Map<String, dynamic>.from(json['milk_data'] as Map),
      }),
    );
  }
}
