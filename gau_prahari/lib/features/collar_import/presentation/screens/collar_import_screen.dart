import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gau_prahari/core/constants/app_colors.dart';
import 'package:gau_prahari/shared/widgets/custom_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../milk_tester/presentation/screens/milk_tester_screen.dart';
import '../../data/repositories/file_collar_data_provider.dart';
import '../../data/services/collar_bluetooth_service.dart';
import '../../domain/entities/collar_telemetry.dart';
import '../controllers/collar_import_controller.dart';

class CollarImportScreen extends StatefulWidget {
  final Cow cow;

  const CollarImportScreen({
    super.key,
    required this.cow,
  });

  @override
  State<CollarImportScreen> createState() => _CollarImportScreenState();
}

class _CollarImportScreenState extends State<CollarImportScreen> {
  late final CollarBluetoothService _btService;

  @override
  void initState() {
    super.initState();
    _btService = CollarBluetoothService();
  }

  @override
  void dispose() {
    _btService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CollarImportController(
            provider: FileCollarDataProvider(),
          ),
        ),
        ChangeNotifierProvider.value(value: _btService),
      ],
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
                    widget.cow.displayName,
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
        body: _CollarImportView(cow: widget.cow),
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
    final btService = context.watch<CollarBluetoothService>();
    final history = controller.history;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Animal & Purpose Header
          _buildInfoCard(context),
          const SizedBox(height: 16),

          // Live Collar Hardware Section (Bluetooth HC-05 Stream)
          _buildHardwareSection(context, btService, controller),
          const SizedBox(height: 16),

          // File Datasets Selector (Backup / Offline)
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

  Widget _buildHardwareSection(
    BuildContext context,
    CollarBluetoothService btService,
    CollarImportController controller,
  ) {
    final t = AppLocalizations.of(context);
    final isStreaming = btService.isStreaming;
    final packet = btService.latestPacket;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (btService.state) {
      case CollarConnectionState.disconnected:
        statusColor = AppColors.textSecondary;
        statusText = t.translate('collarDisconnected');
        statusIcon = Icons.bluetooth_disabled_rounded;
        break;
      case CollarConnectionState.connecting:
        statusColor = AppColors.warning;
        statusText = t.translate('connectingToCollar');
        statusIcon = Icons.bluetooth_searching_rounded;
        break;
      case CollarConnectionState.streaming:
        statusColor = AppColors.success;
        statusText = t.translate('collarConnectedStreaming');
        statusIcon = Icons.sensors_rounded;
        break;
      case CollarConnectionState.error:
        statusColor = AppColors.error;
        statusText = 'Connection Error';
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStreaming ? AppColors.success.withValues(alpha: 0.5) : AppColors.border,
          width: isStreaming ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 20, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.translate('collarHardwareConnection'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (btService.state == CollarConnectionState.error && btService.errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      btService.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Live sensor telemetry cards when streaming
          if (isStreaming && packet != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _sensorMiniCard(
                          label: t.translate('ambientTemp'),
                          value: '${packet.ambientTemp} °C',
                          sub: 'DHT22',
                          icon: Icons.thermostat_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sensorMiniCard(
                          label: t.translate('humidity'),
                          value: '${packet.humidity} %',
                          sub: 'THI: ${packet.thi}',
                          icon: Icons.water_drop_outlined,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _sensorMiniCard(
                          label: t.translate('accelerometer'),
                          value: '[${packet.accX}, ${packet.accY}]',
                          sub: 'Idx: ${packet.activityIndex.toStringAsFixed(0)}',
                          icon: Icons.screen_rotation_rounded,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sensorMiniCard(
                          label: t.translate('tissueContact'),
                          value: packet.isWorn ? t.translate('contactDetected') : t.translate('noContact'),
                          sub: 'IR: ${packet.irValue}',
                          icon: Icons.favorite_rounded,
                          color: packet.isWorn ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: t.translate('syncCollarData'),
              icon: Icons.cloud_download_rounded,
              backgroundColor: AppColors.primary,
              onPressed: () {
                final hist = btService.toCollarHistory(cowId: cow.id);
                controller.setCollarHistory(hist, sourceName: 'HC-05 Live Hardware');
              },
            ),
            const SizedBox(height: 8),
          ],

          // Connect / Disconnect and Simulation triggers
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openDevicePicker(context, btService),
                  icon: const Icon(Icons.bluetooth_rounded, size: 16),
                  label: Text(
                    isStreaming ? btService.connectedDeviceName ?? 'HC-05' : t.translate('connectBluetoothCollar'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  btService.startDemoSimulation(expectedCowId: cow.id);
                  // Also auto push initial history into controller
                  Future.delayed(const Duration(milliseconds: 1300), () {
                    final hist = btService.toCollarHistory(cowId: cow.id);
                    controller.setCollarHistory(hist, sourceName: 'Arduino Collar (Live)');
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  side: const BorderSide(color: AppColors.secondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline_rounded, size: 16, color: AppColors.secondary),
                    SizedBox(width: 4),
                    Text('Demo Stream', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sensorMiniCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _openDevicePicker(BuildContext context, CollarBluetoothService btService) async {
    final t = AppLocalizations.of(context);
    final devices = await btService.getPairedDevices();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bluetooth_audio_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      t.translate('selectCollarDevice'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No paired devices found. Please pair HC-05 in Android Bluetooth Settings.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                else
                  ...devices.map(
                    (d) => ListTile(
                      leading: const Icon(Icons.devices_other_rounded, color: AppColors.primary),
                      title: Text(d['name'] ?? 'HC-05', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(d['address'] ?? '', style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        Navigator.pop(ctx);
                        btService.connect(
                          d['name'] ?? 'HC-05',
                          d['address'] ?? '',
                          expectedCowId: cow.id,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
          const Icon(Icons.sensors_rounded, size: 48, color: AppColors.textMuted),
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

          // Signal verification badges
          Text(
            t.translate('signalChannelsVerified'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildChannelBadge(t.translate('activity'), Icons.directions_run_rounded),
              _buildChannelBadge(t.translate('skinTemperature'), Icons.thermostat_rounded),
              _buildChannelBadge(t.translate('ambientTemperature'), Icons.cloud_outlined),
              _buildChannelBadge(t.translate('humidity'), Icons.water_drop_outlined),
              _buildChannelBadge(t.translate('thiStressIndex'), Icons.wb_sunny_outlined),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
