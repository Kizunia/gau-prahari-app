import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../vet_review/domain/entities/vet_profile.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_slot.dart';
import '../../domain/entities/appointment_status.dart';
import '../../domain/entities/veterinarian_schedule.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Firestore implementation of [AppointmentRepository] complying with SRS Section 5, 6, and 7.
/// Implements atomic double-booking prevention, schedule management, and isolated demo mode.
class FirestoreAppointmentRepository implements AppointmentRepository {
  final FirebaseFirestore? _firestore;
  final bool? _isDemoStatic;
  final AuthController? _authController;

  // In-memory state for isolated demo sessions (SRS Section 9)
  final Map<String, VeterinarianSchedule> _demoSchedules = {};
  final Map<String, AppointmentSlot> _demoSlots = {};
  final Map<String, Appointment> _demoAppointments = {};

  FirestoreAppointmentRepository({
    FirebaseFirestore? firestore,
    bool? isDemo,
    AuthController? authController,
  })  : _firestore = firestore,
        _isDemoStatic = isDemo,
        _authController = authController {
    _initDemoData();
  }

  bool get isDemo =>
      _authController?.currentUser?.isDemo ?? (_isDemoStatic ?? false);

  void _initDemoData() {
    final sched = VeterinarianSchedule.defaultSchedule('demo_vet_001');
    _demoSchedules['demo_vet_001'] = sched;
    final defaultSlots = sched.generateSlotsForRange(daysCount: 14);
    for (final s in defaultSlots) {
      _demoSlots[s.id] = s;
    }
  }

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _schedulesCol =>
      _db.collection('veterinarianSchedules');

  CollectionReference<Map<String, dynamic>> get _slotsCol =>
      _db.collection('appointmentSlots');

  CollectionReference<Map<String, dynamic>> get _appointmentsCol =>
      _db.collection('appointments');

  @override
  Future<List<VetProfile>> getVeterinarianDirectory() async {
    if (isDemo) {
      return const [
        VetProfile(
          uid: 'demo_vet_001',
          name: 'Dr. Sharma, DVM',
          email: 'vet@gauprahari.org',
          designation: 'Senior Bovine Veterinarian',
        ),
        VetProfile(
          uid: 'demo_vet_002',
          name: 'Dr. Ananya Rao, MVSc',
          email: 'ananya.vet@gauprahari.org',
          designation: 'Field Cattle Health Officer',
        ),
      ];
    }

    try {
      final snapshot = await _usersCol
          .where('role', isEqualTo: 'veterinarian')
          .get();
      final vets = snapshot.docs
          .map((doc) => VetProfile.fromFirestore(doc.data(), doc.id))
          .toList();
      if (vets.isEmpty) {
        // Fallback to sample certified veterinarians if none registered yet
        return const [
          VetProfile(
            uid: 'demo_vet_001',
            name: 'Dr. Sharma, DVM',
            email: 'vet@gauprahari.org',
            designation: 'Senior Bovine Veterinarian',
          ),
          VetProfile(
            uid: 'demo_vet_002',
            name: 'Dr. Ananya Rao, MVSc',
            email: 'ananya.vet@gauprahari.org',
            designation: 'Field Cattle Health Officer',
          ),
        ];
      }
      return vets;
    } catch (_) {
      return const [
        VetProfile(
          uid: 'demo_vet_001',
          name: 'Dr. Sharma, DVM',
          email: 'vet@gauprahari.org',
          designation: 'Senior Bovine Veterinarian',
        ),
        VetProfile(
          uid: 'demo_vet_002',
          name: 'Dr. Ananya Rao, MVSc',
          email: 'ananya.vet@gauprahari.org',
          designation: 'Field Cattle Health Officer',
        ),
      ];
    }
  }

  @override
  Future<VeterinarianSchedule?> getVeterinarianSchedule(String veterinarianUid) async {
    if (isDemo) {
      return _demoSchedules[veterinarianUid] ??
          VeterinarianSchedule.defaultSchedule(veterinarianUid);
    }

    try {
      final doc = await _schedulesCol.doc(veterinarianUid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return VeterinarianSchedule.fromFirestore(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveVeterinarianSchedule(VeterinarianSchedule schedule) async {
    debugPrint('[AppointmentBooking] Saving schedule for vet: ${schedule.veterinarianUid} (isDemo=$isDemo)');
    if (isDemo) {
      _demoSchedules[schedule.veterinarianUid] = schedule;
      return;
    }

    final data = schedule.toMap(useTimestamps: true);
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _schedulesCol.doc(schedule.veterinarianUid).set(data, SetOptions(merge: true));
    debugPrint('[AppointmentBooking] Schedule saved successfully in Firestore for: ${schedule.veterinarianUid}');
  }

  @override
  Future<int> publishSlots(String veterinarianUid, List<AppointmentSlot> slots) async {
    if (slots.isEmpty) {
      debugPrint('[AppointmentBooking] publishSlots called with empty slots list for $veterinarianUid');
      return 0;
    }
    debugPrint('[AppointmentBooking] Publishing ${slots.length} slots for vet: $veterinarianUid (isDemo=$isDemo)');

    if (isDemo) {
      int count = 0;
      for (final slot in slots) {
        // Do not overwrite existing booked slots in demo mode
        final existing = _demoSlots[slot.id];
        if (existing == null || existing.status != SlotStatus.booked) {
          _demoSlots[slot.id] = slot;
          count++;
        }
      }
      debugPrint('[AppointmentBooking] Published $count slots in local demo storage');
      return count;
    }

    int publishedCount = 0;
    // Batch writes in chunks of 300 to respect Firestore limit of 500
    const chunkSize = 300;
    for (int i = 0; i < slots.length; i += chunkSize) {
      final chunk = slots.sublist(
        i,
        i + chunkSize > slots.length ? slots.length : i + chunkSize,
      );

      final batch = _db.batch();

      for (final slot in chunk) {
        final docRef = _slotsCol.doc(slot.id);
        final data = slot.toMap(useTimestamps: true);
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        batch.set(docRef, data, SetOptions(merge: true));
        publishedCount++;
      }

      await batch.commit();
      debugPrint('[AppointmentBooking] Committed batch chunk (${chunk.length} slots). Total published: $publishedCount');
    }

    debugPrint('[AppointmentBooking] Successfully published total $publishedCount slots to Cloud Firestore');
    return publishedCount;
  }

  @override
  Future<void> setSlotStatus({
    required String slotId,
    required SlotStatus status,
  }) async {
    debugPrint('[AppointmentBooking] Updating slot $slotId status to ${status.key} (isDemo=$isDemo)');
    if (isDemo) {
      final slot = _demoSlots[slotId];
      if (slot != null) {
        _demoSlots[slotId] = slot.copyWith(status: status, updatedAt: DateTime.now());
      }
      return;
    }

    await _slotsCol.doc(slotId).update({
      'status': status.key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<AppointmentSlot>> streamSlotsForDay({
    required String veterinarianUid,
    required DateTime day,
  }) {
    final localDay = day.toLocal();
    debugPrint('[AppointmentBooking] streamSlotsForDay: vet=$veterinarianUid, day=${localDay.year}-${localDay.month}-${localDay.day} (isDemo=$isDemo)');

    if (isDemo) {
      final slots = _demoSlots.values
          .where((s) {
            final sDate = s.startAt.toLocal();
            return s.veterinarianUid == veterinarianUid &&
                sDate.year == localDay.year &&
                sDate.month == localDay.month &&
                sDate.day == localDay.day;
          })
          .toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      debugPrint('[AppointmentBooking] Demo streamSlotsForDay returning ${slots.length} slots for ${localDay.day}/${localDay.month}');
      return Stream.value(slots);
    }

    // Query by veterinarianUid only to avoid requiring composite indexes in Cloud Firestore.
    // Filter by year/month/day and sort in Dart for instant, index-free reliability.
    return _slotsCol
        .where('veterinarianUid', isEqualTo: veterinarianUid)
        .snapshots()
        .handleError((error, stackTrace) {
          debugPrint('🔴 [AppointmentBooking] streamSlotsForDay Firestore error: $error');
          debugPrint(stackTrace.toString());
        })
        .map((snapshot) {
          final allSlots = snapshot.docs.map((doc) {
            try {
              return AppointmentSlot.fromFirestore(doc.data(), doc.id);
            } catch (e) {
              debugPrint('🔴 [AppointmentBooking] Failed to deserialize slot ${doc.id}: $e');
              return null;
            }
          }).whereType<AppointmentSlot>().toList();

          final daySlots = allSlots.where((s) {
            final sDate = s.startAt.toLocal();
            return sDate.year == localDay.year &&
                sDate.month == localDay.month &&
                sDate.day == localDay.day;
          }).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));

          debugPrint('[AppointmentBooking] Stream updated: Firestore has ${snapshot.docs.length} slots for vet $veterinarianUid, ${daySlots.length} match date ${localDay.year}-${localDay.month}-${localDay.day}');
          return daySlots;
        });
  }

  @override
  Stream<List<AppointmentSlot>> streamAvailableSlots({
    required String veterinarianUid,
    DateTime? fromDate,
  }) {
    final start = fromDate?.toLocal() ?? DateTime.now();
    debugPrint('[AppointmentBooking] streamAvailableSlots: vet=$veterinarianUid from $start (isDemo=$isDemo)');

    if (isDemo) {
      final slots = _demoSlots.values
          .where((s) =>
              s.veterinarianUid == veterinarianUid &&
              s.status == SlotStatus.available &&
              s.startAt.toLocal().isAfter(start))
          .toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return Stream.value(slots);
    }

    return _slotsCol
        .where('veterinarianUid', isEqualTo: veterinarianUid)
        .snapshots()
        .handleError((error, stackTrace) {
          debugPrint('🔴 [AppointmentBooking] streamAvailableSlots Firestore error: $error');
        })
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) {
                try {
                  return AppointmentSlot.fromFirestore(doc.data(), doc.id);
                } catch (e) {
                  return null;
                }
              })
              .whereType<AppointmentSlot>()
              .where((s) =>
                  s.status == SlotStatus.available &&
                  s.startAt.toLocal().isAfter(start))
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
          return list;
        });
  }

  @override
  Stream<List<AppointmentSlot>> streamVeterinarianSlots({
    required String veterinarianUid,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    if (isDemo) {
      final slots = _demoSlots.values
          .where((s) =>
              s.veterinarianUid == veterinarianUid &&
              s.startAt.isAfter(fromDate) &&
              s.startAt.isBefore(toDate))
          .toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return Stream.value(slots);
    }

    return _slotsCol
        .where('veterinarianUid', isEqualTo: veterinarianUid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AppointmentSlot.fromFirestore(doc.data(), doc.id))
              .where((s) =>
                  s.startAt.isAfter(fromDate) &&
                  s.startAt.isBefore(toDate))
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
          return list;
        });
  }

  @override
  Future<Appointment> bookAppointment(Appointment appointment) async {
    if (isDemo) {
      final slot = _demoSlots[appointment.slotId];
      if (slot == null || slot.status != SlotStatus.available) {
        throw Exception('This appointment slot has already been booked or is no longer available.');
      }
      _demoSlots[appointment.slotId] = slot.copyWith(
        status: SlotStatus.booked,
        updatedAt: DateTime.now(),
      );
      _demoAppointments[appointment.id] = appointment;
      return appointment;
    }

    // Atomic double-booking prevention using Firestore transaction (SRS FR-03, NFR-02)
    return await _db.runTransaction<Appointment>((transaction) async {
      final slotRef = _slotsCol.doc(appointment.slotId);
      final slotSnapshot = await transaction.get(slotRef);

      if (!slotSnapshot.exists || slotSnapshot.data() == null) {
        throw Exception('The selected appointment slot no longer exists.');
      }

      final slotData = slotSnapshot.data()!;
      final currentStatus = slotData['status'] as String? ?? '';
      if (currentStatus != SlotStatus.available.key) {
        throw Exception(
          'This appointment slot has already been booked by another farmer. Please choose another time slot.',
        );
      }

      // Mark slot as booked
      transaction.update(slotRef, {
        'status': SlotStatus.booked.key,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create appointment
      final appointmentRef = _appointmentsCol.doc(appointment.id);
      final data = appointment.toMap(useTimestamps: true);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      transaction.set(appointmentRef, data);
      return appointment;
    });
  }

  @override
  Future<void> cancelAppointment({
    required String appointmentId,
    required String cancelledByUid,
    required String slotId,
  }) async {
    if (isDemo) {
      final appt = _demoAppointments[appointmentId];
      if (appt != null) {
        _demoAppointments[appointmentId] = appt.copyWith(
          status: AppointmentStatus.cancelled,
          cancelledByUid: cancelledByUid,
          cancelledAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      final slot = _demoSlots[slotId];
      if (slot != null) {
        _demoSlots[slotId] = slot.copyWith(
          status: SlotStatus.available,
          updatedAt: DateTime.now(),
        );
      }
      return;
    }

    // Batch update: mark appointment cancelled and free up the slot for other farmers
    final batch = _db.batch();
    final apptRef = _appointmentsCol.doc(appointmentId);
    final slotRef = _slotsCol.doc(slotId);

    batch.update(apptRef, {
      'status': AppointmentStatus.cancelled.key,
      'cancelledByUid': cancelledByUid,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(slotRef, {
      'status': SlotStatus.available.key,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  @override
  Future<void> completeAppointment({
    required String appointmentId,
    required String veterinarianUid,
  }) async {
    if (isDemo) {
      final appt = _demoAppointments[appointmentId];
      if (appt != null) {
        _demoAppointments[appointmentId] = appt.copyWith(
          status: AppointmentStatus.completed,
          completedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return;
    }

    await _appointmentsCol.doc(appointmentId).update({
      'status': AppointmentStatus.completed.key,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<Appointment>> streamFarmerAppointments(String farmerUid) {
    if (farmerUid.trim().isEmpty) return Stream.value(const []);

    if (isDemo) {
      final list = _demoAppointments.values
          .where((a) => a.farmerUid == farmerUid)
          .toList()
        ..sort((a, b) => b.startAt.compareTo(a.startAt));
      return Stream.value(list);
    }

    return _appointmentsCol
        .where('farmerUid', isEqualTo: farmerUid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Appointment.fromFirestore(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => b.startAt.compareTo(a.startAt));
          return list;
        });
  }

  @override
  Stream<List<Appointment>> streamVeterinarianAppointments(String veterinarianUid) {
    if (veterinarianUid.trim().isEmpty) return Stream.value(const []);

    if (isDemo) {
      final list = _demoAppointments.values
          .where((a) => a.veterinarianUid == veterinarianUid)
          .toList()
        ..sort((a, b) => b.startAt.compareTo(a.startAt));
      return Stream.value(list);
    }

    return _appointmentsCol
        .where('veterinarianUid', isEqualTo: veterinarianUid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Appointment.fromFirestore(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => b.startAt.compareTo(a.startAt));
          return list;
        });
  }

  @override
  Stream<Appointment?> streamAppointmentById(String appointmentId) {
    if (appointmentId.trim().isEmpty) return Stream.value(null);

    if (isDemo) {
      return Stream.value(_demoAppointments[appointmentId]);
    }

    return _appointmentsCol.doc(appointmentId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Appointment.fromFirestore(doc.data()!, doc.id);
    });
  }
}
