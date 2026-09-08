import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/analysis/data/repositories/analysis_repository_impl.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_request.dart';
import 'package:gau_prahari/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import '../../data/repositories/mock_milk_tester.dart';
import '../../domain/entities/milk_measurement.dart';
import '../../domain/repositories/milk_data_provider.dart';
import '../controllers/milk_tester_controller.dart';

class MilkTesterScreen extends StatelessWidget {
  final Cow cow;
  final CollarHistory? collarHistory;

  const MilkTesterScreen({
    super.key,
    required this.cow,
    this.collarHistory,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ChangeNotifierProvider(
      create: (_) => MilkTesterController(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(t.translate('handheldMilkTester')),
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
        body: _MilkTesterView(cow: cow, collarHistory: collarHistory),
      ),
    );
  }
}

class _MilkTesterView extends StatelessWidget {
  final Cow cow;
  final CollarHistory? collarHistory;

  const _MilkTesterView({
    required this.cow,
    this.collarHistory,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final controller = context.watch<MilkTesterController>();
    final measurement = controller.measurement;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Connection Mode Selector (Live Arduino vs Demo Simulation)
          _buildModeSelector(context, controller),
          const SizedBox(height: 14),

          // 2. Collar Telemetry Status Pill
          if (collarHistory != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.translate('collarTelemetryAttached', args: {'days': collarHistory!.recordCount.toString(), 'skinTemp': collarHistory!.meanSkinTemperature.toStringAsFixed(1), 'thi': collarHistory!.meanThi.toStringAsFixed(1)}),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Device Status & Animal Header
          _buildHardwareStatusCard(context, controller),
          const SizedBox(height: 16),

          // 4. Mode-specific controls
          if (!controller.isHardwareMode) ...[
            _buildPresetSelector(context, controller),
            const SizedBox(height: 16),
          ] else if (controller.hardwareMetadata.gasMq2 != null || controller.hardwareMetadata.distanceCm != null) ...[
            _buildHardwareSensorsBadge(context, controller),
            const SizedBox(height: 16),
          ],

          // 5. Action: Trigger measurement & Continuous Real-time Stream
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CustomButton(
                  text: controller.hasMeasurement
                      ? t.translate('retakeMilkMeasurement')
                      : t.translate('startMilkSampleAnalysis'),
                  icon: controller.isHardwareMode
                      ? Icons.bluetooth_searching_rounded
                      : Icons.biotech_rounded,
                  isLoading: controller.isBusy && !controller.isContinuousStreamActive,
                  onPressed: () => controller.takeMeasurement(cow.id),
                ),
              ),
              if (controller.isHardwareMode) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => controller.toggleContinuousStream(cow.id),
                    icon: Icon(
                      controller.isContinuousStreamActive
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 18,
                      color: controller.isContinuousStreamActive
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                    label: Text(
                      controller.isContinuousStreamActive ? t.translate('stopLive') : t.translate('liveStream'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: controller.isContinuousStreamActive
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      side: BorderSide(
                        color: controller.isContinuousStreamActive
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (controller.isContinuousStreamActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sensors_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    t.translate('realTimeSensorActive'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // 6. Measurement Results Section
          if (controller.isBusy)
            _buildMeasuringIndicator(context, controller.state)
          else if (measurement != null)
            _buildResultsSection(context, measurement)
          else
            _buildEmptyState(context),

          if (measurement != null) ...[
            const SizedBox(height: 24),
            CustomButton(
              text: t.translate('proceedToAnalysis'),
              icon: Icons.analytics_rounded,
              backgroundColor: AppColors.primaryDark,
              onPressed: () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t.translate('runningAiModel'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                try {
                  final repo = AnalysisRepositoryImpl();
                  final req = AnalysisRequest(
                    cowId: cow.id,
                    collarData: collarHistory?.records ?? const [],
                    milkData: measurement,
                  );

                  final result = await repo.analyzeSample(req);

                  if (context.mounted) {
                    Navigator.of(context).pop(); // dismiss loading
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnalysisResultScreen(
                          cow: cow,
                          milkMeasurement: measurement,
                          collarHistory: collarHistory,
                          result: result,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // dismiss loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.translate('analysisError', args: {'error': e.toString()})),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, MilkTesterController controller) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              title: t.translate('liveArduino'),
              icon: Icons.bluetooth_rounded,
              isSelected: controller.isHardwareMode,
              onTap: () => controller.setMode(TesterMode.hardware),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModeTab(
              title: t.translate('demoSimulation'),
              icon: Icons.science_rounded,
              isSelected: !controller.isHardwareMode,
              onTap: () => controller.setMode(TesterMode.simulation),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareSensorsBadge(BuildContext context, MilkTesterController controller) {
    final t = AppLocalizations.of(context);
    final meta = controller.hardwareMetadata;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          if (meta.gasMq2 != null)
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.air_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      t.translate('mq2Gas', args: {'value': meta.gasMq2.toString()}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
          if (meta.gasMq2 != null && meta.distanceCm != null)
            Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 8), color: AppColors.primary.withValues(alpha: 0.3)),
          if (meta.distanceCm != null)
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.straighten_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      t.translate('distanceCm', args: {'value': meta.distanceCm.toString()}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHardwareStatusCard(
    BuildContext context,
    MilkTesterController controller,
  ) {
    final t = AppLocalizations.of(context);
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (controller.state) {
      case MilkTestingState.disconnected:
        statusColor = AppColors.textMuted;
        statusText = controller.isHardwareMode
            ? t.translate('testerStandbyArduino')
            : t.translate('testerStandbyMock');
        statusIcon = Icons.bluetooth_disabled_rounded;
        break;
      case MilkTestingState.searching:
        statusColor = Colors.blue;
        statusText = controller.isHardwareMode
            ? t.translate('scanningHc05')
            : t.translate('scanningEsp32');
        statusIcon = Icons.bluetooth_searching_rounded;
        break;
      case MilkTestingState.connecting:
        statusColor = AppColors.secondary;
        statusText = controller.isHardwareMode
            ? t.translate('connectingHc05')
            : t.translate('connectingBle');
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
      case MilkTestingState.connected:
        statusColor = AppColors.primary;
        statusText = t.translate('connectedToMilkTester');
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
      case MilkTestingState.measuring:
        statusColor = Colors.purple;
        statusText = controller.isHardwareMode
            ? t.translate('readingAdcStream')
            : t.translate('readingSpectrometry');
        statusIcon = Icons.sensors_rounded;
        break;
      case MilkTestingState.completed:
        statusColor = AppColors.success;
        statusText = t.translate('milkSampleCaptured');
        statusIcon = Icons.check_circle_rounded;
        break;
      case MilkTestingState.error:
        statusColor = AppColors.error;
        statusText = controller.errorMessage ?? t.translate('hardwareCommunicationError');
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${t.translate("animalPrefix")} ${cow.id} (${cow.breed})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  cow.lactationStage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSelector(
    BuildContext context,
    MilkTesterController controller,
  ) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: AppColors.secondary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.translate('simulationPresets'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  label: t.translate('healthySample'),
                  preset: MockSamplePreset.healthy,
                  activePreset: controller.activePreset,
                  onSelected: () => controller.setPreset(MockSamplePreset.healthy),
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  label: t.translate('subclinicalRisk'),
                  preset: MockSamplePreset.subclinical,
                  activePreset: controller.activePreset,
                  onSelected: () => controller.setPreset(MockSamplePreset.subclinical),
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  label: t.translate('clinicalMastitis'),
                  preset: MockSamplePreset.clinical,
                  activePreset: controller.activePreset,
                  onSelected: () => controller.setPreset(MockSamplePreset.clinical),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required MockSamplePreset preset,
    required MockSamplePreset? activePreset,
    required VoidCallback onSelected,
  }) {
    final isSelected = preset == activePreset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selectedColor: AppColors.secondary,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.secondary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t.translate('noMilkMeasurementYet'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.translate('noMilkMeasurementDescription'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasuringIndicator(BuildContext context, MilkTestingState state) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            t.translate('acquiringMilkTelemetry'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state == MilkTestingState.connecting
                ? t.translate('handshakingConnection')
                : t.translate('processingOpticalTransmission'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(
    BuildContext context,
    MilkMeasurement measurement,
  ) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                t.translate('sampleMeasurements'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    t.translate('validSample'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2x3 Metric Card Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildMetricCard(
              title: t.translate('temperatureLabel'),
              value: '${measurement.milkTemperature.toStringAsFixed(1)} °C',
              subtitle: t.translate('normalTempRange'),
              isWarning: measurement.milkTemperature > 37.8,
              icon: Icons.thermostat_rounded,
            ),
            _buildMetricCard(
              title: t.translate('phValueLabel'),
              value: measurement.ph.toStringAsFixed(2),
              subtitle: t.translate('normalPhRange'),
              isWarning: measurement.isPhAbnormal,
              icon: Icons.water_drop_rounded,
            ),
            _buildMetricCard(
              title: t.translate('conductivityLabel'),
              value: '${measurement.conductivity.toStringAsFixed(2)} mS/cm',
              subtitle: t.translate('normalConductivityRange'),
              isWarning: measurement.isConductivityElevated,
              icon: Icons.electric_bolt_rounded,
            ),
            _buildMetricCard(
              title: t.translate('somaticCellCountLabel'),
              value: '${measurement.scc ~/ 1000}k /mL',
              subtitle: t.translate('riskThresholdScc'),
              isWarning: measurement.isSccElevated,
              icon: Icons.grain_rounded,
            ),
            _buildMetricCard(
              title: t.translate('fatContentLabel'),
              value: '${measurement.fat.toStringAsFixed(1)} %',
              subtitle: t.translate('typicalFatRange'),
              isWarning: false,
              icon: Icons.opacity_rounded,
            ),
            _buildMetricCard(
              title: t.translate('snfSolidsLabel'),
              value: '${measurement.snf.toStringAsFixed(1)} %',
              subtitle: t.translate('typicalSnfRange'),
              isWarning: false,
              icon: Icons.pie_chart_outline_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required bool isWarning,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.errorLight : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWarning
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: isWarning ? AppColors.error : AppColors.primary,
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isWarning ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isWarning ? AppColors.error : AppColors.textMuted,
              fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
