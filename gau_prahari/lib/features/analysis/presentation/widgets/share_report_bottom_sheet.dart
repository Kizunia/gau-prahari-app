import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../milk_tester/domain/entities/milk_measurement.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import '../../domain/entities/analysis_result.dart';
import '../../services/report_export_service.dart';
import 'diagnostic_certificate_dialog.dart';

/// Modal bottom sheet providing multiple export and veterinary sharing options.
class ShareReportBottomSheet extends StatefulWidget {
  final Cow cow;
  final MilkMeasurement milkMeasurement;
  final AnalysisResult result;
  final CollarHistory? collarHistory;

  const ShareReportBottomSheet({
    super.key,
    required this.cow,
    required this.milkMeasurement,
    required this.result,
    this.collarHistory,
  });

  @override
  State<ShareReportBottomSheet> createState() => _ShareReportBottomSheetState();
}

class _ShareReportBottomSheetState extends State<ShareReportBottomSheet> {
  final TextEditingController _vetPhoneController = TextEditingController();
  final ReportExportService _exportService = const ReportExportService();
  bool _copied = false;

  @override
  void dispose() {
    _vetPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export & Share Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Send clinical mastitis summary to Veterinarian / Co-op',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Optional Veterinarian Phone Field
            TextField(
              controller: _vetPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Veterinarian / Co-op WhatsApp Number (Optional)',
                hintText: '+91 98765 43210',
                prefixIcon: const Icon(Icons.phone_rounded, size: 20, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Share via WhatsApp Action
            _buildActionTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'Share via WhatsApp',
              subtitle: 'Pre-formatted clinical diagnosis with telemetry readings',
              onTap: () async {
                final phone = _vetPhoneController.text.trim();
                final uri = _exportService.generateWhatsAppUri(
                  cow: widget.cow,
                  milkMeasurement: widget.milkMeasurement,
                  result: widget.result,
                  collarHistory: widget.collarHistory,
                  phoneNumber: phone.isNotEmpty ? phone : null,
                );

                // Copy report to clipboard as immediate guarantee
                await _exportService.copyReportToClipboard(
                  cow: widget.cow,
                  milkMeasurement: widget.milkMeasurement,
                  result: widget.result,
                  collarHistory: widget.collarHistory,
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('WhatsApp report prepared! URI: ${uri.toString().substring(0, 45)}... (Copied to clipboard)'),
                      backgroundColor: const Color(0xFF25D366),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),

            // 2. Copy Full Text Summary
            _buildActionTile(
              icon: _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
              iconColor: _copied ? AppColors.success : AppColors.primary,
              title: _copied ? 'Report Copied!' : 'Copy Summary to Clipboard',
              subtitle: 'Formatted text for SMS, email, or messaging apps',
              onTap: () async {
                await _exportService.copyReportToClipboard(
                  cow: widget.cow,
                  milkMeasurement: widget.milkMeasurement,
                  result: widget.result,
                  collarHistory: widget.collarHistory,
                );
                setState(() => _copied = true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Full clinical diagnostic report copied to clipboard!'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),

            // 3. View Official Certificate
            _buildActionTile(
              icon: Icons.card_membership_rounded,
              iconColor: AppColors.secondary,
              title: 'View Diagnostic Certificate Card',
              subtitle: 'Printable medical card with official project seal',
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => DiagnosticCertificateDialog(
                    cow: widget.cow,
                    milkMeasurement: widget.milkMeasurement,
                    result: widget.result,
                    collarHistory: widget.collarHistory,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
