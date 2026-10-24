import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment_status.dart';

/// Domain entity representing a confirmed, completed, or cancelled consultation booking (SRS Section 6.4).
class Appointment {
  final String id;
  final String farmerUid;
  final String farmerNameSnapshot;
  final String veterinarianUid;
  final String veterinarianNameSnapshot;
  final String slotId;
  final String? cowId;
  final String? cowTagNumber;
  final String? reviewRequestId;
  final DateTime startAt;
  final DateTime endAt;
  final AppointmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? cancelledByUid;
  final DateTime? cancelledAt;
  final DateTime? completedAt;

  const Appointment({
    required this.id,
    required this.farmerUid,
    required this.farmerNameSnapshot,
    required this.veterinarianUid,
    required this.veterinarianNameSnapshot,
    required this.slotId,
    this.cowId,
    this.cowTagNumber,
    this.reviewRequestId,
    required this.startAt,
    required this.endAt,
    this.status = AppointmentStatus.booked,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.cancelledByUid,
    this.cancelledAt,
    this.completedAt,
  });

  bool get isBooked => status.isBooked;
  bool get isCancelled => status.isCancelled;
  bool get isCompleted => status.isCompleted;
  bool get hasLinkedReview => reviewRequestId != null && reviewRequestId!.trim().isNotEmpty;
  bool get hasLinkedCow => (cowTagNumber != null && cowTagNumber!.isNotEmpty) || (cowId != null && cowId!.isNotEmpty);

  String _formatTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final h12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final mStr = dt.minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  String get timeRangeString => '${_formatTime(startAt)} - ${_formatTime(endAt)}';

  String get dateString =>
      '${startAt.day.toString().padLeft(2, '0')}/${startAt.month.toString().padLeft(2, '0')}/${startAt.year}';

  Appointment copyWith({
    String? id,
    String? farmerUid,
    String? farmerNameSnapshot,
    String? veterinarianUid,
    String? veterinarianNameSnapshot,
    String? slotId,
    String? cowId,
    String? cowTagNumber,
    String? reviewRequestId,
    DateTime? startAt,
    DateTime? endAt,
    AppointmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? cancelledByUid,
    DateTime? cancelledAt,
    DateTime? completedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      farmerUid: farmerUid ?? this.farmerUid,
      farmerNameSnapshot: farmerNameSnapshot ?? this.farmerNameSnapshot,
      veterinarianUid: veterinarianUid ?? this.veterinarianUid,
      veterinarianNameSnapshot: veterinarianNameSnapshot ?? this.veterinarianNameSnapshot,
      slotId: slotId ?? this.slotId,
      cowId: cowId ?? this.cowId,
      cowTagNumber: cowTagNumber ?? this.cowTagNumber,
      reviewRequestId: reviewRequestId ?? this.reviewRequestId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledByUid: cancelledByUid ?? this.cancelledByUid,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap({bool useTimestamps = false}) {
    return {
      'farmerUid': farmerUid,
      'farmerNameSnapshot': farmerNameSnapshot,
      'veterinarianUid': veterinarianUid,
      'veterinarianNameSnapshot': veterinarianNameSnapshot,
      'slotId': slotId,
      'cowId': cowId,
      'cowTagNumber': cowTagNumber,
      'reviewRequestId': reviewRequestId,
      'startAt': useTimestamps ? Timestamp.fromDate(startAt) : startAt.toIso8601String(),
      'endAt': useTimestamps ? Timestamp.fromDate(endAt) : endAt.toIso8601String(),
      'status': status.key,
      'notes': notes,
      'createdAt': useTimestamps ? Timestamp.fromDate(createdAt) : createdAt.toIso8601String(),
      'updatedAt': useTimestamps ? Timestamp.fromDate(updatedAt) : updatedAt.toIso8601String(),
      'cancelledByUid': cancelledByUid,
      'cancelledAt': cancelledAt != null
          ? (useTimestamps ? Timestamp.fromDate(cancelledAt!) : cancelledAt!.toIso8601String())
          : null,
      'completedAt': completedAt != null
          ? (useTimestamps ? Timestamp.fromDate(completedAt!) : completedAt!.toIso8601String())
          : null,
    };
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  factory Appointment.fromFirestore(Map<String, dynamic> data, String id) {
    return Appointment(
      id: id,
      farmerUid: data['farmerUid'] as String? ?? '',
      farmerNameSnapshot: data['farmerNameSnapshot'] as String? ?? 'Farmer',
      veterinarianUid: data['veterinarianUid'] as String? ?? '',
      veterinarianNameSnapshot: data['veterinarianNameSnapshot'] as String? ?? 'Veterinarian',
      slotId: data['slotId'] as String? ?? '',
      cowId: data['cowId'] as String?,
      cowTagNumber: data['cowTagNumber'] as String?,
      reviewRequestId: data['reviewRequestId'] as String?,
      startAt: _parseDate(data['startAt']),
      endAt: _parseDate(data['endAt']),
      status: AppointmentStatus.fromString(data['status'] as String?),
      notes: data['notes'] as String?,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      cancelledByUid: data['cancelledByUid'] as String?,
      cancelledAt: _parseNullableDate(data['cancelledAt']),
      completedAt: _parseNullableDate(data['completedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Appointment &&
          id == other.id &&
          farmerUid == other.farmerUid &&
          veterinarianUid == other.veterinarianUid &&
          slotId == other.slotId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, farmerUid, veterinarianUid, slotId, status);
}
