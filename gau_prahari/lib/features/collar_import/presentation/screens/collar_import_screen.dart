import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gau_prahari/core/constants/app_colors.dart';
import 'package:gau_prahari/shared/widgets/custom_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../milk_tester/presentation/screens/milk_tester_screen.dart';
import '../../data/repositories/file_collar_data_provider.dart';
import '../../domain/entities/collar_telemetry.dart';
import '../controllers/collar_import_controller.dart';

class CollarImportScreen extends StatelessWidget {
  final Cow cow;

  const CollarImportScreen({
    super.key,
    required this.cow,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ChangeNotifierProvider(
      create: (_) => CollarImportController(
        provider: FileCollarDataProvider(),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(t.translate('smartCollarHistory')),
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
        body: _CollarImportView(cow: cow),
      ),
    );
  }
}

class _CollarImportView extends StatelessWidget {
  final Cow cow;

  const _CollarImportView({required this.cow});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final controller = context.watch<CollarImportController>();
    final history = controller.history;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Animal & Purpose Header
          _buildInfoCard(context),
          const SizedBox(height: 16),

          // Demo Datasets Selector
          _buildDemoSelector(context, controller),
          const SizedBox(height: 16),

          // Error Alert Banner
          if (controller.errorMessage != null) ...[
            _buildErrorBanner(controller.errorMessage!),
            const SizedBox(height: 16),
          ],

          // Telemetry Summary or Empty State
          if (controller.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            )
          else if (history != null)
            _buildTelemetrySummary(context, history, controller.sourceName)
          else
            _buildEmptyState(context),

          const SizedBox(height: 24),

          // Navigation Button
          CustomButton(
            text: history != null
                ? t.translate('continueToMilkTester')
                : t.translate('skipToMilkTester'),
            icon: Icons.arrow_forward_rounded,
            backgroundColor: history != null ? AppColors.primary : AppColors.secondary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MilkTesterScreen(
                    cow: cow,
                    collarHistory: history,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final t = AppLocalizations.of(context);
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
              const Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.translate('longitudinalAnimalTelemetry'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.translate('collarTelemetryDescription', args: {'cowId': cow.id}),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoSelector(
    BuildContext context,
    CollarImportController controller,
  ) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_zip_rounded, size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.translate('selectTelemetryFile'),
                  style: const TextStyle(
                    fontSize: 13,
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
              _datasetChip(
                label: t.translate('cow104Csv'),
                icon: Icons.table_chart_outlined,
                onTap: () => controller.loadFromAsset(
                  'assets/data/collar_cow_104.csv',
                  expectedCowId: cow.id,
                ),
              ),
              _datasetChip(
                label: t.translate('cow104Json'),
                icon: Icons.data_object_rounded,
                onTap: () => controller.loadFromAsset(
                  'assets/data/collar_cow_104.json',
                  expectedCowId: cow.id,
                ),
              ),
              _datasetChip(
                label: t.translate('cow101Mismatch'),
                icon: Icons.warning_amber_rounded,
                onTap: () => controller.loadFromAsset(
                  'assets/data/collar_cow_101.csv',
                  expectedCowId: cow.id,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datasetChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.file_upload_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            t.translate('noTelemetryFileLoaded'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.translate('noTelemetryFileDescription'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetrySummary(
    BuildContext context,
    CollarHistory history,
    String? sourceName,
  ) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.translate('daysTelemetryImported', args: {'count': history.recordCount.toString()}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (sourceName != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sourceName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 24, color: AppColors.border),

          // Aggregate stat chips
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: t.translate('meanActivity'),
                  value: '${history.meanActivity.toStringAsFixed(1)} / 100',
                  icon: Icons.directions_run_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  label: t.translate('meanSkinTemp'),
                  value: '${history.meanSkinTemperature.toStringAsFixed(1)} °C',
                  icon: Icons.thermostat_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: t.translate('meanThiIndex'),
                  value: history.meanThi.toStringAsFixed(1),
                  icon: Icons.wb_sunny_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  label: t.translate('meanHumidity'),
                  value: '${history.meanHumidity.toStringAsFixed(1)} %',
                  icon: Icons.water_drop_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            t.translate('signalChannelsVerified'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _channelChip(t.translate('activity'), true),
              _channelChip(t.translate('skinTemperature'), true),
              _channelChip(t.translate('ambientTemperature'), true),
              _channelChip(t.translate('humidity'), true),
              _channelChip(t.translate('thiStressIndex'), true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelChip(String label, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
