import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/weekly_day_schedule.dart';

/// Interactive tile allowing a veterinarian to toggle and configure hours for a day of week.
class DayScheduleTile extends StatelessWidget {
  final WeeklyDaySchedule schedule;
  final ValueChanged<WeeklyDaySchedule> onChanged;

  const DayScheduleTile({
    super.key,
    required this.schedule,
    required this.onChanged,
  });

  Future<void> _pickStartTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: schedule.startHour, minute: schedule.startMinute),
    );
    if (picked != null) {
      onChanged(schedule.copyWith(startHour: picked.hour, startMinute: picked.minute));
    }
  }

  Future<void> _pickEndTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: schedule.endHour, minute: schedule.endMinute),
    );
    if (picked != null) {
      onChanged(schedule.copyWith(endHour: picked.hour, endMinute: picked.minute));
    }
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: schedule.enabled ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: schedule.enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Day Name
          SizedBox(
            width: 90,
            child: Text(
              schedule.dayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: schedule.enabled ? FontWeight.w700 : FontWeight.w500,
                color: schedule.enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),

          // Working Hours Selectors (if enabled)
          Expanded(
            child: schedule.enabled
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _pickStartTime(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            _formatTime(schedule.startHour, schedule.startMinute),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('-', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      InkWell(
                        onTap: () => _pickEndTime(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            _formatTime(schedule.endHour, schedule.endMinute),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                      'Unavailable',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
          ),

          // Toggle Switch
          Switch.adaptive(
            value: schedule.enabled,
            activeTrackColor: AppColors.primary,
            onChanged: (val) => onChanged(schedule.copyWith(enabled: val)),
          ),
        ],
      ),
    );
  }
}
