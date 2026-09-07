/// Domain entity representing a point-of-care milk sample measurement.
class MilkMeasurement {
  final String cowId;
  final double milkTemperature; // °C (physiologically 30.0 - 45.0)
  final double ph; // pH (physiologically 6.0 - 7.5, normal 6.5 - 6.8)
  final double conductivity; // mS/cm (normal 4.5 - 5.8, mastitis > 6.0)
  final int scc; // Somatic Cell Count cells/mL (<200k normal, >400k clinical)
  final double fat; // Fat percentage (e.g. 3.5 - 5.0%)
  final double snf; // Solids-not-fat percentage (e.g. 8.0 - 9.5%)
  final DateTime timestamp;

  MilkMeasurement({
    required this.cowId,
    required this.milkTemperature,
    required this.ph,
    required this.conductivity,
    required this.scc,
    required this.fat,
    required this.snf,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Physical physiological plausibility checks
  bool get isValid => validationErrors.isEmpty;

  List<String> get validationErrors {
    final errors = <String>[];
    if (cowId.trim().isEmpty) {
      errors.add('Cow ID cannot be empty');
    }
    if (milkTemperature < 25.0 || milkTemperature > 45.0) {
      errors.add('Milk temperature (${milkTemperature.toStringAsFixed(1)} °C) is outside physiological range (25-45 °C)');
    }
    if (ph < 5.5 || ph > 8.0) {
      errors.add('Milk pH (${ph.toStringAsFixed(2)}) is outside plausible range (5.5 - 8.0)');
    }
    if (conductivity < 2.0 || conductivity > 15.0) {
      errors.add('Electrical conductivity (${conductivity.toStringAsFixed(2)} mS/cm) is out of range');
    }
    if (scc < 0) {
      errors.add('Somatic Cell Count cannot be negative');
    }
    if (fat < 0.0 || fat > 15.0) {
      errors.add('Fat percentage (${fat.toStringAsFixed(1)}%) is out of range (0-15%)');
    }
    if (snf < 0.0 || snf > 20.0) {
      errors.add('SNF percentage (${snf.toStringAsFixed(1)}%) is out of range (0-20%)');
    }
    return errors;
  }

  // Clinical risk flags for diagnostic presentation
  bool get isSccElevated => scc > 250000;
  bool get isConductivityElevated => conductivity > 5.8;
  bool get isPhAbnormal => ph < 6.4 || ph > 6.9;

  Map<String, dynamic> toJson() {
    return {
      'cow_id': cowId,
      'milk_temperature': milkTemperature,
      'ph': ph,
      'conductivity': conductivity,
      'scc': scc,
      'fat': fat,
      'snf': snf,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MilkMeasurement.fromJson(Map<String, dynamic> json) {
    return MilkMeasurement(
      cowId: json['cow_id'] as String? ?? '',
      milkTemperature: (json['milk_temperature'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      conductivity: (json['conductivity'] as num).toDouble(),
      scc: (json['scc'] as num).toInt(),
      fat: (json['fat'] as num).toDouble(),
      snf: (json['snf'] as num).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }
}
