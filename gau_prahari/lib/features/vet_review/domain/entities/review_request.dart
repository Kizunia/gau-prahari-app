import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../analysis/domain/entities/analysis_result.dart';
import '../../../milk_tester/domain/entities/milk_measurement.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import 'review_status.dart';

/// Domain entity representing a clinical review request submitted by a farmer to a veterinarian.
class ReviewRequest {
  final String id;
  final String farmerUid;
  final String farmerNameSnapshot;
  final String veterinarianUid;
  final String veterinarianNameSnapshot;
  final String cowId;
  final String cowTagNumber;
  final String predictionLabel;
  final String riskLevel;
  final ReviewStatus status;
  final int snapshotVersion;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;

  const ReviewRequest({
    required this.id,
    required this.farmerUid,
    required this.farmerNameSnapshot,
    required this.veterinarianUid,
    required this.veterinarianNameSnapshot,
    required this.cowId,
    required this.cowTagNumber,
    required this.predictionLabel,
    required this.riskLevel,
    required this.status,
    this.snapshotVersion = 1,
    required this.snapshot,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
  });

  /// Factory helper to build an immutable snapshot according to SRS Section 4.2.
  static Map<String, dynamic> buildSnapshot({
    required Cow cow,
    required AnalysisResult result,
    required MilkMeasurement milkMeasurement,
    CollarHistory? collarHistory,
    List<Map<String, dynamic>>? historicalHealthRecords,
  }) {
    return {
      'cow': {
        'id': cow.id,
        'tag_number': cow.tagNumber,
        'name': cow.name,
        'breed': cow.breed,
        'age_years': cow.ageYears,
        'lactation_stage': cow.lactationStage,
        'status': cow.status,
      },
      'prediction': {
        'cow_id': result.cowId,
        'prediction': result.prediction,
        'probability': result.probability,
        'risk_level': result.riskLevel,
        'factors': result.factors,
        'recommended_action': result.recommendedAction,
        'timestamp': result.timestamp.toIso8601String(),
      },
      'milkMeasurement': {
        'cow_id': milkMeasurement.cowId,
        'milk_temperature': milkMeasurement.milkTemperature,
        'ph': milkMeasurement.ph,
        'conductivity': milkMeasurement.conductivity,
        'scc': milkMeasurement.scc,
        'fat': milkMeasurement.fat,
        'snf': milkMeasurement.snf,
        'timestamp': milkMeasurement.timestamp.toIso8601String(),
      },
      'collarHistory': collarHistory != null
          ? {
              'cow_id': collarHistory.cowId,
              'records': collarHistory.records.map((r) => r.toJson()).toList(),
              'summary': {
                'record_count': collarHistory.recordCount,
                'mean_activity': collarHistory.meanActivity,
                'mean_skin_temp': collarHistory.meanSkinTemperature,
                'mean_ambient_temp': collarHistory.meanAmbientTemperature,
                'mean_humidity': collarHistory.meanHumidity,
                'mean_thi': collarHistory.meanThi,
              },
            }
          : null,
      'historicalHealthRecords': historicalHealthRecords ?? [],
    };
  }

  // Accessors for snapshot data
  Cow? get cowSnapshot {
    final cowMap = snapshot['cow'] as Map<String, dynamic>?;
    if (cowMap == null) return null;
    return Cow(
      id: cowMap['id'] as String? ?? cowId,
      tagNumber: cowMap['tag_number'] as String? ?? cowTagNumber,
      breed: cowMap['breed'] as String? ?? 'Unknown',
      ageYears: (cowMap['age_years'] as num?)?.toInt() ?? 0,
      lactationStage: cowMap['lactation_stage'] as String? ?? '',
      status: cowMap['status'] as String? ?? 'Submitted',
      name: cowMap['name'] as String?,
    );
  }

  AnalysisResult? get predictionSnapshot {
    final pMap = snapshot['prediction'] as Map<String, dynamic>?;
    if (pMap == null) return null;
    return AnalysisResult.fromJson(pMap);
  }

  MilkMeasurement? get milkSnapshot {
    final mMap = snapshot['milkMeasurement'] as Map<String, dynamic>?;
    if (mMap == null) return null;
    return MilkMeasurement.fromJson(mMap);
  }

  CollarHistory? get collarSnapshot {
    final cMap = snapshot['collarHistory'] as Map<String, dynamic>?;
    if (cMap == null) return null;
    return CollarHistory.fromJson(cMap);
  }

  List<dynamic> get historicalRecordsSnapshot {
    return snapshot['historicalHealthRecords'] as List<dynamic>? ?? const [];
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  factory ReviewRequest.fromMap(Map<String, dynamic> data, String id) {
    return ReviewRequest(
      id: id,
      farmerUid: data['farmerUid'] as String? ?? '',
      farmerNameSnapshot: data['farmerNameSnapshot'] as String? ?? '',
      veterinarianUid: data['veterinarianUid'] as String? ?? '',
      veterinarianNameSnapshot: data['veterinarianNameSnapshot'] as String? ?? '',
      cowId: data['cowId'] as String? ?? '',
      cowTagNumber: data['cowTagNumber'] as String? ?? '',
      predictionLabel: data['predictionLabel'] as String? ?? '',
      riskLevel: data['riskLevel'] as String? ?? 'LOW',
      status: ReviewStatus.fromString(data['status'] as String?),
      snapshotVersion: (data['snapshotVersion'] as num?)?.toInt() ?? 1,
      snapshot: Map<String, dynamic>.from(data['snapshot'] as Map? ?? {}),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      lastMessageAt: _parseNullableDate(data['lastMessageAt']),
    );
  }

  Map<String, dynamic> toMap({bool useTimestamps = true}) {
    return {
      'farmerUid': farmerUid,
      'farmerNameSnapshot': farmerNameSnapshot,
      'veterinarianUid': veterinarianUid,
      'veterinarianNameSnapshot': veterinarianNameSnapshot,
      'cowId': cowId,
      'cowTagNumber': cowTagNumber,
      'predictionLabel': predictionLabel,
      'riskLevel': riskLevel,
      'status': status.value,
      'snapshotVersion': snapshotVersion,
      'snapshot': snapshot,
      'createdAt': useTimestamps
          ? Timestamp.fromDate(createdAt)
          : createdAt.toIso8601String(),
      'updatedAt': useTimestamps
          ? Timestamp.fromDate(updatedAt)
          : updatedAt.toIso8601String(),
      'lastMessageAt': lastMessageAt != null
          ? (useTimestamps
              ? Timestamp.fromDate(lastMessageAt!)
              : lastMessageAt!.toIso8601String())
          : null,
    };
  }

  ReviewRequest copyWith({
    String? id,
    String? farmerUid,
    String? farmerNameSnapshot,
    String? veterinarianUid,
    String? veterinarianNameSnapshot,
    String? cowId,
    String? cowTagNumber,
    String? predictionLabel,
    String? riskLevel,
    ReviewStatus? status,
    int? snapshotVersion,
    Map<String, dynamic>? snapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
  }) {
    return ReviewRequest(
      id: id ?? this.id,
      farmerUid: farmerUid ?? this.farmerUid,
      farmerNameSnapshot: farmerNameSnapshot ?? this.farmerNameSnapshot,
      veterinarianUid: veterinarianUid ?? this.veterinarianUid,
      veterinarianNameSnapshot:
          veterinarianNameSnapshot ?? this.veterinarianNameSnapshot,
      cowId: cowId ?? this.cowId,
      cowTagNumber: cowTagNumber ?? this.cowTagNumber,
      predictionLabel: predictionLabel ?? this.predictionLabel,
      riskLevel: riskLevel ?? this.riskLevel,
      status: status ?? this.status,
      snapshotVersion: snapshotVersion ?? this.snapshotVersion,
      snapshot: snapshot ?? this.snapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewRequest &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
