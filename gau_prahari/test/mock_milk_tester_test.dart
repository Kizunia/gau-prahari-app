import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/milk_tester/data/repositories/mock_milk_tester.dart';
import 'package:gau_prahari/features/milk_tester/domain/repositories/milk_data_provider.dart';
import 'package:gau_prahari/features/milk_tester/presentation/controllers/milk_tester_controller.dart';

void main() {
  group('Phase 2 MockMilkTester & Controller Tests', () {
    late MockMilkTester mockTester;
    late MilkTesterController controller;

    setUp(() {
      mockTester = MockMilkTester();
      controller = MilkTesterController(provider: mockTester);
    });

    tearDown(() {
      controller.dispose();
      mockTester.dispose();
    });

    test('MockMilkTester cycles through states and returns subclinical preset by default', () async {
      final states = <MilkTestingState>[];
      final subscription = mockTester.stateStream.listen(states.add);

      expect(mockTester.state, MilkTestingState.disconnected);

      final measurement = await mockTester.getMeasurement(cowId: 'COW-104');
      await Future.delayed(Duration.zero);

      expect(states, [
        MilkTestingState.searching,
        MilkTestingState.connecting,
        MilkTestingState.connected,
        MilkTestingState.measuring,
        MilkTestingState.completed,
      ]);

      expect(measurement.cowId, 'COW-104');
      expect(measurement.isValid, true);
      expect(measurement.scc, 380000);
      expect(measurement.isSccElevated, true);

      await subscription.cancel();
    });

    test('Changing preset to Healthy returns low SCC and normal conductivity', () async {
      controller.setPreset(MockSamplePreset.healthy);
      expect(controller.activePreset, MockSamplePreset.healthy);

      await controller.takeMeasurement('COW-101');

      expect(controller.state, MilkTestingState.completed);
      expect(controller.hasMeasurement, true);
      expect(controller.measurement?.scc, 125000);
      expect(controller.measurement?.isSccElevated, false);
      expect(controller.measurement?.isConductivityElevated, false);
    });

    test('Changing preset to Clinical returns severe inflammatory profile', () async {
      controller.setPreset(MockSamplePreset.clinical);

      await controller.takeMeasurement('COW-104');

      expect(controller.measurement?.scc, 890000);
      expect(controller.measurement?.ph, 7.15);
      expect(controller.measurement?.conductivity, 7.42);
      expect(controller.measurement?.isConductivityElevated, true);
      expect(controller.measurement?.isPhAbnormal, true);
    });

    test('Reset clears measurement and disconnects tester', () async {
      await controller.takeMeasurement('COW-104');
      expect(controller.hasMeasurement, true);

      controller.reset();
      expect(controller.hasMeasurement, false);
      expect(controller.state, MilkTestingState.disconnected);
    });
  });
}
