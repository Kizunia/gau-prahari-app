import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    return ChangeNotifierProvider(
      create: (_) => MilkTesterController(
        provider: MockMilkTester(),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Handheld Milk Tester'),
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
    final controller = context.watch<MilkTesterController>();
    final measurement = controller.measurement;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Collar Telemetry Status Pill
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
                      'Collar Telemetry Attached: ${collarHistory!.recordCount} Days (Mean Skin Temp: ${collarHistory!.meanSkinTemperature.toStringAsFixed(1)} °C, THI: ${collarHistory!.meanThi.toStringAsFixed(1)})',
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
          // Device Status & Animal Header
          _buildHardwareStatusCard(context, controller),
          const SizedBox(height: 16),

          // Simulation Preset Selector (when using MockMilkTester)
          if (controller.provider is MockMilkTester) ...[
            _buildPresetSelector(context, controller),
            const SizedBox(height: 16),
          ],

          // Action: Trigger measurement
          CustomButton(
            text: controller.hasMeasurement
                ? 'Retake Milk Measurement'
                : 'Start Milk Sample Analysis',
            icon: Icons.biotech_rounded,
            isLoading: controller.isBusy,
            onPressed: () => controller.takeMeasurement(cow.id),
          ),
          const SizedBox(height: 20),

          // Measurement Results Section
          if (controller.isBusy)
            _buildMeasuringIndicator(controller.state)
          else if (measurement != null)
            _buildResultsSection(context, measurement)
          else
            _buildEmptyState(),

          if (measurement != null) ...[
            const SizedBox(height: 24),
            CustomButton(
              text: 'Proceed to Mastitis Risk Analysis',
              icon: Icons.analytics_rounded,
              backgroundColor: AppColors.primaryDark,
              onPressed: () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Running AI Mastitis Risk Model...',
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
                        content: Text('Analysis Error: $e'),
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

  Widget _buildHardwareStatusCard(
    BuildContext context,
    MilkTesterController controller,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (controller.state) {
      case MilkTestingState.disconnected:
        statusColor = AppColors.textMuted;
        statusText = 'Tester Standby (Mock Provider)';
        statusIcon = Icons.bluetooth_disabled_rounded;
        break;
      case MilkTestingState.searching:
        statusColor = Colors.blue;
        statusText = 'Scanning for ESP32 Milk Tester...';
        statusIcon = Icons.bluetooth_searching_rounded;
        break;
      case MilkTestingState.connecting:
        statusColor = AppColors.secondary;
        statusText = 'Connecting via BLE/GATT...';
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
      case MilkTestingState.connected:
        statusColor = AppColors.primary;
        statusText = 'Connected to Milk Tester';
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
      case MilkTestingState.measuring:
        statusColor = Colors.purple;
        statusText = 'Reading Spectrometry & Conductivity Cell...';
        statusIcon = Icons.sensors_rounded;
        break;
      case MilkTestingState.completed:
        statusColor = AppColors.success;
        statusText = 'Milk Sample Captured Successfully';
        statusIcon = Icons.check_circle_rounded;
        break;
      case MilkTestingState.error:
        statusColor = AppColors.error;
        statusText = controller.errorMessage ?? 'Hardware Communication Error';
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
                  'Animal: ${cow.id} (${cow.breed})',
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
            children: const [
              Icon(Icons.tune_rounded, size: 16, color: AppColors.secondary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mock Simulation Preset (SIH Evaluation)',
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip(
                label: 'Healthy Normal',
                preset: MockSamplePreset.healthy,
                selected: controller.activePreset == MockSamplePreset.healthy,
                onTap: () => controller.setPreset(MockSamplePreset.healthy),
              ),
              _presetChip(
                label: 'Subclinical Mastitis',
                preset: MockSamplePreset.subclinical,
                selected: controller.activePreset == MockSamplePreset.subclinical,
                onTap: () => controller.setPreset(MockSamplePreset.subclinical),
              ),
              _presetChip(
                label: 'Clinical Mastitis',
                preset: MockSamplePreset.clinical,
                selected: controller.activePreset == MockSamplePreset.clinical,
                onTap: () => controller.setPreset(MockSamplePreset.clinical),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip({
    required String label,
    required MockSamplePreset preset,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.textLight : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildMeasuringIndicator(MilkTestingState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            state == MilkTestingState.measuring
                ? 'Sampling milk electrodes & optical sensor...'
                : 'Connecting to Milk Tester ESP32...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: const [
          Icon(Icons.science_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No Milk Measurement Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Press the button above to capture physical milk parameters for this cow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Sample Measurements',
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: measurement.isValid
                    ? AppColors.successLight
                    : AppColors.errorLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                measurement.isValid ? 'Valid Sample' : 'Physiological Warning',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: measurement.isValid
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid of 6 milk parameters with resilient aspect ratio and inner layout
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.30,
          children: [
            _buildMetricCard(
              title: 'Temperature',
              value: '${measurement.milkTemperature.toStringAsFixed(1)} °C',
              subtitle: 'Normal: 35.0 - 38.0 °C',
              isWarning: measurement.milkTemperature > 38.0,
              icon: Icons.thermostat_rounded,
            ),
            _buildMetricCard(
              title: 'pH Value',
              value: measurement.ph.toStringAsFixed(2),
              subtitle: 'Normal: 6.50 - 6.80',
              isWarning: measurement.isPhAbnormal,
              icon: Icons.water_drop_outlined,
            ),
            _buildMetricCard(
              title: 'Conductivity',
              value: '${measurement.conductivity.toStringAsFixed(2)} mS/cm',
              subtitle: 'Normal: 4.5 - 5.8 mS/cm',
              isWarning: measurement.isConductivityElevated,
              icon: Icons.electric_bolt_rounded,
            ),
            _buildMetricCard(
              title: 'Somatic Cell Count',
              value: '${measurement.scc ~/ 1000}k /mL',
              subtitle: 'Risk Threshold: >250k',
              isWarning: measurement.isSccElevated,
              icon: Icons.grain_rounded,
            ),
            _buildMetricCard(
              title: 'Fat Content',
              value: '${measurement.fat.toStringAsFixed(1)} %',
              subtitle: 'Typical: 3.5 - 5.0 %',
              isWarning: false,
              icon: Icons.opacity_rounded,
            ),
            _buildMetricCard(
              title: 'SNF (Solids)',
              value: '${measurement.snf.toStringAsFixed(1)} %',
              subtitle: 'Typical: 8.0 - 9.5 %',
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
