import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../cow_selection/presentation/controllers/cow_controller.dart';
import '../../../vet_review/domain/entities/review_request.dart';
import '../../../vet_review/domain/entities/vet_profile.dart';
import '../../../vet_review/domain/repositories/vet_review_repository.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_slot.dart';
import '../../domain/entities/appointment_status.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../widgets/time_slot_chip.dart';
import 'farmer_appointments_screen.dart';

/// Screen allowing a farmer to choose a date, pick an available slot,
/// optionally attach a cow or clinical review, and confirm booking (SRS FR-03).
class FarmerBookingScreen extends StatefulWidget {
  final VetProfile veterinarian;
  final String? preselectedCowId;
  final String? preselectedCowTag;
  final String? preselectedReviewRequestId;

  const FarmerBookingScreen({
    super.key,
    required this.veterinarian,
    this.preselectedCowId,
    this.preselectedCowTag,
    this.preselectedReviewRequestId,
  });

  @override
  State<FarmerBookingScreen> createState() => _FarmerBookingScreenState();
}

class _FarmerBookingScreenState extends State<FarmerBookingScreen> {
  late DateTime _selectedDate;
  AppointmentSlot? _selectedSlot;
  String? _selectedCowId;
  String? _selectedCowTag;
  String? _selectedReviewRequestId;
  final _notesController = TextEditingController();
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    // Default to tomorrow or today
    _selectedDate = DateTime.now();
    _selectedCowId = widget.preselectedCowId;
    _selectedCowTag = widget.preselectedCowTag;
    _selectedReviewRequestId = widget.preselectedReviewRequestId;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmBooking() async {
    if (_selectedSlot == null) return;
    final authController = context.read<AuthController>();
    final user = authController.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to complete your booking.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Veterinarian: Dr. ${widget.veterinarian.name}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Date: ${_selectedSlot!.dateString}'),
            Text('Time: ${_selectedSlot!.timeRangeString}'),
            if (_selectedCowTag != null && _selectedCowTag!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Animal: $_selectedCowTag'),
            ],
            if (_selectedReviewRequestId != null && _selectedReviewRequestId!.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Linked: Prior Clinical Case Review'),
            ],
            const SizedBox(height: 12),
            const Text(
              'Your slot will be reserved immediately upon confirmation.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBooking = true);

    try {
      final repo = context.read<AppointmentRepository>();
      final appointmentId = 'APPT_${DateTime.now().millisecondsSinceEpoch}_${user.id.hashCode.abs()}';

      final appointment = Appointment(
        id: appointmentId,
        farmerUid: user.id,
        farmerNameSnapshot: user.displayName,
        veterinarianUid: widget.veterinarian.uid,
        veterinarianNameSnapshot: widget.veterinarian.name,
        slotId: _selectedSlot!.id,
        cowId: _selectedCowId,
        cowTagNumber: _selectedCowTag,
        reviewRequestId: _selectedReviewRequestId,
        startAt: _selectedSlot!.startAt,
        endAt: _selectedSlot!.endAt,
        status: AppointmentStatus.booked,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.bookAppointment(appointment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment confirmed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Replace with FarmerAppointmentsScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const FarmerAppointmentsScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppointmentRepository>();
    final cowCtrl = context.watch<CowController>();
    final user = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule Appointment'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Veterinarian Header Card
                  _buildVetHeader(),
                  const SizedBox(height: 16),

                  // 2. Horizontal Date Selector (Next 14 Days)
                  const Text(
                    'Select Consultation Date',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _buildDateSelector(),
                  const SizedBox(height: 20),

                  // 3. Available Time Slots for Selected Date
                  const Text(
                    'Available Time Slots',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _buildSlotsSection(repo),
                  const SizedBox(height: 20),

                  // 4. Optional Cow Selection
                  const Text(
                    'Associated Animal (Optional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildCowDropdown(cowCtrl),
                  const SizedBox(height: 16),

                  // 5. Optional Linked Clinical Review
                  if (user != null) ...[
                    const Text(
                      'Link to Clinical Case Review (Optional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _buildReviewDropdown(user.id),
                    const SizedBox(height: 16),
                  ],

                  // 6. Farmer Notes Field
                  const Text(
                    'Consultation Reason / Notes (Optional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Follow-up CMT test, physical quarter palpation needed...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Fixed Bottom Booking Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildVetHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${widget.veterinarian.name}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.veterinarian.designation ?? 'Field Veterinary Officer',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = now.add(Duration(days: index));
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          final dayName = _getDayShortName(date.weekday);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                    _selectedSlot = null; // Clear selected slot when changing date
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getDayShortName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  Widget _buildSlotsSection(AppointmentRepository repo) {
    return StreamBuilder<List<AppointmentSlot>>(
      stream: repo.streamSlotsForDay(
        veterinarianUid: widget.veterinarian.uid,
        day: _selectedDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('🔴 [FarmerBookingScreen] Error loading slots: ${snapshot.error}');
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error loading available slots: ${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        }

        final allSlots = snapshot.data ?? [];
        final availableSlots = allSlots.where((s) => s.isAvailable).toList();
        debugPrint('[FarmerBookingScreen] Date ${_selectedDate.day}/${_selectedDate.month}: total=${allSlots.length}, available=${availableSlots.length}');

        if (availableSlots.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_busy_rounded, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No available time slots on this date. Please pick another date above.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                      _selectedSlot = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Check Next Day', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableSlots.map((slot) {
            final isSelected = _selectedSlot?.id == slot.id;
            return TimeSlotChip(
              slot: slot,
              isSelected: isSelected,
              onTap: () {
                setState(() => _selectedSlot = slot);
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCowDropdown(CowController cowCtrl) {
    final cows = cowCtrl.cows;
    final cowExists = cows.any((c) => c.id == _selectedCowId);
    final effectiveCowId = cowExists ? _selectedCowId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: effectiveCowId,
          hint: const Text('None (General Consultation)', style: TextStyle(fontSize: 13)),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('None (General Consultation)', style: TextStyle(fontSize: 13)),
            ),
            ...cows.map((Cow cow) {
              final label = cow.name != null && cow.name!.isNotEmpty
                  ? '${cow.name} (${cow.tagNumber})'
                  : cow.tagNumber;
              return DropdownMenuItem<String?>(
                value: cow.id,
                child: Text(label, style: const TextStyle(fontSize: 13)),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedCowId = val;
              if (val != null) {
                final found = cows.firstWhere((c) => c.id == val, orElse: () => cows.first);
                _selectedCowTag = found.tagNumber;
              } else {
                _selectedCowTag = null;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildReviewDropdown(String farmerUid) {
    final user = context.watch<AuthController>().currentUser;
    if (user?.isDemo == true || farmerUid.startsWith('demo_')) {
      return const SizedBox.shrink();
    }

    final vetRepo = context.read<VetReviewRepository>();
    return StreamBuilder<List<ReviewRequest>>(
      stream: vetRepo.streamFarmerRequests(farmerUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[FarmerBookingScreen] streamFarmerRequests error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final requests = snapshot.data ?? [];
        final reqExists = requests.any((r) => r.id == _selectedReviewRequestId);
        final effectiveReqId = reqExists ? _selectedReviewRequestId : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: effectiveReqId,
              hint: const Text('None (Standalone Booking)', style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None (Standalone Booking)', style: TextStyle(fontSize: 13)),
                ),
                ...requests.map((ReviewRequest req) {
                  return DropdownMenuItem<String?>(
                    value: req.id,
                    child: Text(
                      'Case ${req.cowTagNumber} (${req.riskLevel} Risk)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedReviewRequestId = val);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedSlot != null ? _selectedSlot!.timeRangeString : 'No slot chosen',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  _selectedSlot != null ? _selectedSlot!.dateString : 'Select a date and time',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: (_selectedSlot == null || _isBooking) ? null : _handleConfirmBooking,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              minimumSize: const Size(130, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _isBooking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }
}
