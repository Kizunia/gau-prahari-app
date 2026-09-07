import 'package:flutter/material.dart';
import 'package:gau_prahari/core/constants/app_colors.dart';
import 'package:gau_prahari/shared/widgets/custom_button.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../cow_selection/presentation/screens/cow_selection_screen.dart';
import '../../../milk_tester/domain/entities/milk_measurement.dart';
import '../../domain/entities/analysis_result.dart';

class AnalysisResultScreen extends StatelessWidget {
  final Cow cow;
  final MilkMeasurement milkMeasurement;
  final CollarHistory? collarHistory;
  final AnalysisResult result;

  const AnalysisResultScreen({
    super.key,
    required this.cow,
    required this.milkMeasurement,
    this.collarHistory,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Mastitis Risk Assessment'),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                const Icon(Icons.pets_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  cow.id,
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. Primary Risk Classification Banner
            _buildRiskBanner(context),
            const SizedBox(height: 20),

            // 2. Model Confidence / Probability Card
            if (result.probability != null) ...[
              _buildProbabilityCard(context),
              const SizedBox(height: 20),
            ],

            // 3. Contributing Key Factors
            _buildKeyFactorsSection(context),
            const SizedBox(height: 20),

            // 4. Clinical Guidance / Recommended Action
            _buildRecommendationCard(context),
            const SizedBox(height: 20),

            // 5. Test Parameter Summary Breakdown
            _buildParameterBreakdown(context),
            const SizedBox(height: 28),

            // 6. Action: New Test
            CustomButton(
              text: 'Done & Select Next Animal',
              icon: Icons.check_circle_outline_rounded,
              backgroundColor: AppColors.primaryDark,
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CowSelectionScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBanner(BuildContext context) {
    Color bannerBg;
    Color textColor;
    IconData icon;
    String statusTitle;
    String statusSubtitle;

    if (result.isHighRisk) {
      bannerBg = AppColors.errorLight;
      textColor = AppColors.error;
      icon = Icons.warning_rounded;
      statusTitle = 'HIGH MASTITIS RISK';
      statusSubtitle = 'Immediate isolation and clinical intervention recommended.';
    } else if (result.isModerateRisk) {
      bannerBg = AppColors.warningLight;
      textColor = AppColors.warning;
      icon = Icons.info_rounded;
      statusTitle = 'MODERATE RISK (SUBCLINICAL)';
      statusSubtitle = 'Early inflammatory indicators detected in quarter milk.';
    } else {
      bannerBg = AppColors.successLight;
      textColor = AppColors.success;
      icon = Icons.verified_user_rounded;
      statusTitle = 'HEALTHY / LOW RISK';
      statusSubtitle = 'Milk biomarkers within standard physiological baseline.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Icon(icon, color: textColor, size: 26),
              Text(
                statusTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.9),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityCard(BuildContext context) {
    final prob = result.probability ?? 0.0;
    final percentage = (prob * 100).toInt();

    Color barColor;
    if (prob >= 0.65) {
      barColor = AppColors.error;
    } else if (prob >= 0.35) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'AI Model Risk Confidence',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: prob,
              minHeight: 10,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyFactorsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Key Diagnostic Drivers',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (result.factors.isEmpty)
            const Text(
              'No significant anomalous feature deviations detected.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            ...result.factors.map(
              (factor) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      result.isHighRisk
                          ? Icons.arrow_upward_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: result.isHighRisk ? AppColors.error : AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        factor,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.medical_services_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommended Veterinary Action',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.recommendedAction,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterBreakdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Raw Input Parameters Recorded',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildParamRow('Milk Temperature', '${milkMeasurement.milkTemperature.toStringAsFixed(1)} °C'),
          _buildParamRow('pH Level', milkMeasurement.ph.toStringAsFixed(2)),
          _buildParamRow('Electrical Conductivity', '${milkMeasurement.conductivity.toStringAsFixed(2)} mS/cm'),
          _buildParamRow('Somatic Cell Count', '${milkMeasurement.scc.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} cells/mL'),
          _buildParamRow('Fat Content', '${milkMeasurement.fat.toStringAsFixed(1)} %'),
          _buildParamRow('Solids-Not-Fat (SNF)', '${milkMeasurement.snf.toStringAsFixed(1)} %'),
          if (collarHistory != null) ...[
            const Divider(height: 20, color: AppColors.border),
            _buildParamRow('Collar Telemetry', '${collarHistory!.recordCount} Days attached'),
            _buildParamRow('Collar Mean THI', collarHistory!.meanThi.toStringAsFixed(1)),
          ],
        ],
      ),
    );
  }

  Widget _buildParamRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
