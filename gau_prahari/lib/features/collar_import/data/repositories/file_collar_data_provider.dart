import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/collar_import/domain/repositories/collar_data_provider.dart';

/// Concrete implementation of [CollarDataProvider] supporting CSV and JSON files.
class FileCollarDataProvider implements CollarDataProvider {
  @override
  Future<CollarHistory> loadFromAsset(
    String assetPath, {
    required String expectedCowId,
  }) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return parseData(content, expectedCowId: expectedCowId);
    } catch (e) {
      throw Exception('Failed to load asset "$assetPath": $e');
    }
  }

  @override
  Future<CollarHistory> parseData(
    String rawContent, {
    required String expectedCowId,
  }) async {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      throw Exception('Collar telemetry file is empty');
    }

    // Detect format: JSON starts with '{' or '['
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return _parseJson(trimmed, expectedCowId);
    } else {
      return _parseCsv(trimmed, expectedCowId);
    }
  }

  CollarHistory _parseJson(String jsonString, String expectedCowId) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid JSON structure: Expected a root JSON object.');
      }

      final fileCowId = decoded['cow_id'] as String? ?? '';
      if (fileCowId.trim().toUpperCase() !=
          expectedCowId.trim().toUpperCase()) {
        throw Exception(
          'Cow ID mismatch: File contains data for "$fileCowId", but selected cow is "$expectedCowId".',
        );
      }

      final recordsList = decoded['records'];
      if (recordsList is! List || recordsList.isEmpty) {
        throw Exception(
          'JSON file contains no telemetry records in "records" array.',
        );
      }

      final telemetryList = <CollarTelemetry>[];
      for (int i = 0; i < recordsList.length; i++) {
        final recordMap = recordsList[i];
        if (recordMap is! Map<String, dynamic>) {
          throw Exception('Record at index $i is malformed.');
        }
        telemetryList.add(CollarTelemetry.fromJson(recordMap));
      }

      return CollarHistory(cowId: expectedCowId, records: telemetryList);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('JSON parse error: $e');
    }
  }

  CollarHistory _parseCsv(String csvString, String expectedCowId) {
    final lines = csvString
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) {
      throw Exception(
        'CSV file must contain a header line and at least one data record.',
      );
    }

    // Parse header
    final header = lines[0]
        .toLowerCase()
        .split(',')
        .map((h) => h.trim())
        .toList();

    int findCol(String name) {
      final idx = header.indexOf(name);
      if (idx == -1) {
        throw Exception(
          'Missing required CSV header column: "$name". Found: ${header.join(", ")}',
        );
      }
      return idx;
    }

    final cowIdIdx = findCol('cow_id');
    final timestampIdx = findCol('timestamp');
    final activityIdx = findCol('activity');
    final skinTempIdx = findCol('skin_temperature');
    final ambientTempIdx = findCol('ambient_temperature');
    final humidityIdx = findCol('humidity');
    final thiIdx = findCol('thi');

    final telemetryList = <CollarTelemetry>[];

    for (int lineNum = 1; lineNum < lines.length; lineNum++) {
      final line = lines[lineNum];
      final parts = line.split(',').map((p) => p.trim()).toList();

      if (parts.length < header.length) {
        throw Exception(
          'Row ${lineNum + 1} is missing columns. Expected ${header.length} columns, found ${parts.length}.',
        );
      }

      final rowCowId = parts[cowIdIdx];
      if (rowCowId.toUpperCase() != expectedCowId.trim().toUpperCase()) {
        throw Exception(
          'Cow ID mismatch at row ${lineNum + 1}: Found "$rowCowId", expected "$expectedCowId".',
        );
      }

      DateTime timestamp;
      try {
        timestamp = DateTime.parse(parts[timestampIdx]);
      } catch (_) {
        throw Exception(
          'Invalid ISO 8601 timestamp at row ${lineNum + 1}: "${parts[timestampIdx]}"',
        );
      }

      double parseNum(int idx, String fieldName) {
        final val = double.tryParse(parts[idx]);
        if (val == null) {
          throw Exception(
            'Invalid numeric value for $fieldName at row ${lineNum + 1}: "${parts[idx]}"',
          );
        }
        return val;
      }

      final activity = parseNum(activityIdx, 'activity');
      final skinTemp = parseNum(skinTempIdx, 'skin_temperature');
      final ambientTemp = parseNum(ambientTempIdx, 'ambient_temperature');
      final humidity = parseNum(humidityIdx, 'humidity');
      final thi = parseNum(thiIdx, 'thi');

      telemetryList.add(
        CollarTelemetry(
          timestamp: timestamp,
          activity: activity,
          skinTemperature: skinTemp,
          ambientTemperature: ambientTemp,
          humidity: humidity,
          thi: thi,
        ),
      );
    }

    return CollarHistory(cowId: expectedCowId, records: telemetryList);
  }
}
