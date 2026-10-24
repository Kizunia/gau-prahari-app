import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/core/theme/app_theme.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/vet_review/domain/entities/review_request.dart';
import 'package:gau_prahari/features/vet_review/domain/entities/review_status.dart';
import 'package:gau_prahari/features/vet_review/presentation/widgets/snapshot_view.dart';
import 'package:gau_prahari/features/vet_review/presentation/widgets/review_request_card.dart';

Widget buildResponsiveTestApp({
  required Widget child,
  Size size = const Size(320, 568),
  double textScale = 1.25,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testCow = Cow(
    id: 'COW-104',
    tagNumber: 'RFID-9821',
    breed: 'Gir / Sahiwal Cross',
    ageYears: 4,
    lactationStage: 'Early Lactation (Day 42)',
    status: 'In Quarantine',
    name: 'Ganga',
  );

  final testMeasurement = MilkMeasurement(
    cowId: 'COW-104',
    milkTemperature: 39.8,
    ph: 6.94,
    conductivity: 7.42,
    scc: 380000,
    fat: 3.1,
    snf: 7.9,
    timestamp: DateTime.now(),
  );

  final testHistory = CollarHistory(
    cowId: 'COW-104',
    records: [
      CollarTelemetry(
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        activity: 42.3,
        skinTemperature: 39.2,
        ambientTemperature: 31.5,
        humidity: 78.4,
        thi: 82.1,
      ),
    ],
  );

  group('SnapshotView Pixel Overflow & Responsiveness Tests', () {
    testWidgets('SnapshotView renders without overflow on 320x568 screen with high-risk multiple factors', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final highRiskResult = AnalysisResult(
        cowId: 'COW-104',
        prediction: 1,
        probability: 0.914,
        riskLevel: 'HIGH',
        factors: const [
          'Elevated Somatic Cell Count (380,000 cells/mL > 250,000 threshold)',
          'Rapid Conductivity Spike (7.42 mS/cm > 6.50 normal)',
          'Elevated Milk Temperature (39.8 °C)',
        ],
        recommendedAction: 'Immediate veterinary consultation and CMT test recommended. Isolate cow from milking line.',
        timestamp: DateTime(2026, 10, 24, 15, 30),
      );

      final snapshotData = ReviewRequest.buildSnapshot(
        cow: testCow,
        result: highRiskResult,
        milkMeasurement: testMeasurement,
        collarHistory: testHistory,
      );

      final reviewReq = ReviewRequest(
        id: 'REQ-TEST-001',
        farmerUid: 'farmer_123',
        veterinarianUid: 'vet_456',
        cowId: testCow.id,
        cowTagNumber: testCow.tagNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ReviewStatus.pending,
        riskLevel: highRiskResult.riskLevel,
        predictionLabel: highRiskResult.isHighRisk ? 'Mastitis Detected' : 'Healthy',
        snapshot: snapshotData,
        farmerNameSnapshot: 'Ramesh Patel',
        veterinarianNameSnapshot: 'Dr. Sharma, DVM',
      );

      await tester.pumpWidget(
        buildResponsiveTestApp(
          child: Scaffold(
            body: SingleChildScrollView(
              child: SnapshotView(request: reviewReq),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Mastitis Prediction (Snapshot)'), findsOneWidget);
      expect(find.text('Mastitis Detected'), findsOneWidget);
      expect(find.text('Key Contributing Factors (3):'), findsOneWidget);
      expect(find.text('Elevated Somatic Cell Count (380,000 cells/mL > 250,000 threshold)'), findsOneWidget);
      expect(find.text('Milk Measurement (Snapshot)'), findsOneWidget);
      expect(find.text('14-Day Collar Telemetry (Snapshot)'), findsOneWidget);
      expect(find.text('Cryptographically Immutable Record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReviewRequestCard renders with long names without overflow on 320x568 screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final reviewReq = ReviewRequest(
        id: 'REQ-LONG-002',
        farmerUid: 'farmer_123',
        veterinarianUid: 'vet_456',
        cowId: 'COW-VERY-LONG-IDENTIFIER-9999',
        cowTagNumber: 'TAG-IN-MAHARASHTRA-PUNE-9999-SPECIAL',
        createdAt: DateTime(2026, 10, 24, 18, 45),
        updatedAt: DateTime(2026, 10, 24, 18, 45),
        status: ReviewStatus.inReview,
        riskLevel: 'HIGH',
        predictionLabel: 'Clinical Mastitis Detected',
        farmerNameSnapshot: 'Suryavanshi Vikramaditya Gaikwad',
        veterinarianNameSnapshot: 'Dr. Rameshwar Chandrashekhar Patel, Senior Specialist',
        snapshot: const {},
      );

      await tester.pumpWidget(
        buildResponsiveTestApp(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ReviewRequestCard(
                request: reviewReq,
                isVetView: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinical Mastitis Detected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
