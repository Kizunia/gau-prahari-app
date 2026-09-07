import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/data/repositories/hardware_milk_tester.dart';
import 'package:gau_prahari/features/milk_tester/data/services/arduino_data_parser.dart';
import 'package:gau_prahari/features/milk_tester/domain/repositories/milk_data_provider.dart';
import 'package:gau_prahari/features/milk_tester/presentation/screens/milk_tester_screen.dart';

void main() {
  const testCow = Cow(
    id: 'COW-104',
    tagNumber: 'RFID-104',
    breed: 'Gir',
    ageYears: 4,
    lactationStage: 'Early Lactation',
  );

  group('ArduinoDataParser Unit Tests', () {
    const parser = ArduinoDataParser();

    test('Parses standard JSON Arduino Bluetooth payload correctly', () {
      const jsonRaw =
          '{"milk_temperature": 36.2, "ph": 6.65, "conductivity": 4.75, "scc": 140000, "fat": 4.2, "snf": 8.8, "gas": 210, "distance": 15}';

      final parsed = parser.parse(rawData: jsonRaw, cowId: 'COW-104');
      final m = parsed.measurement;

      expect(m.cowId, equals('COW-104'));
      expect(m.milkTemperature, closeTo(36.2, 0.01));
      expect(m.ph, closeTo(6.65, 0.01));
      expect(m.conductivity, closeTo(4.75, 0.01));
      expect(m.scc, equals(140000));
      expect(m.fat, closeTo(4.2, 0.01));
      expect(m.snf, closeTo(8.8, 0.01));
      expect(parsed.metadata.gasMq2, equals(210));
      expect(parsed.metadata.distanceCm, equals(15));
      expect(m.isValid, isTrue);
    });

    test('Parses legacy raw Arduino format (pH:6.7,G:210,D:15cm) correctly', () {
      const rawString = 'pH:6.7,G:210,D:15cm';

      final parsed = parser.parse(rawData: rawString, cowId: 'COW-104');
      final m = parsed.measurement;

      expect(m.cowId, equals('COW-104'));
      expect(m.ph, closeTo(6.7, 0.01));
      expect(m.conductivity, closeTo(4.60, 0.01));
      expect(m.scc, equals(120000));
      expect(parsed.metadata.gasMq2, equals(210));
      expect(parsed.metadata.distanceCm, equals(15));
      expect(m.isValid, isTrue);
    });

    test('Parses user terminal stream format (pH:6.5,G:107,D:45cm) with noise', () {
      const userPacket = 'p11,D:50cm\r\npH:6.5,G:107,D:45cm';

      final parsed = parser.parse(rawData: userPacket, cowId: 'COW-104');
      final m = parsed.measurement;

      expect(m.cowId, equals('COW-104'));
      expect(m.ph, closeTo(6.5, 0.01));
      expect(parsed.metadata.gasMq2, equals(107));
      expect(parsed.metadata.distanceCm, equals(45));
      expect(m.isValid, isTrue);
    });

    test('Correlates alkaline pH and elevated gas to mastitis biomarkers', () {
      const rawMastitis = 'pH:7.2,G:420,D:12cm';

      final parsed = parser.parse(rawData: rawMastitis, cowId: 'COW-104');
      final m = parsed.measurement;

      expect(m.ph, closeTo(7.2, 0.01));
      expect(m.conductivity, greaterThan(5.80));
      expect(m.scc, greaterThan(400000));
      expect(m.isSccElevated, isTrue);
      expect(m.isConductivityElevated, isTrue);
    });

    test('Rejects empty or unrecognizable payload', () {
      expect(
        () => parser.parse(rawData: '', cowId: 'COW-104'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parser.parse(rawData: 'INVALID_STREAM_DATA', cowId: 'COW-104'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('HardwareMilkTester Repository Tests', () {
    test('Executes Bluetooth lifecycle stream and ingests custom packet', () async {
      final tester = HardwareMilkTester(
        connectionDelay: const Duration(milliseconds: 10),
        measurementDelay: const Duration(milliseconds: 10),
      );

      tester.setStreamPacket(
        '{"milk_temperature": 36.5, "ph": 6.70, "conductivity": 4.90, "scc": 155000, "fat": 4.0, "snf": 8.5, "gas": 190, "distance": 18}',
      );

      final states = <MilkTestingState>[];
      final sub = tester.stateStream.listen((s) => states.add(s));

      final measurement = await tester.getMeasurement(cowId: 'COW-104');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(measurement.cowId, equals('COW-104'));
      expect(measurement.ph, closeTo(6.70, 0.01));
      expect(tester.latestMetadata.gasMq2, equals(190));
      expect(tester.latestMetadata.distanceCm, equals(18));
      expect(states, containsAllInOrder([
        MilkTestingState.searching,
        MilkTestingState.connecting,
        MilkTestingState.connected,
        MilkTestingState.measuring,
        MilkTestingState.completed,
      ]));

      await sub.cancel();
    });
  });

  group('MilkTesterScreen Hardware UI Tests', () {
    testWidgets('Renders mode selector and switches between Hardware and Demo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MilkTesterScreen(cow: testCow),
        ),
      );

      expect(find.text('Live Arduino (HC-05)'), findsOneWidget);
      expect(find.text('Demo Simulation'), findsOneWidget);
      expect(find.text('Start Milk Sample Analysis'), findsOneWidget);

      // Switch to Hardware
      await tester.tap(find.text('Live Arduino (HC-05)'));
      await tester.pumpAndSettle();

      expect(find.text('Start Milk Sample Analysis'), findsOneWidget);

      // Switch to Demo Simulation
      await tester.tap(find.text('Demo Simulation'));
      await tester.pumpAndSettle();

      expect(find.text('Simulation Presets (Testing Profiles)'), findsOneWidget);
      expect(find.text('Healthy Sample'), findsOneWidget);
      expect(find.text('Start Milk Sample Analysis'), findsOneWidget);
    });
  });
}
