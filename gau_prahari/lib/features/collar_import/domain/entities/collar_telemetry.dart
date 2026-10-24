/// Domain entity representing a single point-in-time telemetry reading from the smart collar.
class CollarTelemetry {
  final DateTime timestamp;
  final double activity; // e.g., 0 - 100 activity index
  final double skinTemperature; // degrees Celsius (°C)
  final double ambientTemperature; // degrees Celsius (°C)
  final double humidity; // relative humidity (%)
  final double thi; // Temperature Humidity Index

  const CollarTelemetry({
    required this.timestamp,
    required this.activity,
    required this.skinTemperature,
    required this.ambientTemperature,
    required this.humidity,
    required this.thi,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'activity': activity,
      'skin_temperature': skinTemperature,
      'ambient_temperature': ambientTemperature,
      'humidity': humidity,
      'thi': thi,
    };
  }

  factory CollarTelemetry.fromJson(Map<String, dynamic> json) {
    return CollarTelemetry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      activity: (json['activity'] as num).toDouble(),
      skinTemperature: (json['skin_temperature'] as num).toDouble(),
      ambientTemperature: (json['ambient_temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      thi: (json['thi'] as num).toDouble(),
    );
  }
}

/// Domain entity representing historical longitudinal telemetry collected for a specific cow.
class CollarHistory {
  final String cowId;
  final List<CollarTelemetry> records;

  const CollarHistory({required this.cowId, required this.records});

  int get recordCount => records.length;

  bool get isEmpty => records.isEmpty;
  bool get isNotEmpty => records.isNotEmpty;

  double get meanActivity {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.activity).reduce((a, b) => a + b) /
        records.length;
  }

  double get meanSkinTemperature {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.skinTemperature).reduce((a, b) => a + b) /
        records.length;
  }

  double get meanAmbientTemperature {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.ambientTemperature).reduce((a, b) => a + b) /
        records.length;
  }

  double get meanHumidity {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.humidity).reduce((a, b) => a + b) /
        records.length;
  }

  double get meanThi {
    if (records.isEmpty) return 0.0;
    return records.map((r) => r.thi).reduce((a, b) => a + b) / records.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'cow_id': cowId,
      'records': records.map((r) => r.toJson()).toList(),
    };
  }

  factory CollarHistory.fromJson(Map<String, dynamic> json) {
    final rawList = json['records'] as List<dynamic>? ?? [];
    return CollarHistory(
      cowId: json['cow_id'] as String,
      records: rawList
          .map((item) => CollarTelemetry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
