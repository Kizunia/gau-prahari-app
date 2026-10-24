import '../../../appointment_booking/presentation/screens/veterinarian_directory_screen.dart';
import 'package:flutter/material.dart';
import 'package:gau_prahari/core/constants/app_colors.dart';
import 'package:gau_prahari/shared/widgets/custom_button.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../cow_selection/presentation/screens/cow_selection_screen.dart';
import '../../../milk_tester/domain/entities/milk_measurement.dart';
import '../../../vet_review/presentation/screens/create_review_request_screen.dart';
import '../../../voice_assistant/presentation/widgets/voice_assistant_button.dart';
import '../../domain/entities/analysis_result.dart';
import '../widgets/share_report_bottom_sheet.dart';

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

  void _handleVetReview(BuildContext context) {
    final authCtrl = context.read<AuthController>();
    final user = authCtrl.currentUser;

    if (user == null || user.isDemo) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Farmer Account Required'),
          content: const Text(
            'Requesting a clinical veterinarian review requires a registered farmer account. Demo sessions use isolated local sample data.\n\nPlease sign in or create a free farmer account to connect with registered veterinarians.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Sign In / Register'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateReviewRequestScreen(
          cow: cow,
          result: result,
          milkMeasurement: milkMeasurement,
          collarHistory: collarHistory,
        ),
      ),
    );
  }

  void _openShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareReportBottomSheet(
        cow: cow,
        milkMeasurement: milkMeasurement,
        result: result,
        collarHistory: collarHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(t.translate('mastitisRiskAssessment')),
        ),
        actions: [
          VoiceAssistantButton(
            screenName: 'analysis_result',
            contextData: {
              'cowId': cow.id,
              'cowName': cow.displayName,
              'riskLevel': result.riskLevel,
              'probability': result.probability,
              'factors': result.factors,
              'recommendedAction': result.recommendedAction,
            },
          ),
          IconButton(
            tooltip: t.translate('shareReport'),
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            onPressed: () => _openShareOptions(context),
          ),
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
                const Icon(
                  Icons.pets_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  cow.displayName,
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
            const SizedBox(height: 24),

            // 6. Action: Request Veterinarian Review
            CustomButton(
              text: t.translate('requestVetReview'),
              icon: Icons.medical_services_rounded,
              backgroundColor: const Color(0xFF1565C0),
              onPressed: () => _handleVetReview(context),
            ),
            const SizedBox(height: 12),

            // Action: Book Veterinarian Consultation
            CustomButton(
              text: 'Book Veterinarian Consultation',
              icon: Icons.calendar_month_rounded,
              backgroundColor: AppColors.primary,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VeterinarianDirectoryScreen(
                      preselectedCowId: cow.id,
                      preselectedCowTag: cow.tagNumber,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 7. Action: Share / Export Clinical Report
            CustomButton(
              text: t.translate('shareClinicReport'),
              icon: Icons.share_rounded,
              backgroundColor: const Color(0xFF1E7E34),
              onPressed: () => _openShareOptions(context),
            ),
            const SizedBox(height: 12),

            // 8. Action: Done & Select Next Animal
            CustomButton(
              text: t.translate('doneSelectNext'),
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
    final t = AppLocalizations.of(context);
    Color bannerBg;
    Color textColor;
    IconData icon;
    String statusTitle;
    String statusSubtitle;

    if (result.isHighRisk) {
      bannerBg = AppColors.errorLight;
      textColor = AppColors.error;
      icon = Icons.warning_rounded;
      statusTitle = t.translate('highMastitisRisk');
      statusSubtitle = t.translate('highRiskSubtitle');
    } else if (result.isModerateRisk) {
      bannerBg = AppColors.warningLight;
      textColor = AppColors.warning;
      icon = Icons.info_rounded;
      statusTitle = t.translate('moderateRisk');
      statusSubtitle = t.translate('moderateRiskSubtitle');
    } else {
      bannerBg = AppColors.successLight;
      textColor = AppColors.success;
      icon = Icons.verified_user_rounded;
      statusTitle = t.translate('healthyLowRisk');
      statusSubtitle = t.translate('healthyRiskSubtitle');
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
    final t = AppLocalizations.of(context);
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
              Expanded(
                child: Text(
                  t.translate('aiModelRiskConfidence'),
                  style: const TextStyle(
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
    final t = AppLocalizations.of(context);
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
            children: [
              const Icon(
                Icons.insights_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.translate('keyDiagnosticDrivers'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (result.factors.isEmpty)
            Text(
              t.translate('noAbnormalVariances'),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...result.factors.map(
              (factor) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: result.isHighRisk
                            ? AppColors.error
                            : (result.isModerateRisk
                                  ? AppColors.warning
                                  : AppColors.success),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        factor,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
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
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.translate('recommendedVeterinaryAction'),
                  style: const TextStyle(
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
    final t = AppLocalizations.of(context);
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
          Text(
            t.translate('rawInputParameters'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildParamRow(
            t.translate('milkTemperature'),
            '${milkMeasurement.milkTemperature.toStringAsFixed(1)} °C',
          ),
          _buildParamRow(
            t.translate('phLevel'),
            milkMeasurement.ph.toStringAsFixed(2),
          ),
          _buildParamRow(
            t.translate('electricalConductivity'),
            '${milkMeasurement.conductivity.toStringAsFixed(2)} mS/cm',
          ),
          _buildParamRow(
            t.translate('somaticCellCount'),
            '${milkMeasurement.scc.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} cells/mL',
          ),
          _buildParamRow(
            t.translate('fatContent'),
            '${milkMeasurement.fat.toStringAsFixed(1)} %',
          ),
          _buildParamRow(
            t.translate('snfContent'),
            '${milkMeasurement.snf.toStringAsFixed(1)} %',
          ),
          if (collarHistory != null) ...[
            const Divider(height: 20, color: AppColors.border),
            _buildParamRow(
              t.translate('collarTelemetry'),
              t.translate(
                'daysAttached',
                args: {'count': collarHistory!.recordCount.toString()},
              ),
            ),
            _buildParamRow(
              t.translate('collarMeanThi'),
              collarHistory!.meanThi.toStringAsFixed(1),
            ),
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
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
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
