import 'dart:convert';
import '../../domain/entities/milk_measurement.dart';

/// Parsed metadata from Arduino hardware sensors (MQ-2 gas, Ultrasonic distance)
class ArduinoHardwareMetadata {
  final int? gasMq2;
  final int? distanceCm;

  const ArduinoHardwareMetadata({this.gasMq2, this.distanceCm});
}

/// Result containing both standard [MilkMeasurement] and optional hardware metadata
class ParsedArduinoPayload {
  final MilkMeasurement measurement;
  final ArduinoHardwareMetadata metadata;

  const ParsedArduinoPayload({
    required this.measurement,
    this.metadata = const ArduinoHardwareMetadata(),
  });
}

/// Robust parser for incoming Arduino Bluetooth telemetry streams
class ArduinoDataParser {
  const ArduinoDataParser();

  /// Parses both structured JSON and raw string formats emitted by Arduino HC-05
  ParsedArduinoPayload parse({required String rawData, required String cowId}) {
    final clean = rawData.trim();
    if (clean.isEmpty) {
      throw const FormatException(
        'Empty payload received from Bluetooth stream',
      );
    }

    // --- Mode 1: Structured JSON Payload ---
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final Map<String, dynamic> json = jsonDecode(clean);

        final double ph = (json['ph'] as num?)?.toDouble() ?? 6.65;
        final int? gas = (json['gas'] as num?)?.toInt();
        final int? dist = (json['distance'] as num?)?.toInt();

        // If hardware rig does not have temp/cond/scc sensors, correlate from pH and gas
        final isAlkaline = ph > 6.80;
        final isGasHigh = (gas != null && gas > 350);

        final double estimatedCond =
            4.60 +
            (isAlkaline ? (ph - 6.80) * 3.5 : 0.0) +
            (isGasHigh ? (gas - 350) * 0.003 : 0.0);
        final int estimatedScc = (isAlkaline || isGasHigh)
            ? (350000 + ((ph - 6.80) * 500000).toInt() + ((gas ?? 200) * 250))
                  .clamp(300000, 950000)
            : 120000;
        final double estimatedTemp =
            35.8 + (isAlkaline || isGasHigh ? 1.8 : 0.2);
        final double estimatedFat = (isAlkaline || isGasHigh) ? 3.2 : 4.1;
        final double estimatedSnf = (isAlkaline || isGasHigh) ? 7.8 : 8.6;

        final double temp =
            (json['milk_temperature'] as num?)?.toDouble() ?? estimatedTemp;
        final double cond =
            (json['conductivity'] as num?)?.toDouble() ??
            double.parse(estimatedCond.toStringAsFixed(2));
        final double fat = (json['fat'] as num?)?.toDouble() ?? estimatedFat;
        final double snf = (json['snf'] as num?)?.toDouble() ?? estimatedSnf;

        final rawScc = json['scc'];
        int sccValue = estimatedScc;
        if (rawScc is num) {
          // If SCC is in thousands scale (e.g. 148 -> 148000), scale up for app model
          sccValue = rawScc < 2000 ? (rawScc * 1000).toInt() : rawScc.toInt();
        }

        final measurement = MilkMeasurement(
          cowId: cowId,
          milkTemperature: temp.clamp(25.0, 45.0),
          ph: ph.clamp(5.5, 8.5),
          conductivity: cond.clamp(2.0, 15.0),
          scc: sccValue.clamp(0, 5000000),
          fat: fat.clamp(0.0, 15.0),
          snf: snf.clamp(0.0, 20.0),
        );

        return ParsedArduinoPayload(
          measurement: measurement,
          metadata: ArduinoHardwareMetadata(gasMq2: gas, distanceCm: dist),
        );
      } catch (e) {
        throw FormatException('Failed to parse Arduino JSON payload: $e');
      }
    }

    // --- Mode 2: Key-Value Raw Format (e.g. "pH:4.10,LEVEL:17,GAS:44,STATUS:ACIDIC" or "pH:6.7,G:210,D:15cm") ---
    final upperClean = clean.toUpperCase();
    if (upperClean.contains('PH:') ||
        upperClean.contains('GAS:') ||
        upperClean.contains('G:') ||
        upperClean.contains('LEVEL:') ||
        upperClean.contains('D:')) {
      double ph = 6.65;
      int gas = 200;
      int? distance;

      final phMatches = RegExp(
        r'pH:\s*([\d\.]+)',
        caseSensitive: false,
      ).allMatches(clean);
      if (phMatches.isNotEmpty) {
        ph = double.tryParse(phMatches.last.group(1) ?? '') ?? 6.65;
      }

      final gMatches = RegExp(
        r'(?:GAS|G):\s*(\d+)',
        caseSensitive: false,
      ).allMatches(clean);
      if (gMatches.isNotEmpty) {
        gas = int.tryParse(gMatches.last.group(1) ?? '') ?? 200;
      }

      final dMatches = RegExp(
        r'(?:LEVEL|D):\s*(\d+)',
        caseSensitive: false,
      ).allMatches(clean);
      if (dMatches.isNotEmpty) {
        distance = int.tryParse(dMatches.last.group(1) ?? '');
      }

      // Map hardware sensors to biological mastitis biomarkers
      // Normal milk pH is 6.5 - 6.8. Alkaline > 6.8 indicates subclinical/clinical mastitis
      // Acidic milk pH < 6.4 indicates souring, high lactic fermentation, or severe acid disturbance
      final isAlkaline = ph > 6.80;
      final isAcidic = ph < 6.40;
      final isGasHigh = gas > 350;

      final double cond =
          4.60 +
          (isAlkaline ? (ph - 6.80) * 3.5 : 0.0) +
          (isAcidic ? (6.40 - ph) * 0.5 : 0.0) +
          (isGasHigh ? (gas - 350) * 0.003 : 0.0);
      final int scc = (isAlkaline || isGasHigh)
          ? (350000 + ((ph - 6.80) * 500000).toInt() + (gas * 250)).clamp(
              300000,
              950000,
            )
          : (isAcidic
                ? (150000 + ((6.40 - ph) * 80000).toInt()).clamp(120000, 400000)
                : 120000);
      final double temp = 35.8 + (isAlkaline || isGasHigh ? 1.8 : 0.2);
      final double fat = (isAlkaline || isGasHigh)
          ? 3.2
          : (isAcidic ? 3.6 : 4.2);
      final double snf = (isAlkaline || isGasHigh)
          ? 7.8
          : (isAcidic ? 8.1 : 8.8);

      final measurement = MilkMeasurement(
        cowId: cowId,
        milkTemperature: temp.clamp(25.0, 45.0),
        ph: ph.clamp(3.0, 9.0),
        conductivity: double.parse(cond.toStringAsFixed(2)).clamp(2.0, 15.0),
        scc: scc.clamp(0, 5000000),
        fat: fat.clamp(0.0, 15.0),
        snf: snf.clamp(0.0, 20.0),
      );

      return ParsedArduinoPayload(
        measurement: measurement,
        metadata: ArduinoHardwareMetadata(gasMq2: gas, distanceCm: distance),
      );
    }

    throw FormatException('Unrecognized Arduino stream format: "$clean"');
  }
}
