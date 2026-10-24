import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/appointment_slot.dart';

/// Selectable or interactive chip rendering an appointment time slot.
class TimeSlotChip extends StatelessWidget {
  final AppointmentSlot slot;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showStatus;

  const TimeSlotChip({
    super.key,
    required this.slot,
    this.isSelected = false,
    this.onTap,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = slot.isAvailable;
    final isBooked = slot.isBooked;
    final isBlocked = slot.isBlocked;

    Color bg;
    Color border;
    Color textColor;

    if (isSelected) {
      bg = AppColors.primary;
      border = AppColors.primary;
      textColor = Colors.white;
    } else if (isBooked) {
      bg = AppColors.surfaceVariant.withValues(alpha: 0.5);
      border = AppColors.border;
      textColor = AppColors.textMuted;
    } else if (isBlocked) {
      bg = AppColors.errorLight.withValues(alpha: 0.3);
      border = AppColors.error.withValues(alpha: 0.2);
      textColor = AppColors.error;
    } else {
      bg = AppColors.surface;
      border = AppColors.border;
      textColor = AppColors.textPrimary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAvailable || showStatus ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                slot.timeRangeString,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (showStatus && !isAvailable) ...[
                const SizedBox(height: 2),
                Text(
                  slot.status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isBooked ? AppColors.textMuted : AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
