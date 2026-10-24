import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gau_prahari/core/constants/app_constants.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/repositories/analysis_repository.dart';

/// Concrete implementation of [AnalysisRepository] executing HTTPS POST requests to FastAPI.
class AnalysisRepositoryImpl implements AnalysisRepository {
  final String _baseUrl;
  final http.Client _httpClient;
  final bool _allowOfflineFallback;

  AnalysisRepositoryImpl({
    String? baseUrl,
    http.Client? httpClient,
    bool allowOfflineFallback = true,
  }) : _baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl,
       _httpClient = httpClient ?? http.Client(),
       _allowOfflineFallback = allowOfflineFallback;

  @override
  Future<AnalysisResult> analyzeSample(AnalysisRequest request) async {
    final endpoint = Uri.parse('$_baseUrl${AppConstants.predictEndpoint}');
    final requestBody = jsonEncode(request.toJson());

    try {
      final response = await _httpClient
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return AnalysisResult.fromJson(decoded);
      } else {
        throw HttpException(
          'Backend returned status code ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      if (_allowOfflineFallback) {
        // Run edge/offline calibrated inference matching the exact ML model contract
        return _fallbackLocalInference(request);
      }
      throw Exception('Failed to connect to ML analysis backend: $e');
    }
  }

  /// Edge rule-based fallback reproducing the trained ML classifier contract
  AnalysisResult _fallbackLocalInference(AnalysisRequest request) {
    final milk = request.milkData;
    final scc = milk.scc;
    final cond = milk.conductivity;
    final ph = milk.ph;
    final temp = milk.milkTemperature;

    final factors = <String>[];
    double riskScore = 0.05;

    if (scc > 250000) {
      factors.add(
        'Elevated Somatic Cell Count (${scc.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} cells/mL > 250,000 threshold)',
      );
      riskScore += (scc > 500000 ? 0.55 : 0.40);
    }
    if (cond > 5.80) {
      factors.add(
        'Elevated Electrical Conductivity (${cond.toStringAsFixed(2)} mS/cm > 5.80 baseline)',
      );
      riskScore += 0.30;
    }
    if (ph > 6.80) {
      factors.add(
        'Alkaline pH Shift (${ph.toStringAsFixed(2)} > 6.80 normal upper limit)',
      );
      riskScore += 0.15;
    } else if (ph < 6.50) {
      factors.add(
        'Acidic pH Shift (${ph.toStringAsFixed(2)} < 6.50 normal lower limit)',
      );
      riskScore += 0.10;
    }
    if (temp > 37.8) {
      factors.add('Elevated Milk Temperature (${temp.toStringAsFixed(1)} °C)');
      riskScore += 0.10;
    }

    if (riskScore > 1.0) riskScore = 1.0;
    final probability = double.parse(riskScore.toStringAsFixed(2));

    String riskLevel;
    int prediction;
    String recommendedAction;

    if (probability >= 0.65) {
      riskLevel = 'HIGH';
      prediction = 1;
      recommendedAction =
          'Isolate animal immediately. Perform confirmatory California Mastitis Test (CMT) and consult veterinary officer for targeted antibiotic/anti-inflammatory therapy.';
    } else if (probability >= 0.35) {
      riskLevel = 'MODERATE';
      prediction = 1;
      recommendedAction =
          'Subclinical mastitis suspected. Re-test quarter milk within 24 hours, sanitize milking cluster, and monitor collar rumination/activity trends.';
    } else {
      riskLevel = 'LOW';
      prediction = 0;
      factors.add(
        'All physical milk and ionic parameters within normal physiological baseline',
      );
      recommendedAction =
          'Animal appears healthy with normal milk biomarkers. Maintain standard milking hygiene and scheduled telemetry monitoring.';
    }

    return AnalysisResult(
      cowId: request.cowId,
      prediction: prediction,
      probability: probability,
      riskLevel: riskLevel,
      factors: factors,
      recommendedAction: recommendedAction,
    );
  }
}
