import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/review_message.dart';

/// Renders a single chat bubble in the review conversation thread.
class ReviewMessageBubble extends StatelessWidget {
  final ReviewMessage message;
  final bool isMe;

  const ReviewMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = message.isVeterinarian ? 'Veterinarian' : 'Farmer';
    final roleColor = message.isVeterinarian
        ? const Color(0xFF1565C0)
        : const Color(0xFF2E7D32);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender Role / Identity Header
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      roleLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Message text
            SelectableText(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
