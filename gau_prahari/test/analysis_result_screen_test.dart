import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';

void main() {
  const testCow = Cow(
    id: 'COW-104',
    tagNumber: 'RFID-9821',
    breed: 'Gir / Sahiwal Cross',
    ageYears: 4,
    lactationStage: 'Early Lactation',
  );

  final testMilk = MilkMeasurement(
    cowId: 'COW-104',
    milkTemperature: 36.9,
    ph: 6.78,
    conductivity: 6.18,
    scc: 380000,
    fat: 3.8,
    snf: 8.4,
  );

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('Renders High Risk result with factors and clinical recommendations', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final highRiskResult = AnalysisResult(
      cowId: 'COW-104',
      prediction: 1,
      probability: 0.88,
      riskLevel: 'HIGH',
      factors: [
        'Elevated Somatic Cell Count (380,000 cells/mL > 250,000 threshold)',
        'Elevated Electrical Conductivity (6.18 mS/cm > 5.80 baseline)',
      ],
      recommendedAction: 'Isolate animal immediately. Perform CMT test.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisResultScreen(
          cow: testCow,
          milkMeasurement: testMilk,
          result: highRiskResult,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mastitis Risk Assessment'), findsOneWidget);
    expect(find.text('HIGH MASTITIS RISK'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('AI Model Risk Confidence'), findsOneWidget);
    expect(find.text('Key Diagnostic Drivers'), findsOneWidget);
    expect(find.textContaining('Elevated Somatic Cell Count'), findsOneWidget);
    expect(find.textContaining('Elevated Electrical Conductivity'), findsOneWidget);
    expect(find.text('Recommended Veterinary Action'), findsOneWidget);
    expect(find.text('Isolate animal immediately. Perform CMT test.'), findsOneWidget);
    expect(find.text('Done & Select Next Animal'), findsOneWidget);
  });
}
