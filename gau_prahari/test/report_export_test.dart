import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:gau_prahari/features/analysis/presentation/widgets/diagnostic_certificate_dialog.dart';
import 'package:gau_prahari/features/analysis/presentation/widgets/share_report_bottom_sheet.dart';
import 'package:gau_prahari/features/analysis/services/report_export_service.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';

void main() {
  const testCow = Cow(
    id: 'COW-104',
    tagNumber: 'TAG-8821',
    breed: 'Gir',
    ageYears: 4,
    lactationStage: 'Early (Day 45)',
  );

  final testMeasurement = MilkMeasurement(
    cowId: 'COW-104',
    milkTemperature: 38.3,
    ph: 7.15,
    conductivity: 6.85,
    scc: 650000,
    fat: 3.2,
    snf: 7.8,
  );

  final testResult = AnalysisResult(
    cowId: 'COW-104',
    prediction: 1,
    probability: 0.95,
    riskLevel: 'HIGH',
    factors: [
      'Elevated Electrical Conductivity (6.85 mS/cm > 5.50 baseline)',
      'Elevated Somatic Cell Count (650,000 cells/mL > 250,000)',
    ],
    recommendedAction: 'Isolate animal immediately. Perform CMT test and contact veterinarian.',
  );

  final testCollarHistory = CollarHistory(
    cowId: 'COW-104',
    records: [
      CollarTelemetry(
        timestamp: DateTime.now(),
        activity: 120.0,
        skinTemperature: 38.5,
        ambientTemperature: 30.0,
        humidity: 60.0,
        thi: 78.0,
      ),
    ],
  );

  group('ReportExportService Unit Tests', () {
    const service = ReportExportService();

    test('Generates comprehensive formatted text summary for High Risk Mastitis', () {
      final summary = service.generateClinicalSummary(
        cow: testCow,
        milkMeasurement: testMeasurement,
        result: testResult,
        collarHistory: testCollarHistory,
      );

      expect(summary, contains('GAU-PRAHARI CLINICAL MASTITIS REPORT'));
      expect(summary, contains('COW-104'));
      expect(summary, contains('TAG-8821'));
      expect(summary, contains('MASTITIS RISK LEVEL:* *HIGH*'));
      expect(summary, contains('650k cells/mL'));
      expect(summary, contains('6.85 mS/cm'));
      expect(summary, contains('Elevated Electrical Conductivity'));
      expect(summary, contains('Isolate animal immediately'));
      expect(summary, contains('COLLAR TELEMETRY CONTEXT'));
    });

    test('Generates valid WhatsApp URI with pre-filled encoded text', () {
      final uri = service.generateWhatsAppUri(
        cow: testCow,
        milkMeasurement: testMeasurement,
        result: testResult,
        phoneNumber: '+91 98765 43210',
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('api.whatsapp.com'));
      expect(uri.queryParameters['phone'], equals('919876543210'));
      expect(uri.queryParameters['text'], contains('GAU-PRAHARI'));
    });
  });

  group('Clinical Report UI & Dialog Widget Tests', () {
    testWidgets('DiagnosticCertificateDialog renders correctly with medical card details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiagnosticCertificateDialog(
              cow: testCow,
              milkMeasurement: testMeasurement,
              result: testResult,
              collarHistory: testCollarHistory,
            ),
          ),
        ),
      );

      expect(find.text('Gau-Prahari Clinical Card'), findsOneWidget);
      expect(find.text('Animal: COW-104 (Tag: TAG-8821)'), findsOneWidget);
      expect(find.text('Risk: HIGH'), findsOneWidget);
      expect(find.text('Prob: 95.0%'), findsOneWidget);
      expect(find.text('650k /mL'), findsOneWidget);
      expect(find.text('Copy Summary'), findsOneWidget);
    });

    testWidgets('ShareReportBottomSheet renders all sharing options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareReportBottomSheet(
              cow: testCow,
              milkMeasurement: testMeasurement,
              result: testResult,
              collarHistory: testCollarHistory,
            ),
          ),
        ),
      );

      expect(find.text('Export & Share Report'), findsOneWidget);
      expect(find.text('Share via WhatsApp'), findsOneWidget);
      expect(find.text('Copy Summary to Clipboard'), findsOneWidget);
      expect(find.text('View Diagnostic Certificate Card'), findsOneWidget);
    });

    testWidgets('AnalysisResultScreen has Share Clinical Report button and opens bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AnalysisResultScreen(
            cow: testCow,
            milkMeasurement: testMeasurement,
            result: testResult,
            collarHistory: testCollarHistory,
          ),
        ),
      );

      final shareBtn = find.text('Share Clinical Report / WhatsApp');
      await tester.scrollUntilVisible(
        shareBtn,
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(shareBtn, findsOneWidget);

      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(find.text('Export & Share Report'), findsOneWidget);
      expect(find.text('Share via WhatsApp'), findsOneWidget);
    });
  });
}
