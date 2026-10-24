import 'dart:math';
import '../../domain/entities/collar_telemetry.dart';

/// Parsed telemetry packet from collar hardware
class CollarHardwarePacket {
  final String? cowId;
  final double ambientTemp;
  final double skinTemp;
  final double humidity;
  final double thi;
  final double activityIndex;
  final double accX;
  final double accY;
  final int irValue;
  final bool isWorn;

  const CollarHardwarePacket({
    this.cowId,
    required this.ambientTemp,
    required this.skinTemp,
    required this.humidity,
    required this.thi,
    required this.activityIndex,
    required this.accX,
    required this.accY,
    required this.irValue,
    required this.isWorn,
  });

  CollarTelemetry toCollarTelemetry({DateTime? timestamp}) {
    return CollarTelemetry(
      timestamp: timestamp ?? DateTime.now(),
      activity: activityIndex,
      skinTemperature: skinTemp,
      ambientTemperature: ambientTemp,
      humidity: humidity,
      thi: thi,
    );
  }
}

/// Parser for pipe-delimited Arduino collar stream:
/// Format: T:32.4C|H:65.2%|Acc[0.1,0.9]|IR:45210
/// (or optionally with ID: ID:COW-104|T:32.4C|H:65.2%|Acc[0.1,0.9]|IR:45210)
class CollarBluetoothParser {
  const CollarBluetoothParser();

  CollarHardwarePacket parse(String rawLine) {
    final clean = rawLine.trim();
    if (clean.isEmpty) {
      throw const FormatException('Empty collar telemetry line');
    }

    String? cowId;
    double temp = 28.0;
    double hum = 60.0;
    double accX = 0.0;
    double accY = 0.0;
    int ir = 0;

    final parts = clean.split('|');
    for (final part in parts) {
      final token = part.trim();
      if (token.startsWith('ID:')) {
        cowId = token.substring(3).trim();
      } else if (token.startsWith('T:')) {
        final tVal = token.substring(2).replaceAll('C', '').replaceAll('c', '').trim();
        final parsed = double.tryParse(tVal);
        if (parsed != null) temp = parsed;
      } else if (token.startsWith('H:')) {
        final hVal = token.substring(2).replaceAll('%', '').trim();
        final parsed = double.tryParse(hVal);
        if (parsed != null) hum = parsed;
      } else if (token.startsWith('Acc[') && token.endsWith(']')) {
        final inner = token.substring(4, token.length - 1);
        final coords = inner.split(',');
        if (coords.length >= 2) {
          accX = double.tryParse(coords[0].trim()) ?? 0.0;
          accY = double.tryParse(coords[1].trim()) ?? 0.0;
        }
      } else if (token.startsWith('IR:')) {
        final irVal = token.substring(3).trim();
        ir = int.tryParse(irVal) ?? 0;
      }
    }

    // Physiological calculations:
    // 1. THI (Temperature-Humidity Index for Dairy Cattle)
    // Formula: (0.8 * T) + ((H / 100) * (T - 14.4)) + 46.4
    final thi = (0.8 * temp) + ((hum / 100.0) * (temp - 14.4)) + 46.4;

    // 2. Activity Index (0 - 100) derived from Accelerometer magnitude
    // G-vector magnitude: sqrt(x^2 + y^2)
    // In typical resting state ~0.0 to 0.3g dynamic variation.
    // Scale up to 0-100 activity index.
    final gMag = sqrt(accX * accX + accY * accY);
    // 0.0g - 1.5g maps smoothly to 30 - 95 activity index
    final double activity = (35.0 + (gMag * 40.0)).clamp(10.0, 100.0);

    // 3. Skin Temperature:
    // Cows maintain internal ~38.6°C. Skin temperature tracks close to body temp
    // with ambient offset: Tskin ~ 35.5 + (ambient * 0.08)
    final double skinTemp = double.parse((35.8 + (temp * 0.06)).toStringAsFixed(1));

    // 4. Animal Worn status based on MAX30105 IR reflectance
    final bool isWorn = ir > 1000;

    return CollarHardwarePacket(
      cowId: cowId,
      ambientTemp: double.parse(temp.toStringAsFixed(1)),
      skinTemp: skinTemp,
      humidity: double.parse(hum.toStringAsFixed(1)),
      thi: double.parse(thi.toStringAsFixed(1)),
      activityIndex: double.parse(activity.toStringAsFixed(1)),
      accX: accX,
      accY: accY,
      irValue: ir,
      isWorn: isWorn,
    );
  }
}
