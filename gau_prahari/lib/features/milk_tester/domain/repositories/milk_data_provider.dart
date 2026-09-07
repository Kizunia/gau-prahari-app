import '../entities/milk_measurement.dart';

/// Connection and sampling states for the milk tester hardware.
enum MilkTestingState {
  disconnected,
  searching,
  connecting,
  connected,
  measuring,
  completed,
  error,
}

/// Abstract provider interface for obtaining milk measurements.
/// Decouples the UI and analysis pipelines from physical BLE hardware.
abstract class MilkDataProvider {
  /// Fetches or reads a milk measurement for the specified cow.
  Future<MilkMeasurement> getMeasurement({required String cowId});

  /// Current connection/operational state.
  MilkTestingState get state;

  /// Stream of state transitions.
  Stream<MilkTestingState> get stateStream;

  /// Disconnect or reset tester.
  Future<void> disconnect();
}
