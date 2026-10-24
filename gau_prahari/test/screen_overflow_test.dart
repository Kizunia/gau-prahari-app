import 'package:gau_prahari/core/localization/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/core/theme/app_theme.dart';
import 'package:gau_prahari/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gau_prahari/features/auth/presentation/screens/login_screen.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/cow_selection/presentation/screens/cow_selection_screen.dart';
import 'package:gau_prahari/features/collar_import/domain/entities/collar_telemetry.dart';
import 'package:gau_prahari/features/collar_import/presentation/screens/collar_import_screen.dart';
import 'package:gau_prahari/features/milk_tester/domain/entities/milk_measurement.dart';
import 'package:gau_prahari/features/milk_tester/presentation/screens/milk_tester_screen.dart';
import 'package:gau_prahari/features/analysis/domain/entities/analysis_result.dart';
import 'package:gau_prahari/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:gau_prahari/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gau_prahari/features/cow_selection/presentation/controllers/cow_controller.dart';
import 'package:gau_prahari/features/cow_selection/data/repositories/cow_repository_impl.dart';
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
    status: 'Ready for Test',
  );

  final List<CollarTelemetry> testCollarRecords = List.generate(
    14,
    (i) => CollarTelemetry(
      timestamp: DateTime(2026, 9, 1 + i, 10, 0),
      activity: 52.0 + (i % 5),
      skinTemperature: 37.8 + (i * 0.05),
      ambientTemperature: 28.0 + (i * 0.2),
      humidity: 65.0 - (i * 0.5),
      thi: 77.5 + (i * 0.1),
    ),
  );

  final testHistory = CollarHistory(
    cowId: 'COW-104',
    records: testCollarRecords,
  );

  final testMeasurement = MilkMeasurement(
    cowId: 'COW-104',
    timestamp: DateTime.now(),
    milkTemperature: 38.6,
    ph: 7.05,
    conductivity: 6.85,
    scc: 540000,
    fat: 3.4,
    snf: 7.8,
  );

  group('Pixel Overflow & Responsiveness Tests (320x568 & TextScaler 1.25)', () {
    testWidgets('LoginScreen renders with no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authRepo = AuthRepositoryImpl();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthController(authRepository: authRepo),
          child: buildResponsiveTestApp(child: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gau-Prahari'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CowSelectionScreen renders with no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authRepo = AuthRepositoryImpl();
      final authCtrl = AuthController(authRepository: authRepo);
      final cowCtrl = CowController(repository: CowRepositoryImpl());
      final localeCtrl = LocaleController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authCtrl),
            ChangeNotifierProvider.value(value: cowCtrl),
            ChangeNotifierProvider.value(value: localeCtrl),
          ],
          child: buildResponsiveTestApp(child: const CowSelectionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COW-104'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CollarImportScreen renders with no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildResponsiveTestApp(
          child: const CollarImportScreen(cow: testCow),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Smart Collar History'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MilkTesterScreen renders all 6 metric cards with no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildResponsiveTestApp(
          child: const MilkTesterScreen(
            cow: testCow,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down slightly so the measurement trigger button is built
      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pumpAndSettle();

      final startBtn = find.text('Start Milk Sample Analysis');
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);

      // Pump through mock BLE & sensor sampling delays
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Check cards rendered
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('pH Value'), findsOneWidget);
      expect(find.text('Conductivity'), findsOneWidget);
      expect(find.text('Somatic Cell Count'), findsOneWidget);
      expect(find.text('Fat Content'), findsOneWidget);
      expect(find.text('SNF (Solids)'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('AnalysisResultScreen renders high risk without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final highRiskResult = AnalysisResult(
        cowId: 'COW-104',
        prediction: 1,
        riskLevel: 'HIGH',
        probability: 0.94,
        factors: const [
          'Critical Electrical Conductivity: 6.85 mS/cm',
          'Severe Somatic Cell Count: 540,000 /mL',
          'Elevated Milk Temp: 38.6 °C with persistent THI stress',
        ],
        recommendedAction: 'Immediate isolation, veterinary CMT validation, and antimicrobial protocol.',
      );

      await tester.pumpWidget(
        buildResponsiveTestApp(
          child: AnalysisResultScreen(
            cow: testCow,
            milkMeasurement: testMeasurement,
            collarHistory: testHistory,
            result: highRiskResult,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HIGH MASTITIS RISK'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.text('Key Diagnostic Drivers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnalysisResultScreen renders moderate subclinical risk without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final subclinicalResult = AnalysisResult(
        cowId: 'COW-104',
        prediction: 0,
        riskLevel: 'MODERATE',
        probability: 0.62,
        factors: const [
          'Elevated Somatic Cell Count: 280,000 /mL',
          'Borderline Electrical Conductivity: 5.60 mS/cm',
        ],
        recommendedAction: 'Perform California Mastitis Test (CMT), increase milking hygiene, monitor daily.',
      );

      await tester.pumpWidget(
        buildResponsiveTestApp(
          child: AnalysisResultScreen(
            cow: testCow,
            milkMeasurement: testMeasurement,
            collarHistory: testHistory,
            result: subclinicalResult,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MODERATE RISK (SUBCLINICAL)'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
