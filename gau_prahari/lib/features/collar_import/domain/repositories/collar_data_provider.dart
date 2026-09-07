import '../entities/collar_telemetry.dart';

/// Abstract provider interface for obtaining and parsing longitudinal collar telemetry.
/// Allows swapping file-based historical import with real-time BLE telemetry in the future.
abstract class CollarDataProvider {
  /// Parses raw text content (CSV or JSON format) and validates against the expected cow ID.
  Future<CollarHistory> parseData(
    String rawContent, {
    required String expectedCowId,
  });

  /// Loads and parses a bundled asset dataset.
  Future<CollarHistory> loadFromAsset(
    String assetPath, {
    required String expectedCowId,
  });
}
