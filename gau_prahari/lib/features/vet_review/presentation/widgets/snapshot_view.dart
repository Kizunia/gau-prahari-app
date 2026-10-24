import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/review_request.dart';

/// Renders the immutable clinical snapshot attached to a review request.
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
          children: [
            _buildRow('Cow ID / Tag', '${request.cowId} (${request.cowTagNumber})'),
            if (cow?.name != null && cow!.name!.isNotEmpty)
              _buildRow('Cow Name', cow.name!),
            _buildRow('Breed', cow?.breed ?? 'Unknown'),
            _buildRow('Age', '${cow?.ageYears ?? 0} years'),
            _buildRow('Lactation Stage', cow?.lactationStage ?? 'Not specified'),
            _buildRow('Status at Submission', cow?.status ?? 'Submitted'),
          ],
        ),
        const SizedBox(height: 12),

        // 2. AI Prediction Snapshot
        if (prediction != null) ...[
          _buildSectionCard(
            title: 'AI Mastitis Prediction (Snapshot)',
            icon: Icons.psychology_rounded,
            children: [
              _buildRow('Prediction', prediction.prediction == 1 ? 'Mastitis Detected' : 'Healthy'),
              _buildRow('Risk Classification', prediction.riskLevel),
              if (prediction.probability != null)
                _buildRow(
                  'Model Confidence',
                  '${(prediction.probability! * 100).toStringAsFixed(1)} %',
                ),
              if (prediction.factors.isNotEmpty)
                _buildRow('Key Contributing Factors', prediction.factors.join(', ')),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Clinical Recommendation: ${prediction.recommendedAction}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // 3. Milk Measurement Snapshot
        if (milk != null) ...[
          _buildSectionCard(
            title: 'Milk Measurement (Snapshot)',
            icon: Icons.water_drop_rounded,
            children: [
              _buildRow('Milk Temperature', '${milk.milkTemperature.toStringAsFixed(1)} °C'),
              _buildRow('pH Level', milk.ph.toStringAsFixed(2)),
              _buildRow('Electrical Conductivity', '${milk.conductivity.toStringAsFixed(2)} mS/cm'),
              _buildRow('Somatic Cell Count (SCC)', '${milk.scc} cells/mL'),
              _buildRow('Fat Content', '${milk.fat.toStringAsFixed(1)} %'),
              _buildRow('Solids-Not-Fat (SNF)', '${milk.snf.toStringAsFixed(1)} %'),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // 4. Collar History Snapshot
        if (collar != null) ...[
          _buildSectionCard(
            title: '14-Day Collar Telemetry (Snapshot)',
            icon: Icons.timeline_rounded,
            children: [
              _buildRow('Total Telemetry Records', '${collar.recordCount} readings'),
              _buildRow('Mean Activity Index', '${collar.meanActivity.toStringAsFixed(1)} / 100'),
              _buildRow('Mean Skin Temperature', '${collar.meanSkinTemperature.toStringAsFixed(1)} °C'),
              _buildRow('Mean Ambient Temp', '${collar.meanAmbientTemperature.toStringAsFixed(1)} °C'),
              _buildRow('Mean Humidity', '${collar.meanHumidity.toStringAsFixed(1)} %'),
              _buildRow('Mean THI', collar.meanThi.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // 5. Immutable snapshot notice banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This clinical snapshot is cryptographically immutable and preserves the exact state recorded at submission.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 16, color: AppColors.primary),
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
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
