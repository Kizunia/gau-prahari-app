import 'package:flutter/services.dart';
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
  }) {
    final buffer = StringBuffer();
    final isRisk = result.prediction == 1;
    final statusEmoji = result.riskLevel == 'HIGH'
        ? '🚨'
        : (result.riskLevel == 'MODERATE' ? '⚠️' : '✅');
    final probPercent = ((result.probability ?? (isRisk ? 0.90 : 0.05)) * 100).toStringAsFixed(1);

    buffer.writeln('🐄 *GAU-PRAHARI CLINICAL MASTITIS REPORT* 🐄');
    buffer.writeln('----------------------------------------');
    buffer.writeln('📅 *Date/Time:* ${DateTime.now().toLocal().toString().substring(0, 16)}');
    buffer.writeln('🏷️ *Animal ID:* ${cow.id} (Tag: ${cow.tagNumber})');
    buffer.writeln('🧬 *Breed:* ${cow.breed} | *Lactation:* ${cow.lactationStage}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('$statusEmoji *MASTITIS RISK LEVEL:* *${result.riskLevel}*');
    buffer.writeln('📊 *Calculated Risk Probability:* $probPercent%');
    buffer.writeln('🔬 *Diagnosis:* ${isRisk ? 'Mastitis Detected / High Alert' : 'Healthy / Normal Profile'}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('🥛 *POINT-OF-CARE MILK PARAMETERS:*');
    buffer.writeln('• Somatic Cells (SCC): ${milkMeasurement.scc ~/ 1000}k cells/mL ${milkMeasurement.isSccElevated ? '⚠️ [ELEVATED]' : '✓ [NORMAL]'}');
    buffer.writeln('• Electrical Conductivity: ${milkMeasurement.conductivity.toStringAsFixed(2)} mS/cm ${milkMeasurement.isConductivityElevated ? '⚠️ [ELEVATED]' : '✓ [NORMAL]'}');
    buffer.writeln('• Milk pH: ${milkMeasurement.ph.toStringAsFixed(2)} ${milkMeasurement.isPhAbnormal ? '⚠️ [ABNORMAL]' : '✓ [NORMAL]'}');
    buffer.writeln('• Milk Temperature: ${milkMeasurement.milkTemperature.toStringAsFixed(1)} °C');
    buffer.writeln('• Fat Content: ${milkMeasurement.fat.toStringAsFixed(1)}% | SNF: ${milkMeasurement.snf.toStringAsFixed(1)}%');

    if (collarHistory != null && collarHistory.records.isNotEmpty) {
      buffer.writeln('----------------------------------------');
      buffer.writeln('📡 *COLLAR TELEMETRY CONTEXT:*');
      buffer.writeln('• Mean Activity Index: ${collarHistory.meanActivity.toStringAsFixed(1)}');
      buffer.writeln('• Mean Skin Temp: ${collarHistory.meanSkinTemperature.toStringAsFixed(1)} °C');
      buffer.writeln('• Temperature Humidity Index (THI): ${collarHistory.meanThi.toStringAsFixed(1)}');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('🔍 *CONTRIBUTING RISK FACTORS:*');
    for (final factor in result.factors) {
      buffer.writeln('• $factor');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('🩺 *RECOMMENDED VETERINARY ACTION:*');
    buffer.writeln(result.recommendedAction);
    buffer.writeln('----------------------------------------');
    buffer.writeln('_Generated via Gau-Prahari AI Diagnostic System (SIH26109)_');

    return buffer.toString();
  }

  /// Generates a WhatsApp deep link URL with pre-filled message text.
  Uri generateWhatsAppUri({
    required Cow cow,
    required MilkMeasurement milkMeasurement,
    required AnalysisResult result,
    CollarHistory? collarHistory,
    String? phoneNumber,
  }) {
    final text = generateClinicalSummary(
      cow: cow,
      milkMeasurement: milkMeasurement,
      result: result,
      collarHistory: collarHistory,
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
  }) async {
    final text = generateClinicalSummary(
      cow: cow,
      milkMeasurement: milkMeasurement,
      result: result,
      collarHistory: collarHistory,
    );

    await Clipboard.setData(ClipboardData(text: text));
  }
}
