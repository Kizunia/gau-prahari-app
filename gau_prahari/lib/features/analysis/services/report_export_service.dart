import 'package:flutter/services.dart';
import 'package:gau_prahari/core/localization/app_localizations.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';

/// Service responsible for generating formatted clinical reports, WhatsApp share links,
/// and clipboard summaries for veterinary officers and dairy cooperatives.
class ReportExportService {
  const ReportExportService();

  /// Generates a structured clinical summary text formatted for WhatsApp, SMS, or Email.
  String generateClinicalSummary({
    required Cow cow,
    required MilkMeasurement milkMeasurement,
    required AnalysisResult result,
    CollarHistory? collarHistory,
    AppLocalizations? localizations,
  }) {
    final buffer = StringBuffer();
    final isRisk = result.prediction == 1;
    final statusEmoji = result.riskLevel == 'HIGH'
        ? '🚨'
        : (result.riskLevel == 'MODERATE' ? '⚠️' : '✅');
    final probPercent = ((result.probability ?? (isRisk ? 0.90 : 0.05)) * 100).toStringAsFixed(1);

    final title = localizations != null ? localizations.translate('reportTitle') : 'GAU-PRAHARI CLINICAL MASTITIS REPORT';
    final dtLabel = localizations != null ? localizations.translate('reportDateTime') : 'Date/Time';
    final riskLevelLabel = localizations != null ? localizations.translate('reportRiskLevel') : 'MASTITIS RISK LEVEL';
    final calcRiskLabel = localizations != null ? localizations.translate('reportCalculatedRisk') : 'Calculated Risk Probability';
    final diagnosisLabel = localizations != null ? localizations.translate('reportDiagnosis') : 'Diagnosis';
    final diagHigh = localizations != null ? localizations.translate('reportDiagnosisHigh') : 'Mastitis Detected / High Alert';
    final diagNormal = localizations != null ? localizations.translate('reportDiagnosisNormal') : 'Healthy / Normal Profile';
    final milkParamsLabel = localizations != null ? localizations.translate('reportMilkParams') : 'POINT-OF-CARE MILK PARAMETERS';
    final collarLabel = localizations != null ? localizations.translate('reportCollarTelemetry') : 'COLLAR TELEMETRY CONTEXT';
    final factorsLabel = localizations != null ? localizations.translate('reportContributingFactors') : 'CONTRIBUTING RISK FACTORS';
    final recActionLabel = localizations != null ? localizations.translate('reportRecommendedAction') : 'RECOMMENDED VETERINARY ACTION';
    final footer = localizations != null ? localizations.translate('reportGeneratedVia') : 'Generated via Gau-Prahari AI Diagnostic System (SIH26109)';

    final breed = localizations != null ? localizations.translateBreed(cow.breed) : cow.breed;
    final lactation = localizations != null ? localizations.translateLactation(cow.lactationStage) : cow.lactationStage;
    final breedPrefix = localizations != null ? localizations.translate('breedPrefix') : 'Breed:';
    final lactationPrefix = localizations != null ? localizations.translate('lactationPrefix') : 'Lactation:';

    buffer.writeln('🐄 *$title* 🐄');
    buffer.writeln('----------------------------------------');
    buffer.writeln('📅 *$dtLabel:* ${DateTime.now().toLocal().toString().substring(0, 16)}');
    final cowLabel = (cow.name != null && cow.name!.trim().isNotEmpty) ? '${cow.name} (ID: ${cow.id})' : cow.id;
    buffer.writeln('🏷️ *Animal:* $cowLabel (Tag: ${cow.tagNumber})');
    buffer.writeln('🧬 *$breedPrefix* $breed | *$lactationPrefix* $lactation');
    buffer.writeln('----------------------------------------');
    buffer.writeln('$statusEmoji *$riskLevelLabel:* *${result.riskLevel}*');
    buffer.writeln('📊 *$calcRiskLabel:* $probPercent%');
    buffer.writeln('🔬 *$diagnosisLabel:* ${isRisk ? diagHigh : diagNormal}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('🥛 *$milkParamsLabel:*');
    buffer.writeln('• Somatic Cells (SCC): ${milkMeasurement.scc ~/ 1000}k cells/mL ${milkMeasurement.isSccElevated ? '⚠️ [ELEVATED]' : '✓ [NORMAL]'}');
    buffer.writeln('• Electrical Conductivity: ${milkMeasurement.conductivity.toStringAsFixed(2)} mS/cm ${milkMeasurement.isConductivityElevated ? '⚠️ [ELEVATED]' : '✓ [NORMAL]'}');
    buffer.writeln('• Milk pH: ${milkMeasurement.ph.toStringAsFixed(2)} ${milkMeasurement.isPhAbnormal ? '⚠️ [ABNORMAL]' : '✓ [NORMAL]'}');
    buffer.writeln('• Milk Temperature: ${milkMeasurement.milkTemperature.toStringAsFixed(1)} °C');
    buffer.writeln('• Fat Content: ${milkMeasurement.fat.toStringAsFixed(1)}% | SNF: ${milkMeasurement.snf.toStringAsFixed(1)}%');

    if (collarHistory != null && collarHistory.records.isNotEmpty) {
      buffer.writeln('----------------------------------------');
      buffer.writeln('📡 *$collarLabel:*');
      buffer.writeln('• Mean Activity Index: ${collarHistory.meanActivity.toStringAsFixed(1)}');
      buffer.writeln('• Mean Skin Temp: ${collarHistory.meanSkinTemperature.toStringAsFixed(1)} °C');
      buffer.writeln('• Temperature Humidity Index (THI): ${collarHistory.meanThi.toStringAsFixed(1)}');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('🔍 *$factorsLabel:*');
    for (final factor in result.factors) {
      final translatedFactor = localizations != null ? localizations.translateFactor(factor) : factor;
      buffer.writeln('• $translatedFactor');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('🩺 *$recActionLabel:*');
    final recommendation = localizations != null
        ? localizations.translateRecommendation(result.recommendedAction, result.riskLevel)
        : result.recommendedAction;
    buffer.writeln(recommendation);
    buffer.writeln('----------------------------------------');
    buffer.writeln('_${footer}_');

    return buffer.toString();
  }

  /// Generates a WhatsApp deep link URL with pre-filled message text.
  Uri generateWhatsAppUri({
    required Cow cow,
    required MilkMeasurement milkMeasurement,
    required AnalysisResult result,
    CollarHistory? collarHistory,
    String? phoneNumber,
    AppLocalizations? localizations,
  }) {
    final text = generateClinicalSummary(
      cow: cow,
      milkMeasurement: milkMeasurement,
      result: result,
      collarHistory: collarHistory,
      localizations: localizations,
    );

    final cleanPhone = phoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    final encodedText = Uri.encodeComponent(text);

    if (cleanPhone.isNotEmpty) {
      return Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedText');
    }
    return Uri.parse('https://api.whatsapp.com/send?text=$encodedText');
  }

  /// Copies the formatted report to the device clipboard.
  Future<void> copyReportToClipboard({
    required Cow cow,
    required MilkMeasurement milkMeasurement,
    required AnalysisResult result,
    CollarHistory? collarHistory,
    AppLocalizations? localizations,
  }) async {
    final text = generateClinicalSummary(
      cow: cow,
      milkMeasurement: milkMeasurement,
      result: result,
      collarHistory: collarHistory,
      localizations: localizations,
    );

    await Clipboard.setData(ClipboardData(text: text));
  }
}
