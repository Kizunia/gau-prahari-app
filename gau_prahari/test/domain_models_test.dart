import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_request.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';

void main() {
  group('Phase 1 Domain Models Tests', () {
    test('Cow serialization, deserialization, and equality', () {
      const cow = Cow(
        id: 'COW-104',
        tagNumber: 'RFID-9821',
        breed: 'Gir / Sahiwal Cross',
        ageYears: 4,
        lactationStage: 'Early Lactation',
        status: 'Ready for Test',
      );

      final json = cow.toJson();
      expect(json['id'], 'COW-104');
      expect(json['tag_number'], 'RFID-9821');

      final reconstructed = Cow.fromJson(json);
      expect(reconstructed, cow);
      expect(reconstructed.breed, 'Gir / Sahiwal Cross');
    });

    test('CollarTelemetry & CollarHistory mean calculations and JSON parsing', () {
      final t1 = CollarTelemetry(
        timestamp: DateTime(2026, 9, 1, 8, 0),
        activity: 70.0,
        skinTemperature: 37.0,
        ambientTemperature: 28.0,
        humidity: 60.0,
        thi: 75.0,
      );
      final t2 = CollarTelemetry(
        timestamp: DateTime(2026, 9, 1, 9, 0),
        activity: 80.0,
        skinTemperature: 37.4,
        ambientTemperature: 30.0,
        humidity: 64.0,
        thi: 77.0,
      );

      final history = CollarHistory(
        cowId: 'COW-104',
        records: [t1, t2],
      );

      expect(history.recordCount, 2);
      expect(history.meanActivity, 75.0);
      expect(history.meanSkinTemperature, closeTo(37.2, 0.01));
      expect(history.meanThi, 76.0);

      final json = history.toJson();
      final parsed = CollarHistory.fromJson(json);
      expect(parsed.cowId, 'COW-104');
      expect(parsed.recordCount, 2);
      expect(parsed.records[0].activity, 70.0);
    });

    test('MilkMeasurement validation rules and physiological flags', () {
      // Valid healthy measurement
      final validMeasurement = MilkMeasurement(
        cowId: 'COW-104',
        milkTemperature: 36.5,
        ph: 6.65,
        conductivity: 5.10,
        scc: 140000,
        fat: 4.2,
        snf: 8.8,
      );

      expect(validMeasurement.isValid, true);
      expect(validMeasurement.validationErrors, isEmpty);
      expect(validMeasurement.isSccElevated, false);
      expect(validMeasurement.isConductivityElevated, false);
      expect(validMeasurement.isPhAbnormal, false);

      // Elevated/Subclinical measurement
      final subclinical = MilkMeasurement(
        cowId: 'COW-104',
        milkTemperature: 37.2,
        ph: 6.78,
        conductivity: 6.20,
        scc: 420000,
        fat: 3.8,
        snf: 8.4,
      );
      expect(subclinical.isValid, true);
      expect(subclinical.isSccElevated, true);
      expect(subclinical.isConductivityElevated, true);

      // Out of bounds / invalid measurement
      final invalid = MilkMeasurement(
        cowId: '',
        milkTemperature: 55.0, // boiling!
        ph: 9.5, // dangerous alkali!
        conductivity: 25.0,
        scc: -50,
        fat: -1.0,
        snf: 30.0,
      );
      expect(invalid.isValid, false);
      expect(invalid.validationErrors.length, greaterThanOrEqualTo(5));
    });

    test('AnalysisRequest & AnalysisResult serialization matching data contract', () {
      final telemetry = CollarTelemetry(
        timestamp: DateTime(2026, 9, 1, 8, 0),
        activity: 72.0,
        skinTemperature: 37.1,
        ambientTemperature: 29.2,
        humidity: 61.0,
        thi: 77.3,
      );
      final milk = MilkMeasurement(
        cowId: 'COW-104',
        milkTemperature: 35.8,
        ph: 6.72,
        conductivity: 6.18,
        scc: 420000,
        fat: 4.1,
        snf: 8.6,
      );

      final req = AnalysisRequest(
        cowId: 'COW-104',
        collarData: [telemetry],
        milkData: milk,
      );

      final reqJson = req.toJson();
      expect(reqJson['cow_id'], 'COW-104');
      expect((reqJson['collar_data'] as List).length, 1);
      expect((reqJson['milk_data'] as Map)['scc'], 420000);

      final parsedReq = AnalysisRequest.fromJson(reqJson);
      expect(parsedReq.cowId, 'COW-104');
      expect(parsedReq.milkData.scc, 420000);

      // AnalysisResult
      final res = AnalysisResult(
        cowId: 'COW-104',
        prediction: 1,
        probability: 0.84,
        riskLevel: 'HIGH',
        factors: ['Elevated SCC', 'High Conductivity'],
        recommendedAction: 'Perform CMT test immediately.',
      );

      final resJson = res.toJson();
      expect(resJson['risk_level'], 'HIGH');
      expect(resJson['prediction'], 1);

      final parsedRes = AnalysisResult.fromJson(resJson);
      expect(parsedRes.isHighRisk, true);
      expect(parsedRes.isLowRisk, false);
      expect(parsedRes.probability, 0.84);
    });
  });
}
