import 'package:flutter/material.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_request.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/analysis/domain/repositories/analysis_repository.dart';

/// Controller managing the inference pipeline state and prediction results.
class AnalysisController extends ChangeNotifier {
  final AnalysisRepository _repository;

  AnalysisResult? _result;
  bool _isAnalyzing = false;
  String? _errorMessage;

  AnalysisController({required AnalysisRepository repository})
    : _repository = repository;

  AnalysisResult? get result => _result;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  bool get hasResult => _result != null;

  /// Runs the mastitis risk prediction model
  Future<bool> analyze({
    required String cowId,
    required MilkMeasurement milkData,
    List<CollarTelemetry>? collarData,
  }) async {
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = AnalysisRequest(
        cowId: cowId,
        collarData: collarData ?? const [],
        milkData: milkData,
      );

      final analysisResult = await _repository.analyzeSample(request);
      _result = analysisResult;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _result = null;
      notifyListeners();
      return false;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  void reset() {
    _result = null;
    _errorMessage = null;
    _isAnalyzing = false;
    notifyListeners();
  }
}
