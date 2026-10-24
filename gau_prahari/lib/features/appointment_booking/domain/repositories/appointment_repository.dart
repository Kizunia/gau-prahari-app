import '../../../vet_review/domain/entities/vet_profile.dart';
import '../entities/appointment.dart';
import '../entities/appointment_slot.dart';
import '../entities/appointment_status.dart';
import '../entities/veterinarian_schedule.dart';

/// Abstract repository defining the contract for veterinarian schedules,
/// appointment slot publishing, atomic reservations, and lifecycle transitions.
abstract class AppointmentRepository {
  /// Retrieves registered veterinarians from Firestore profiles for the booking directory.
  Future<List<VetProfile>> getVeterinarianDirectory();

  /// Retrieves a veterinarian's recurring weekly schedule.
  Future<VeterinarianSchedule?> getVeterinarianSchedule(String veterinarianUid);

  /// Saves or updates a veterinarian's recurring weekly availability.
  Future<void> saveVeterinarianSchedule(VeterinarianSchedule schedule);

  /// Publishes generated slots to Firestore.
  /// Crucially, existing booked slots are preserved and NEVER overwritten.
  Future<int> publishSlots(String veterinarianUid, List<AppointmentSlot> slots);

  /// Toggles or updates an individual slot's status (e.g. blocking or unblocking).
  Future<void> setSlotStatus({required String slotId, required SlotStatus status});

  /// Streams available time slots for a veterinarian on a specific date.
  Stream<List<AppointmentSlot>> streamSlotsForDay({
    required String veterinarianUid,
    required DateTime day,
  });

  /// Streams all upcoming available slots for a veterinarian.
  Stream<List<AppointmentSlot>> streamAvailableSlots({
    required String veterinarianUid,
    DateTime? fromDate,
  });

  /// Streams all slots (available, booked, blocked) for a veterinarian within a date range.
  Stream<List<AppointmentSlot>> streamVeterinarianSlots({
    required String veterinarianUid,
    required DateTime fromDate,
    required DateTime toDate,
  });

  /// Atomically books an appointment and reserves the selected slot.
  /// Uses a Firestore transaction to prevent double bookings (SRS FR-03, NFR-02).
  Future<Appointment> bookAppointment(Appointment appointment);

  /// Cancels an eligible appointment. Updates status to 'cancelled' and records metadata.
  Future<void> cancelAppointment({
    required String appointmentId,
    required String cancelledByUid,
    required String slotId,
  });

  /// Marks an appointment as completed. Can only be performed by the assigned veterinarian.
  Future<void> completeAppointment({
    required String appointmentId,
    required String veterinarianUid,
  });

  /// Streams real-time appointments for a farmer.
  Stream<List<Appointment>> streamFarmerAppointments(String farmerUid);

  /// Streams real-time appointments assigned to a veterinarian.
  Stream<List<Appointment>> streamVeterinarianAppointments(String veterinarianUid);

  /// Streams real-time details of a single appointment.
  Stream<Appointment?> streamAppointmentById(String appointmentId);
}
