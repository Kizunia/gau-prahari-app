import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/review_request.dart';
import 'review_status_badge.dart';

/// Card widget representing a single review request in the farmer or vet dashboard.
class ReviewRequestCard extends StatelessWidget {
  final ReviewRequest request;
  final bool isVetView;
  final VoidCallback onTap;

  const ReviewRequestCard({
    super.key,
    required this.request,
    this.isVetView = false,
    required this.onTap,
  });

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isHigh = request.riskLevel.toUpperCase() == 'HIGH';
    final isModerate = request.riskLevel.toUpperCase() == 'MODERATE';
    final riskColor = isHigh
        ? AppColors.error
        : (isModerate ? AppColors.warning : AppColors.success);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Cow Tag + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pets_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              request.cowTagNumber.isNotEmpty
                                  ? request.cowTagNumber
                                  : request.cowId,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ReviewStatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 12),

              // Prediction Label & Risk
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.predictionLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: riskColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${request.riskLevel} RISK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),

              // Footer: Counterpart name & submission timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isVetView
                            ? Icons.person_rounded
                            : Icons.medical_services_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isVetView
                            ? 'Farmer: ${request.farmerNameSnapshot}'
                            : 'Vet: ${request.veterinarianNameSnapshot}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(request.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
