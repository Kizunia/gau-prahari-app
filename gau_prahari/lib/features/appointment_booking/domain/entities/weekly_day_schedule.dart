/// Represents a veterinarian's configured working hours for a specific day of the week.
class WeeklyDaySchedule {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday (matches DateTime.weekday)
  final bool enabled;
  final int startHour; // 0..23
  final int startMinute; // 0..59
  final int endHour; // 0..23
  final int endMinute; // 0..59

  const WeeklyDaySchedule({
    required this.dayOfWeek,
    this.enabled = true,
    this.startHour = 9,
    this.startMinute = 0,
    this.endHour = 17,
    this.endMinute = 0,
  });

  static const List<String> dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> shortDayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String get dayName => dayNames[dayOfWeek - 1];
  String get shortDayName => shortDayNames[dayOfWeek - 1];

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  String get formattedRange =>
      enabled ? '${_formatTime(startHour, startMinute)} - ${_formatTime(endHour, endMinute)}' : 'Unavailable';

  int get totalMinutesAvailable {
    if (!enabled) return 0;
    final startTotal = startHour * 60 + startMinute;
    final endTotal = endHour * 60 + endMinute;
    return endTotal > startTotal ? endTotal - startTotal : 0;
  }

  WeeklyDaySchedule copyWith({
    int? dayOfWeek,
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return WeeklyDaySchedule(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'enabled': enabled,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  factory WeeklyDaySchedule.fromMap(Map<String, dynamic> map, int dayOfWeek) {
    return WeeklyDaySchedule(
      dayOfWeek: dayOfWeek,
      enabled: map['enabled'] as bool? ?? true,
      startHour: (map['startHour'] as num?)?.toInt() ?? 9,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (map['endHour'] as num?)?.toInt() ?? 17,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyDaySchedule &&
          dayOfWeek == other.dayOfWeek &&
          enabled == other.enabled &&
          startHour == other.startHour &&
          startMinute == other.startMinute &&
          endHour == other.endHour &&
          endMinute == other.endMinute;

  @override
  int get hashCode => Object.hash(
        dayOfWeek,
        enabled,
        startHour,
        startMinute,
        endHour,
        endMinute,
      );
}
