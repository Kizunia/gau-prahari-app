import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Lifecycle statuses for an appointment in Gau-Prahari (SRS Section 5).
enum AppointmentStatus {
  booked,
  cancelled,
  completed;

  static AppointmentStatus fromString(String? value) {
    if (value == null) return AppointmentStatus.booked;
    final lower = value.toLowerCase().trim();
    switch (lower) {
      case 'cancelled':
      case 'canceled':
        return AppointmentStatus.cancelled;
      case 'completed':
        return AppointmentStatus.completed;
      case 'booked':
      default:
        return AppointmentStatus.booked;
    }
  }

  String get key => name;

  String get label {
    switch (this) {
      case AppointmentStatus.booked:
        return 'Confirmed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.completed:
        return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case AppointmentStatus.booked:
        return AppColors.primary;
      case AppointmentStatus.cancelled:
        return AppColors.error;
      case AppointmentStatus.completed:
        return AppColors.success;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AppointmentStatus.booked:
        return AppColors.primaryLight;
      case AppointmentStatus.cancelled:
        return AppColors.errorLight;
      case AppointmentStatus.completed:
        return AppColors.successLight;
    }
  }

  bool get isBooked => this == AppointmentStatus.booked;
  bool get isCancelled => this == AppointmentStatus.cancelled;
  bool get isCompleted => this == AppointmentStatus.completed;
  bool get isTerminal => isCancelled || isCompleted;
  bool get canCancel => isBooked;
  bool get canComplete => isBooked;
}

/// Status of an appointment time slot.
enum SlotStatus {
  available,
  booked,
  blocked;

  static SlotStatus fromString(String? value) {
    if (value == null) return SlotStatus.available;
    final lower = value.toLowerCase().trim();
    switch (lower) {
      case 'booked':
        return SlotStatus.booked;
      case 'blocked':
        return SlotStatus.blocked;
      case 'available':
      default:
        return SlotStatus.available;
    }
  }

  String get key => name;

  String get label {
    switch (this) {
      case SlotStatus.available:
        return 'Available';
      case SlotStatus.booked:
        return 'Booked';
      case SlotStatus.blocked:
        return 'Blocked';
    }
  }

  bool get isAvailable => this == SlotStatus.available;
  bool get isBooked => this == SlotStatus.booked;
  bool get isBlocked => this == SlotStatus.blocked;
}
