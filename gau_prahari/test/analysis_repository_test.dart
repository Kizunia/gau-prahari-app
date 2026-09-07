import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gau_prahari/features/analysis/data/repositories/analysis_repository_impl.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_request.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';

void main() {
  group('Phase 4 AnalysisRepository Tests', () {
    final sampleMilk = MilkMeasurement(
      cowId: 'COW-104',
      milkTemperature: 36.9,
      ph: 6.78,
      conductivity: 6.18,
      scc: 380000,
      fat: 3.8,
      snf: 8.4,
    );

    final sampleRequest = AnalysisRequest(
      cowId: 'COW-104',
      collarData: const [],
      milkData: sampleMilk,
    );

    test('Successfully parses 200 JSON response from FastAPI backend', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/analysis/predict');
        expect(request.method, 'POST');

        final responseJson = {
          'cow_id': 'COW-104',
          'prediction': 1,
          'probability': 0.88,
          'risk_level': 'HIGH',
          'factors': ['Elevated Somatic Cell Count', 'Elevated Electrical Conductivity'],
          'recommended_action': 'Isolate animal and perform CMT test.',
          'timestamp': '2026-09-07T12:00:00',
        };

        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final repo = AnalysisRepositoryImpl(
        baseUrl: 'http://test-server:8000',
        httpClient: mockClient,
      );

      final result = await repo.analyzeSample(sampleRequest);

      expect(result.cowId, 'COW-104');
      expect(result.prediction, 1);
      expect(result.isHighRisk, true);
      expect(result.probability, 0.88);
      expect(result.factors.length, 2);
    });

    test('Executes calibrated offline fallback when backend server is unavailable', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection refused');
      });

      final repo = AnalysisRepositoryImpl(
        baseUrl: 'http://unreachable:8000',
        httpClient: mockClient,
        allowOfflineFallback: true,
      );

      final result = await repo.analyzeSample(sampleRequest);

      expect(result.cowId, 'COW-104');
      expect(result.isHighRisk, true);
      expect(result.riskLevel, 'HIGH');
      expect(result.probability, greaterThanOrEqualTo(0.65));
      expect(result.factors.any((f) => f.contains('Somatic Cell Count')), true);
      expect(result.factors.any((f) => f.contains('Electrical Conductivity')), true);
    });
  });
}
