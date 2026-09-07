import '../entities/analysis_request.dart';
import '../entities/analysis_result.dart';

/// Abstract repository defining the contract for executing mastitis analysis.
abstract class AnalysisRepository {
  /// Sends the analysis request payload to the ML inference backend.
  Future<AnalysisResult> analyzeSample(AnalysisRequest request);
}
