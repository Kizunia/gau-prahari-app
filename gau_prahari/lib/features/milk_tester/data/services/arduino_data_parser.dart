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
  ParsedArduinoPayload parse({
    required String rawData,
    required String cowId,
  }) {
    final clean = rawData.trim();
    if (clean.isEmpty) {
      throw const FormatException('Empty payload received from Bluetooth stream');
    }

    // --- Mode 1: Structured JSON Payload ---
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final Map<String, dynamic> json = jsonDecode(clean);

        final rawScc = json['scc'];
        int sccValue = 140000;
        if (rawScc is num) {
          // If SCC is in thousands scale (e.g. 148 -> 148000), scale up for app model
          sccValue = rawScc < 2000 ? (rawScc * 1000).toInt() : rawScc.toInt();
        }

        final double temp = (json['milk_temperature'] as num?)?.toDouble() ?? 36.0;
        final double ph = (json['ph'] as num?)?.toDouble() ?? 6.65;
        final double cond = (json['conductivity'] as num?)?.toDouble() ?? 4.80;
        final double fat = (json['fat'] as num?)?.toDouble() ?? 4.1;
        final double snf = (json['snf'] as num?)?.toDouble() ?? 8.6;

        final int? gas = (json['gas'] as num?)?.toInt();
        final int? dist = (json['distance'] as num?)?.toInt();

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

    // --- Mode 2: Key-Value Raw Format (e.g. "pH:6.7,G:210,D:15cm" or "pH:6.5,G:107,D:45cm") ---
    if (clean.contains('pH:') || clean.contains('G:') || clean.contains('D:')) {
      double ph = 6.65;
      int gas = 200;
      int? distance;

      final phMatches = RegExp(r'pH:\s*([\d\.]+)').allMatches(clean);
      if (phMatches.isNotEmpty) {
        ph = double.tryParse(phMatches.last.group(1) ?? '') ?? 6.65;
      }

      final gMatches = RegExp(r'G:\s*(\d+)').allMatches(clean);
      if (gMatches.isNotEmpty) {
        gas = int.tryParse(gMatches.last.group(1) ?? '') ?? 200;
      }

      final dMatches = RegExp(r'D:\s*(\d+)').allMatches(clean);
      if (dMatches.isNotEmpty) {
        distance = int.tryParse(dMatches.last.group(1) ?? '');
      }

      // Map hardware sensors to biological mastitis biomarkers
      // Normal milk pH is 6.5 - 6.8. Alkaline > 6.8 indicates mastitis
      final isAlkaline = ph > 6.80;
      final isGasHigh = gas > 350;

      final double cond = 4.60 + (isAlkaline ? (ph - 6.80) * 3.5 : 0.0) + (isGasHigh ? (gas - 350) * 0.003 : 0.0);
      final int scc = (isAlkaline || isGasHigh)
          ? (350000 + ((ph - 6.80) * 500000).toInt() + (gas * 250)).clamp(300000, 950000)
          : 120000;
      final double temp = 35.8 + (isAlkaline || isGasHigh ? 1.8 : 0.2);
      final double fat = (isAlkaline || isGasHigh) ? 3.2 : 4.2;
      final double snf = (isAlkaline || isGasHigh) ? 7.8 : 8.8;

      final measurement = MilkMeasurement(
        cowId: cowId,
        milkTemperature: temp.clamp(25.0, 45.0),
        ph: ph.clamp(5.5, 8.5),
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
