import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../milk_tester/domain/entities/milk_measurement.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import '../../domain/entities/analysis_result.dart';
import '../../services/report_export_service.dart';

/// Official Diagnostic Certificate & Clinical Summary Dialog
class DiagnosticCertificateDialog extends StatelessWidget {
  final Cow cow;
  final MilkMeasurement milkMeasurement;
  final AnalysisResult result;
  final CollarHistory? collarHistory;

  const DiagnosticCertificateDialog({
    super.key,
    required this.cow,
    required this.milkMeasurement,
    required this.result,
    this.collarHistory,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isHighRisk = result.riskLevel == 'HIGH';
    final isModRisk = result.riskLevel == 'MODERATE';
    final riskColor = isHighRisk
        ? AppColors.error
        : (isModRisk ? AppColors.warning : AppColors.success);

    final prob = result.probability ?? (isHighRisk ? 0.90 : 0.05);
    final animalLabel = (cow.name != null && cow.name!.trim().isNotEmpty) ? '${cow.name} (${cow.id})' : cow.id;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Stamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate('gauPrahariClinicalCard'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          t.translate('sihDiagnosticTelemetry'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),

              // Animal & Certificate Meta Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.translate("animalPrefix")} $animalLabel (${t.translate("tagPrefix")} ${cow.tagNumber})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${t.translate("breedPrefix")} ${cow.breed}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.translate("lactationPrefix")} ${cow.lactationStage}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${t.translate("datePrefix")} ${DateTime.now().toLocal().toString().substring(0, 10)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Risk Level Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isHighRisk
                              ? Icons.error_rounded
                              : (isModRisk ? Icons.warning_rounded : Icons.check_circle_rounded),
                          color: riskColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${t.translate("riskPrefix")} ${result.riskLevel}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: riskColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${t.translate("probPrefix")} ${(prob * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Milk Biomarkers Table
              Text(
                t.translate('milkBiomarkers'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildParameterRow(t.translate('somaticCellCount'), '${milkMeasurement.scc ~/ 1000}k /mL', milkMeasurement.isSccElevated),
                    const Divider(height: 1, color: AppColors.border),
                    _buildParameterRow(t.translate('conductivityLabel'), '${milkMeasurement.conductivity.toStringAsFixed(2)} mS/cm', milkMeasurement.isConductivityElevated),
                    const Divider(height: 1, color: AppColors.border),
                    _buildParameterRow(t.translate('milkPh'), milkMeasurement.ph.toStringAsFixed(2), milkMeasurement.isPhAbnormal),
                    const Divider(height: 1, color: AppColors.border),
                    _buildParameterRow(t.translate('milkTemp'), '${milkMeasurement.milkTemperature.toStringAsFixed(1)} °C', milkMeasurement.milkTemperature > 37.8),
                    const Divider(height: 1, color: AppColors.border),
                    _buildParameterRow(t.translate('fatSnf'), '${milkMeasurement.fat.toStringAsFixed(1)}% / ${milkMeasurement.snf.toStringAsFixed(1)}%', false),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Factors
              Text(
                t.translate('diagnosticFactors'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              ...result.factors.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Recommended Clinical Action
              Text(
                t.translate('veterinaryRecommendation'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  result.recommendedAction,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: Text(t.translate('copySummary'), style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        const service = ReportExportService();
                        await service.copyReportToClipboard(
                          cow: cow,
                          milkMeasurement: milkMeasurement,
                          result: result,
                          collarHistory: collarHistory,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.translate('clinicalSummaryCopied')),
                              backgroundColor: AppColors.success,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.translate('done'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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

  Widget _buildParameterRow(String label, String value, bool isAlert) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isAlert ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
