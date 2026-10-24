import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/collar_import/data/services/collar_bluetooth_parser.dart';

void main() {
  group('CollarBluetoothParser', () {
    const parser = CollarBluetoothParser();

    test('parses standard Arduino telemetry stream line correctly', () {
      const line = 'T:32.4C|H:65.2%|Acc[0.1,0.9]|IR:45210';
      final packet = parser.parse(line);

      expect(packet.ambientTemp, 32.4);
      expect(packet.humidity, 65.2);
      expect(packet.accX, 0.1);
      expect(packet.accY, 0.9);
      expect(packet.irValue, 45210);
      expect(packet.isWorn, isTrue);
      expect(packet.thi, greaterThan(70.0));
      expect(packet.activityIndex, greaterThan(35.0));
    });

    test('parses telemetry line with ID prefix', () {
      const line = 'ID:COW-104|T:35.0C|H:70.0%|Acc[0.3,0.4]|IR:52000';
      final packet = parser.parse(line);

      expect(packet.cowId, 'COW-104');
      expect(packet.ambientTemp, 35.0);
      expect(packet.humidity, 70.0);
      expect(packet.isWorn, isTrue);
    });

    test('converts to CollarTelemetry entity properly', () {
      const line = 'T:29.0C|H:55.0%|Acc[0.0,0.2]|IR:30000';
      final packet = parser.parse(line);
      final entity = packet.toCollarTelemetry();

      expect(entity.ambientTemperature, 29.0);
      expect(entity.humidity, 55.0);
      expect(entity.skinTemperature, greaterThan(36.0));
      expect(entity.thi, greaterThan(50.0));
    });
  });
}
