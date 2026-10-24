import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Enum representing the review request lifecycle status according to SRS Section 4.6.
enum ReviewStatus {
  pending('pending', 'Pending'),
  inReview('inReview', 'In Review'),
  responded('responded', 'Responded'),
  closed('closed', 'Closed');

  final String value;
  final String label;

  const ReviewStatus(this.value, this.label);

  static ReviewStatus fromString(String? raw) {
    if (raw == null) return ReviewStatus.pending;
    switch (raw.trim()) {
      case 'inReview':
      case 'in_review':
        return ReviewStatus.inReview;
      case 'responded':
        return ReviewStatus.responded;
      case 'closed':
        return ReviewStatus.closed;
      case 'pending':
      default:
        return ReviewStatus.pending;
    }
  }

  bool get isClosed => this == ReviewStatus.closed;
  bool get isOpen => this != ReviewStatus.closed;

  Color get color {
    switch (this) {
      case ReviewStatus.pending:
        return const Color(0xFFE65100); // Deep Orange / Warning
      case ReviewStatus.inReview:
        return const Color(0xFF1565C0); // Blue
      case ReviewStatus.responded:
        return AppColors.success; // Green
      case ReviewStatus.closed:
        return AppColors.textMuted; // Grey
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ReviewStatus.pending:
        return const Color(0xFFFFF3E0);
      case ReviewStatus.inReview:
        return const Color(0xFFE3F2FD);
      case ReviewStatus.responded:
        return const Color(0xFFE8F5E9);
      case ReviewStatus.closed:
        return const Color(0xFFEEEEEE);
    }
  }
}
