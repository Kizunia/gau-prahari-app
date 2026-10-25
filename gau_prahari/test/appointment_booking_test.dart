import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/appointment_booking/data/repositories/firestore_appointment_repository.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/appointment.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/appointment_slot.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/appointment_status.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/google_meet_link.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/veterinarian_schedule.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/weekly_day_schedule.dart';

void main() {
  group('11.1 Schedule & Slot Generation Tests (SRS 11.1)', () {
    test('A valid weekly schedule generates correctly sized 30-minute slots', () {
      final schedule = VeterinarianSchedule(
        veterinarianUid: 'vet_101',
        weeklyAvailability: {
          DateTime.monday: const WeeklyDaySchedule(
            dayOfWeek: DateTime.monday,
            enabled: true,
            startHour: 9,
            startMinute: 0,
            endHour: 11,
            endMinute: 0,
          ),
        },
        slotDurationMinutes: 30,
        updatedAt: DateTime(2026, 10, 25),
      );

      // Monday 9:00 - 11:00 should yield exactly 4 slots: 9:00, 9:30, 10:00, 10:30
      final monday = DateTime(2026, 10, 26, 0, 0); // Next Monday
      final slots = schedule.generateSlotsForRange(startDate: monday, daysCount: 1);

      expect(slots.length, equals(4));
      expect(slots[0].durationMinutes, equals(30));
      expect(slots[0].startAt.hour, equals(9));
      expect(slots[0].startAt.minute, equals(0));
      expect(slots[3].startAt.hour, equals(10));
      expect(slots[3].startAt.minute, equals(30));
      expect(slots[3].endAt.hour, equals(11));
      expect(slots[3].endAt.minute, equals(0));
    });

    test('Slots do not extend beyond configured working hours', () {
      final schedule = VeterinarianSchedule(
        veterinarianUid: 'vet_101',
        weeklyAvailability: {
          DateTime.monday: const WeeklyDaySchedule(
            dayOfWeek: DateTime.monday,
            enabled: true,
            startHour: 14,
            startMinute: 0,
            endHour: 15,
            endMinute: 15, // 1 hour 15 mins -> only two 30-min slots fit (14:00-14:30, 14:30-15:00)
          ),
        },
        slotDurationMinutes: 30,
        updatedAt: DateTime(2026, 10, 25),
      );

      final monday = DateTime(2026, 10, 26, 0, 0);
      final slots = schedule.generateSlotsForRange(startDate: monday, daysCount: 1);

      expect(slots.length, equals(2));
      expect(slots.last.endAt.hour, equals(15));
      expect(slots.last.endAt.minute, equals(0));
      expect(slots.last.endAt.isBefore(DateTime(2026, 10, 26, 15, 16)), isTrue);
    });

    test('Duplicate schedule publishing produces identical deterministic slot IDs', () {
      final schedule = VeterinarianSchedule.defaultSchedule('vet_101');
      final monday = DateTime(2026, 10, 26, 0, 0);

      final run1 = schedule.generateSlotsForRange(startDate: monday, daysCount: 7);
      final run2 = schedule.generateSlotsForRange(startDate: monday, daysCount: 7);

      expect(run1.length, equals(run2.length));
      for (int i = 0; i < run1.length; i++) {
        expect(run1[i].id, equals(run2[i].id));
      }
    });

    test('Disabled days do not generate bookable slots', () {
      final schedule = VeterinarianSchedule(
        veterinarianUid: 'vet_101',
        weeklyAvailability: {
          DateTime.sunday: const WeeklyDaySchedule(
            dayOfWeek: DateTime.sunday,
            enabled: false,
          ),
        },
        updatedAt: DateTime.now(),
      );

      final sunday = DateTime(2026, 11, 1, 0, 0); // Sunday
      final slots = schedule.generateSlotsForRange(startDate: sunday, daysCount: 1);
      expect(slots, isEmpty);
    });
  });

  group('11.2 Booking & Double-Booking Prevention Tests (SRS 11.2)', () {
    late FirestoreAppointmentRepository repo;

    setUp(() {
      repo = FirestoreAppointmentRepository(isDemo: true);
    });

    test('Farmer can successfully book an available slot', () async {
      final slotStart = DateTime.now().add(const Duration(days: 1, hours: 10));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slot = AppointmentSlot(
        id: 'slot_test_001',
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.publishSlots('demo_vet_001', [slot]);

      final appointment = Appointment(
        id: 'appt_test_001',
        farmerUid: 'farmer_001',
        farmerNameSnapshot: 'Ramesh Patel',
        veterinarianUid: 'demo_vet_001',
        veterinarianNameSnapshot: 'Dr. Sharma, DVM',
        slotId: slot.id,
        startAt: slotStart,
        endAt: slotEnd,
        status: AppointmentStatus.booked,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await repo.bookAppointment(appointment);
      expect(result.id, equals('appt_test_001'));
      expect(result.status, equals(AppointmentStatus.booked));

      // Verify the slot is now marked as booked
      final slots = await repo.streamSlotsForDay(
        veterinarianUid: 'demo_vet_001',
        day: slotStart,
      ).first;
      final bookedSlot = slots.firstWhere((s) => s.id == slot.id);
      expect(bookedSlot.status, equals(SlotStatus.booked));
    });

    test('Farmer cannot book an already booked slot (double-booking prevented)', () async {
      final slotStart = DateTime.now().add(const Duration(days: 1, hours: 11));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slot = AppointmentSlot(
        id: 'slot_test_conflict',
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.publishSlots('demo_vet_001', [slot]);

      // First farmer books the slot
      final appt1 = Appointment(
        id: 'appt_farmer_1',
        farmerUid: 'farmer_001',
        farmerNameSnapshot: 'Farmer 1',
        veterinarianUid: 'demo_vet_001',
        veterinarianNameSnapshot: 'Dr. Sharma',
        slotId: slot.id,
        startAt: slotStart,
        endAt: slotEnd,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.bookAppointment(appt1);

      // Second farmer attempts to book the same slot
      final appt2 = Appointment(
        id: 'appt_farmer_2',
        farmerUid: 'farmer_002',
        farmerNameSnapshot: 'Farmer 2',
        veterinarianUid: 'demo_vet_001',
        veterinarianNameSnapshot: 'Dr. Sharma',
        slotId: slot.id,
        startAt: slotStart,
        endAt: slotEnd,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () async => await repo.bookAppointment(appt2),
        throwsA(isA<Exception>()),
      );
    });

    test('Existing booked slots survive schedule republishing', () async {
      final slotStart = DateTime.now().add(const Duration(days: 2, hours: 10));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slotId = 'slot_survive_republish';

      final slot = AppointmentSlot(
        id: slotId,
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.publishSlots('demo_vet_001', [slot]);

      // Book it
      await repo.bookAppointment(
        Appointment(
          id: 'appt_survive',
          farmerUid: 'farmer_001',
          farmerNameSnapshot: 'Farmer 1',
          veterinarianUid: 'demo_vet_001',
          veterinarianNameSnapshot: 'Dr. Sharma',
          slotId: slotId,
          startAt: slotStart,
          endAt: slotEnd,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Republish schedule including this same slot as available
      await repo.publishSlots('demo_vet_001', [
        AppointmentSlot(
          id: slotId,
          veterinarianUid: 'demo_vet_001',
          startAt: slotStart,
          endAt: slotEnd,
          status: SlotStatus.available,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      // The slot MUST remain booked!
      final slots = await repo.streamSlotsForDay(
        veterinarianUid: 'demo_vet_001',
        day: slotStart,
      ).first;
      final checked = slots.firstWhere((s) => s.id == slotId);
      expect(checked.status, equals(SlotStatus.booked));
    });
  });

  group('11.4 Lifecycle & Status Transition Tests (SRS 11.4)', () {
    late FirestoreAppointmentRepository repo;

    setUp(() {
      repo = FirestoreAppointmentRepository(isDemo: true);
    });

    test('Farmer can cancel an eligible upcoming appointment and free the slot', () async {
      final slotStart = DateTime.now().add(const Duration(days: 1, hours: 14));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slot = AppointmentSlot(
        id: 'slot_cancel_test',
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.publishSlots('demo_vet_001', [slot]);

      await repo.bookAppointment(
        Appointment(
          id: 'appt_to_cancel',
          farmerUid: 'farmer_001',
          farmerNameSnapshot: 'Farmer 1',
          veterinarianUid: 'demo_vet_001',
          veterinarianNameSnapshot: 'Dr. Sharma',
          slotId: slot.id,
          startAt: slotStart,
          endAt: slotEnd,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Cancel appointment
      await repo.cancelAppointment(
        appointmentId: 'appt_to_cancel',
        cancelledByUid: 'farmer_001',
        slotId: slot.id,
      );

      final appt = await repo.streamAppointmentById('appt_to_cancel').first;
      expect(appt!.status, equals(AppointmentStatus.cancelled));
      expect(appt.cancelledByUid, equals('farmer_001'));
      expect(appt.isCancelled, isTrue);

      // Slot is released back to available
      final slots = await repo.streamSlotsForDay(
        veterinarianUid: 'demo_vet_001',
        day: slotStart,
      ).first;
      final releasedSlot = slots.firstWhere((s) => s.id == slot.id);
      expect(releasedSlot.status, equals(SlotStatus.available));
    });

    test('Veterinarian can mark consultation as completed', () async {
      final slotStart = DateTime.now().add(const Duration(days: 1, hours: 16));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slot = AppointmentSlot(
        id: 'slot_complete_test',
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.publishSlots('demo_vet_001', [slot]);

      await repo.bookAppointment(
        Appointment(
          id: 'appt_to_complete',
          farmerUid: 'farmer_001',
          farmerNameSnapshot: 'Farmer 1',
          veterinarianUid: 'demo_vet_001',
          veterinarianNameSnapshot: 'Dr. Sharma',
          slotId: slot.id,
          startAt: slotStart,
          endAt: slotEnd,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Complete consultation
      await repo.completeAppointment(
        appointmentId: 'appt_to_complete',
        veterinarianUid: 'demo_vet_001',
      );

      final appt = await repo.streamAppointmentById('appt_to_complete').first;
      expect(appt!.status, equals(AppointmentStatus.completed));
      expect(appt.isCompleted, isTrue);
    });

    test('Veterinarian can block and unblock individual slots', () async {
      final slotStart = DateTime.now().add(const Duration(days: 3, hours: 9));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slot = AppointmentSlot(
        id: 'slot_block_toggle',
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.publishSlots('demo_vet_001', [slot]);

      // Block slot
      await repo.setSlotStatus(slotId: slot.id, status: SlotStatus.blocked);
      var slots = await repo.streamSlotsForDay(
        veterinarianUid: 'demo_vet_001',
        day: slotStart,
      ).first;
      expect(slots.firstWhere((s) => s.id == slot.id).status, equals(SlotStatus.blocked));

      // Unblock slot
      await repo.setSlotStatus(slotId: slot.id, status: SlotStatus.available);
      slots = await repo.streamSlotsForDay(
        veterinarianUid: 'demo_vet_001',
        day: slotStart,
      ).first;
      expect(slots.firstWhere((s) => s.id == slot.id).status, equals(SlotStatus.available));
    });
  });

  group('Shared veterinarian Google Meet link', () {
    late FirestoreAppointmentRepository repo;

    setUp(() {
      repo = FirestoreAppointmentRepository(isDemo: true);
    });

    test('one veterinarian link is available to every appointment', () async {
      const meetLink = 'https://meet.google.com/abc-defg-hij';

      await repo.saveVeterinarianMeetLink(
        veterinarianUid: 'demo_vet_001',
        meetLink: meetLink,
      );

      expect(await repo.getVeterinarianMeetLink('demo_vet_001'), meetLink);
      expect(
        await repo.streamVeterinarianMeetLink('demo_vet_001').first,
        meetLink,
      );
    });

    test('a veterinarian can clear the shared link', () async {
      await repo.saveVeterinarianMeetLink(
        veterinarianUid: 'demo_vet_001',
        meetLink: 'https://meet.google.com/abc-defg-hij',
      );

      await repo.saveVeterinarianMeetLink(
        veterinarianUid: 'demo_vet_001',
        meetLink: '',
      );

      expect(await repo.getVeterinarianMeetLink('demo_vet_001'), isNull);
    });

    test('only HTTPS Google Meet links are accepted', () async {
      expect(
        GoogleMeetLink.normalize('https://meet.google.com/abc-defg-hij'),
        'https://meet.google.com/abc-defg-hij',
      );
      expect(GoogleMeetLink.normalize('https://example.com/meeting'), isNull);
      expect(GoogleMeetLink.normalize('http://meet.google.com/meeting'), isNull);

      await expectLater(
        repo.saveVeterinarianMeetLink(
          veterinarianUid: 'demo_vet_001',
          meetLink: 'https://example.com/meeting',
        ),
        throwsArgumentError,
      );
    });
  });
}
