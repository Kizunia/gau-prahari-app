import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_slot.dart';
import 'weekly_day_schedule.dart';

/// Represents a veterinarian's recurring weekly availability configuration (SRS Section 6.2).
class VeterinarianSchedule {
  final String veterinarianUid;
  final Map<int, WeeklyDaySchedule> weeklyAvailability;
  final int slotDurationMinutes;
  final String timezone;
  final DateTime updatedAt;

  const VeterinarianSchedule({
    required this.veterinarianUid,
    required this.weeklyAvailability,
    this.slotDurationMinutes = 30,
    this.timezone = 'Asia/Kolkata',
    required this.updatedAt,
  });

  /// Creates a default schedule (Mon-Fri 09:00 - 17:00, Sat 09:00 - 13:00, Sun off).
  factory VeterinarianSchedule.defaultSchedule(String veterinarianUid) {
    final map = <int, WeeklyDaySchedule>{};
    for (int day = 1; day <= 7; day++) {
      if (day <= 5) {
        map[day] = WeeklyDaySchedule(dayOfWeek: day, enabled: true, startHour: 9, endHour: 17);
      } else if (day == 6) {
        map[day] = WeeklyDaySchedule(dayOfWeek: day, enabled: true, startHour: 9, endHour: 13);
      } else {
        map[day] = WeeklyDaySchedule(dayOfWeek: day, enabled: false, startHour: 9, endHour: 17);
      }
    }
    return VeterinarianSchedule(
      veterinarianUid: veterinarianUid,
      weeklyAvailability: map,
      slotDurationMinutes: 30,
      timezone: 'Asia/Kolkata',
      updatedAt: DateTime.now(),
    );
  }

  /// Generates concrete [AppointmentSlot]s for the upcoming days (default 14 days)
  /// based on this weekly availability schedule.
  List<AppointmentSlot> generateSlotsForRange({
    DateTime? startDate,
    int daysCount = 14,
  }) {
    final start = startDate ?? DateTime.now();
    // Start from tomorrow or today's beginning
    final baseDate = DateTime(start.year, start.month, start.day);
    final List<AppointmentSlot> generated = [];
    final now = DateTime.now();

    for (int i = 0; i < daysCount; i++) {
      final currentDay = baseDate.add(Duration(days: i));
      final dayOfWeek = currentDay.weekday; // 1 = Mon, 7 = Sun
      final config = weeklyAvailability[dayOfWeek];

      if (config == null || !config.enabled) {
        continue;
      }

      final startDateTime = DateTime(
        currentDay.year,
        currentDay.month,
        currentDay.day,
        config.startHour,
        config.startMinute,
      );

      final endDateTime = DateTime(
        currentDay.year,
        currentDay.month,
        currentDay.day,
        config.endHour,
        config.endMinute,
      );

      DateTime slotStart = startDateTime;
      final step = Duration(minutes: slotDurationMinutes);

      while (slotStart.add(step).isBefore(endDateTime) ||
          slotStart.add(step).isAtSameMomentAs(endDateTime)) {
        final slotEnd = slotStart.add(step);

        // Only include future slots
        if (slotStart.isAfter(now)) {
          final slotId = AppointmentSlot.generateSlotId(veterinarianUid, slotStart);
          generated.add(
            AppointmentSlot(
              id: slotId,
              veterinarianUid: veterinarianUid,
              startAt: slotStart,
              endAt: slotEnd,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        slotStart = slotEnd;
      }
    }

    return generated;
  }

  VeterinarianSchedule copyWith({
    String? veterinarianUid,
    Map<int, WeeklyDaySchedule>? weeklyAvailability,
    int? slotDurationMinutes,
    String? timezone,
    DateTime? updatedAt,
  }) {
    return VeterinarianSchedule(
      veterinarianUid: veterinarianUid ?? this.veterinarianUid,
      weeklyAvailability: weeklyAvailability ?? this.weeklyAvailability,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      timezone: timezone ?? this.timezone,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap({bool useTimestamps = false}) {
    final availabilityMap = <String, dynamic>{};
    weeklyAvailability.forEach((day, sched) {
      availabilityMap[day.toString()] = sched.toMap();
    });

    return {
      'veterinarianUid': veterinarianUid,
      'weeklyAvailability': availabilityMap,
      'slotDurationMinutes': slotDurationMinutes,
      'timezone': timezone,
      'updatedAt': useTimestamps ? Timestamp.fromDate(updatedAt) : updatedAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  factory VeterinarianSchedule.fromFirestore(Map<String, dynamic> data, String id) {
    final rawMap = data['weeklyAvailability'] as Map<String, dynamic>? ?? {};
    final map = <int, WeeklyDaySchedule>{};

    for (int day = 1; day <= 7; day++) {
      if (rawMap.containsKey(day.toString())) {
        map[day] = WeeklyDaySchedule.fromMap(
          rawMap[day.toString()] as Map<String, dynamic>,
          day,
        );
      } else {
        map[day] = WeeklyDaySchedule(dayOfWeek: day, enabled: false);
      }
    }

    return VeterinarianSchedule(
      veterinarianUid: id,
      weeklyAvailability: map,
      slotDurationMinutes: (data['slotDurationMinutes'] as num?)?.toInt() ?? 30,
      timezone: data['timezone'] as String? ?? 'Asia/Kolkata',
      updatedAt: _parseDate(data['updatedAt']),
    );
  }
}
