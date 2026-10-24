import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_status.dart';

/// Represents a concrete appointment time slot (SRS Section 6.3).
class AppointmentSlot {
  final String id;
  final String veterinarianUid;
  final DateTime startAt;
  final DateTime endAt;
  final SlotStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppointmentSlot({
    required this.id,
    required this.veterinarianUid,
    required this.startAt,
    required this.endAt,
    this.status = SlotStatus.available,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deterministic ID generator ensuring republishing never duplicates slots.
  static String generateSlotId(String veterinarianUid, DateTime startAt) {
    return '${veterinarianUid}_${startAt.millisecondsSinceEpoch}';
  }

  int get durationMinutes => endAt.difference(startAt).inMinutes;

  String _formatTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final h12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final mStr = dt.minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  String get timeRangeString => '${_formatTime(startAt)} - ${_formatTime(endAt)}';

  String get dateString =>
      '${startAt.day.toString().padLeft(2, '0')}/${startAt.month.toString().padLeft(2, '0')}/${startAt.year}';

  bool get isAvailable => status.isAvailable;
  bool get isBooked => status.isBooked;
  bool get isBlocked => status.isBlocked;

  AppointmentSlot copyWith({
    String? id,
    String? veterinarianUid,
    DateTime? startAt,
    DateTime? endAt,
    SlotStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentSlot(
      id: id ?? this.id,
      veterinarianUid: veterinarianUid ?? this.veterinarianUid,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap({bool useTimestamps = false}) {
    return {
      'veterinarianUid': veterinarianUid,
      'startAt': useTimestamps ? Timestamp.fromDate(startAt) : startAt.toIso8601String(),
      'endAt': useTimestamps ? Timestamp.fromDate(endAt) : endAt.toIso8601String(),
      'status': status.key,
      'createdAt': useTimestamps ? Timestamp.fromDate(createdAt) : createdAt.toIso8601String(),
      'updatedAt': useTimestamps ? Timestamp.fromDate(updatedAt) : updatedAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  factory AppointmentSlot.fromFirestore(Map<String, dynamic> data, String id) {
    return AppointmentSlot(
      id: id,
      veterinarianUid: data['veterinarianUid'] as String? ?? '',
      startAt: _parseDate(data['startAt']),
      endAt: _parseDate(data['endAt']),
      status: SlotStatus.fromString(data['status'] as String?),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentSlot &&
          id == other.id &&
          veterinarianUid == other.veterinarianUid &&
          startAt == other.startAt &&
          endAt == other.endAt &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, veterinarianUid, startAt, endAt, status);
}
