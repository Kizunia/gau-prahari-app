import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/review_request.dart';

/// Renders the immutable clinical snapshot attached to a review request.
/// Designed for clinical clarity, modern visual hierarchy, and 100% responsiveness on all screen sizes.
class SnapshotView extends StatelessWidget {
  final ReviewRequest request;

  const SnapshotView({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final cow = request.cowSnapshot;
    final prediction = request.predictionSnapshot;
    final milk = request.milkSnapshot;
    final collar = request.collarSnapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Cow Profile Snapshot
        _buildSectionCard(
          title: 'Cow Profile (Snapshot)',
          icon: Icons.pets_rounded,
          badge: request.cowTagNumber.isNotEmpty ? request.cowTagNumber : request.cowId,
          children: [
            _buildRow('Cow ID / Tag', '${request.cowId} (${request.cowTagNumber})'),
            if (cow?.name != null && cow!.name!.isNotEmpty)
              _buildRow('Cow Name', cow.name!),
            _buildRow('Breed', cow?.breed ?? 'Unknown'),
            _buildRow('Age', '${cow?.ageYears ?? 0} years'),
            _buildRow('Lactation Stage', cow?.lactationStage ?? 'Not specified'),
            _buildRow(
              'Status at Submission',
              cow?.status ?? 'Submitted',
              isHighlight: true,
              valueColor: (cow?.status.toLowerCase().contains('quarantine') ?? false)
                  ? AppColors.error
                  : AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. AI Prediction Snapshot
        if (prediction != null) ...[
          _buildPredictionCard(prediction),
          const SizedBox(height: 12),
        ],

        // 3. Milk Measurement Snapshot
        if (milk != null) ...[
          _buildMilkSection(milk),
          const SizedBox(height: 12),
        ],

        // 4. Collar History Snapshot
        if (collar != null) ...[
          _buildCollarSection(collar),
          const SizedBox(height: 12),
        ],

        // 5. Immutable snapshot notice banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cryptographically Immutable Record',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Preserves exact diagnostic metrics and telemetry captured at consultation submission.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCard(dynamic prediction) {
    final isHigh = prediction.riskLevel.toString().toUpperCase() == 'HIGH';
    final isModerate = prediction.riskLevel.toString().toUpperCase() == 'MODERATE';
    final riskColor = isHigh
        ? AppColors.error
        : (isModerate ? AppColors.warning : AppColors.success);
    final riskBg = isHigh
        ? AppColors.errorLight
        : (isModerate ? AppColors.warningLight : AppColors.successLight);

    final isMastitis = prediction.prediction == 1;
    final factors = prediction.factors is List ? (prediction.factors as List) : <dynamic>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.psychology_rounded, size: 16, color: riskColor),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Mastitis Prediction (Snapshot)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${prediction.riskLevel} RISK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: riskColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Prediction Outcome Pill Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: riskBg.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: riskColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  isMastitis ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: riskColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMastitis ? 'Mastitis Detected' : 'Healthy / Low Risk',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                        ),
                      ),
                      if (prediction.probability != null)
                        Text(
                          'Model Confidence: ${(prediction.probability! * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: riskColor.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Confidence Progress Bar
          if (prediction.probability != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (prediction.probability as num).toDouble().clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              ),
            ),
          ],

          // Key Contributing Factors Section (Rendered as individual bullet callouts to prevent flex overflow)
          if (factors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.troubleshoot_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Key Contributing Factors (${factors.length}):',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...factors.map<Widget>((factor) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.fiber_manual_record_rounded,
                        size: 8,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        factor.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Clinical Recommendation Callout
          if (prediction.recommendedAction != null &&
              prediction.recommendedAction.toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Clinical Recommendation',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prediction.recommendedAction.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilkSection(dynamic milk) {
    final sccVal = milk.scc is num ? (milk.scc as num).toInt() : 0;
    final condVal = milk.conductivity is num ? (milk.conductivity as num).toDouble() : 0.0;
    final phVal = milk.ph is num ? (milk.ph as num).toDouble() : 0.0;
    final tempVal = milk.milkTemperature is num ? (milk.milkTemperature as num).toDouble() : 0.0;
    final fatVal = milk.fat is num ? (milk.fat as num).toDouble() : 0.0;
    final snfVal = milk.snf is num ? (milk.snf as num).toDouble() : 0.0;

    return _buildSectionCard(
      title: 'Milk Measurement (Snapshot)',
      icon: Icons.water_drop_rounded,
      children: [
        Row(
          children: [
            _buildMetricTile(
              label: 'Somatic Cells (SCC)',
              value: '$sccVal',
              unit: 'cells/mL',
              icon: Icons.grain_rounded,
              isAlert: sccVal > 250000,
            ),
            const SizedBox(width: 8),
            _buildMetricTile(
              label: 'Conductivity',
              value: condVal.toStringAsFixed(2),
              unit: 'mS/cm',
              icon: Icons.bolt_rounded,
              isAlert: condVal > 6.5,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetricTile(
              label: 'pH Level',
              value: phVal.toStringAsFixed(2),
              unit: 'pH',
              icon: Icons.science_rounded,
              isAlert: phVal < 6.4 || phVal > 6.8,
            ),
            const SizedBox(width: 8),
            _buildMetricTile(
              label: 'Milk Temp',
              value: tempVal.toStringAsFixed(1),
              unit: '°C',
              icon: Icons.thermostat_rounded,
              isAlert: tempVal > 39.0,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetricTile(
              label: 'Fat Content',
              value: fatVal.toStringAsFixed(1),
              unit: '%',
              icon: Icons.opacity_rounded,
            ),
            const SizedBox(width: 8),
            _buildMetricTile(
              label: 'Solids-Not-Fat (SNF)',
              value: snfVal.toStringAsFixed(1),
              unit: '%',
              icon: Icons.pie_chart_outline_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollarSection(dynamic collar) {
    final activity = collar.meanActivity is num ? (collar.meanActivity as num).toDouble() : 0.0;
    final skinTemp = collar.meanSkinTemperature is num ? (collar.meanSkinTemperature as num).toDouble() : 0.0;
    final ambTemp = collar.meanAmbientTemperature is num ? (collar.meanAmbientTemperature as num).toDouble() : 0.0;
    final humidity = collar.meanHumidity is num ? (collar.meanHumidity as num).toDouble() : 0.0;
    final thi = collar.meanThi is num ? (collar.meanThi as num).toDouble() : 0.0;
    final count = collar.recordCount is num ? (collar.recordCount as num).toInt() : 0;

    return _buildSectionCard(
      title: '14-Day Collar Telemetry (Snapshot)',
      icon: Icons.timeline_rounded,
      badge: '$count readings',
      children: [
        Row(
          children: [
            _buildMetricTile(
              label: 'Mean Activity',
              value: activity.toStringAsFixed(1),
              unit: '/ 100',
              icon: Icons.directions_run_rounded,
            ),
            const SizedBox(width: 8),
            _buildMetricTile(
              label: 'Mean Skin Temp',
              value: skinTemp.toStringAsFixed(1),
              unit: '°C',
              icon: Icons.device_thermostat_rounded,
              isAlert: skinTemp > 39.0,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetricTile(
              label: 'Ambient Temp',
              value: ambTemp.toStringAsFixed(1),
              unit: '°C',
              icon: Icons.wb_sunny_outlined,
            ),
            const SizedBox(width: 8),
            _buildMetricTile(
              label: 'Mean Humidity',
              value: humidity.toStringAsFixed(1),
              unit: '%',
              icon: Icons.water_drop_outlined,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetricTile(
              label: 'Mean THI Index',
              value: thi.toStringAsFixed(1),
              unit: 'index',
              icon: Icons.speed_rounded,
              isAlert: thi > 78.0,
            ),
            const SizedBox(width: 8),
            _buildMetricTile(
              label: 'Telemetry Records',
              value: '$count',
              unit: 'samples',
              icon: Icons.history_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    bool isAlert = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isAlert
              ? AppColors.errorLight.withValues(alpha: 0.25)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAlert
                ? AppColors.error.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isAlert ? AppColors.error : AppColors.primary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isAlert ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
