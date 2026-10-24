import 'dart:async';
import '../../domain/entities/milk_measurement.dart';
import '../../domain/repositories/milk_data_provider.dart';

/// Preset simulation profiles for the mock milk tester.
enum MockSamplePreset { healthy, subclinical, clinical }

/// Concrete mock implementation of [MilkDataProvider].
/// Simulates hardware discovery, sensor sampling, and measurement delivery.
class MockMilkTester implements MilkDataProvider {
  MilkTestingState _state = MilkTestingState.disconnected;
  final _stateController = StreamController<MilkTestingState>.broadcast();
  MockSamplePreset activePreset = MockSamplePreset.subclinical;

  @override
  MilkTestingState get state => _state;

  @override
  Stream<MilkTestingState> get stateStream => _stateController.stream;

  void _setState(MilkTestingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @override
  Future<MilkMeasurement> getMeasurement({required String cowId}) async {
    // 1. Searching
    _setState(MilkTestingState.searching);
    await Future.delayed(const Duration(milliseconds: 400));

    // 2. Connecting
    _setState(MilkTestingState.connecting);
    await Future.delayed(const Duration(milliseconds: 400));

    // 3. Connected
    _setState(MilkTestingState.connected);
    await Future.delayed(const Duration(milliseconds: 300));

    // 4. Measuring / Sampling sensor probe
    _setState(MilkTestingState.measuring);
    await Future.delayed(const Duration(milliseconds: 800));

    // 5. Generate measurement based on active preset
    final measurement = _generateMeasurement(cowId, activePreset);

    // 6. Completed
    _setState(MilkTestingState.completed);
    return measurement;
  }

  MilkMeasurement _generateMeasurement(String cowId, MockSamplePreset preset) {
    switch (preset) {
      case MockSamplePreset.healthy:
        return MilkMeasurement(
          cowId: cowId,
          milkTemperature: 35.8,
          ph: 6.68,
          conductivity: 4.85,
          scc: 125000,
          fat: 4.2,
          snf: 8.8,
        );
      case MockSamplePreset.subclinical:
        return MilkMeasurement(
          cowId: cowId,
          milkTemperature: 36.9,
          ph: 6.78,
          conductivity: 6.18,
          scc: 380000,
          fat: 3.8,
          snf: 8.4,
        );
      case MockSamplePreset.clinical:
        return MilkMeasurement(
          cowId: cowId,
          milkTemperature: 38.6,
          ph: 7.15,
          conductivity: 7.42,
          scc: 890000,
          fat: 3.1,
          snf: 7.9,
        );
    }
  }

  @override
  Future<void> disconnect() async {
    _setState(MilkTestingState.disconnected);
  }

  void dispose() {
    _stateController.close();
  }
}
