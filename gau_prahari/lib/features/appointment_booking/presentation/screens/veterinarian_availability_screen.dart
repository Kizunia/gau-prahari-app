import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/appointment_slot.dart';
import '../../domain/entities/appointment_status.dart';
import '../../domain/entities/veterinarian_schedule.dart';
import '../../domain/entities/weekly_day_schedule.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../widgets/day_schedule_tile.dart';
import '../widgets/time_slot_chip.dart';

/// Screen allowing a veterinarian to configure recurring weekly hours,
/// publish slots for the next 14 days, and block/unblock individual slots (SRS FR-02).
class VeterinarianAvailabilityScreen extends StatefulWidget {
  const VeterinarianAvailabilityScreen({super.key});

  @override
  State<VeterinarianAvailabilityScreen> createState() =>
      _VeterinarianAvailabilityScreenState();
}

class _VeterinarianAvailabilityScreenState
    extends State<VeterinarianAvailabilityScreen> {
  VeterinarianSchedule? _schedule;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPublishing = false;
  DateTime _inspectDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final repo = context.read<AppointmentRepository>();
    final loaded = await repo.getVeterinarianSchedule(user.id);

    if (mounted) {
      setState(() {
        _schedule = loaded ?? VeterinarianSchedule.defaultSchedule(user.id);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSaveSchedule() async {
    if (_schedule == null) return;
    setState(() => _isSaving = true);
    try {
      final repo = context.read<AppointmentRepository>();
      await repo.saveVeterinarianSchedule(_schedule!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly availability schedule saved.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handlePublishSlots() async {
    if (_schedule == null) return;
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    setState(() => _isPublishing = true);
    try {
      final repo = context.read<AppointmentRepository>();
      // First save current schedule
      await repo.saveVeterinarianSchedule(_schedule!);

      // Generate 14 days of slots
      final slots = _schedule!.generateSlotsForRange(daysCount: 14);
      final count = await repo.publishSlots(user.id, slots);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully published $count appointment slots for the next 14 days.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish slots: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<void> _toggleSlotBlock(AppointmentSlot slot) async {
    if (slot.isBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booked slots cannot be blocked. Cancel the appointment first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final newStatus = slot.isBlocked ? SlotStatus.available : SlotStatus.blocked;
    try {
      final repo = context.read<AppointmentRepository>();
      await repo.setSlotStatus(slotId: slot.id, status: newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == SlotStatus.blocked
                  ? 'Slot ${slot.timeRangeString} blocked.'
                  : 'Slot ${slot.timeRangeString} restored to available.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update slot: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final repo = context.watch<AppointmentRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Availability'),
        actions: [
          TextButton.icon(
            onPressed: (_isSaving || _isLoading) ? null : _handleSaveSchedule,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Info & Overview Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Configure your weekly recurring clinic and field hours. Generate 30-minute consultation slots that farmers can book in real-time.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Weekly Availability Config
                  const Text(
                    'Weekly Recurring Hours',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(7, (index) {
                    final dayOfWeek = index + 1; // 1 = Mon .. 7 = Sun
                    final daySched = _schedule?.weeklyAvailability[dayOfWeek] ??
                        WeeklyDaySchedule(dayOfWeek: dayOfWeek, enabled: false);
                    return DayScheduleTile(
                      schedule: daySched,
                      onChanged: (updated) {
                        setState(() {
                          final currentMap = Map<int, WeeklyDaySchedule>.from(
                            _schedule!.weeklyAvailability,
                          );
                          currentMap[dayOfWeek] = updated;
                          _schedule = _schedule!.copyWith(weeklyAvailability: currentMap);
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),

                  // 3. Publish Action Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.publish_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Publish Slots to Farmers',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Generates bookable 30-minute intervals for the next 14 calendar days. Any slots already reserved by farmers are safely preserved.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isPublishing ? null : _handlePublishSlots,
                            icon: _isPublishing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.event_available_rounded, size: 18),
                            label: Text(_isPublishing ? 'Publishing Slots...' : 'Publish Next 14 Days Slots'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Daily Slot Inspector & Block/Unblock
                  if (user != null) ...[
                    const Text(
                      'Slot Inspector (Tap to Block / Unblock)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Inspect published slots on any date. Tap an available slot to block it from bookings.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    _buildHorizontalDateSelector(),
                    const SizedBox(height: 12),
                    _buildInspectSlotsList(user.id, repo),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildHorizontalDateSelector() {
    final now = DateTime.now();
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = now.add(Duration(days: index));
          final isSelected = date.year == _inspectDate.year &&
              date.month == _inspectDate.month &&
              date.day == _inspectDate.day;

          const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final dayName = names[date.weekday - 1];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _inspectDate = date),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 15,
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

  Widget _buildInspectSlotsList(String vetUid, AppointmentRepository repo) {
    return StreamBuilder<List<AppointmentSlot>>(
      stream: repo.streamSlotsForDay(veterinarianUid: vetUid, day: _inspectDate),
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
                    'Error loading slots: ${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        }

        final slots = snapshot.data ?? [];
        if (slots.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No slots published on this date yet. Tap "Publish Next 14 Days Slots" above.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            return TimeSlotChip(
              slot: slot,
              showStatus: true,
              onTap: () => _toggleSlotBlock(slot),
            );
          }).toList(),
        );
      },
    );
  }
}
