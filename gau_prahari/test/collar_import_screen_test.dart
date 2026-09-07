import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/collar_import/presentation/screens/collar_import_screen.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';

void main() {
  const testCow = Cow(
    id: 'COW-104',
    tagNumber: 'RFID-9821',
    breed: 'Gir / Sahiwal Cross',
    ageYears: 4,
    lactationStage: 'Early Lactation (Day 42)',
  );

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('CollarImportScreen renders header and empty state', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CollarImportScreen(cow: testCow),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart Collar History'), findsOneWidget);
    expect(find.text('COW-104'), findsWidgets);
    expect(find.text('Longitudinal Animal Telemetry'), findsOneWidget);
    expect(find.text('No Telemetry File Loaded'), findsOneWidget);
    expect(find.text('COW-104 CSV (14 Days)'), findsOneWidget);
  });

  testWidgets('Tapping demo CSV chip loads 14-day telemetry and navigates to MilkTesterScreen', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CollarImportScreen(cow: testCow),
      ),
    );
    await tester.pumpAndSettle();

    // Tap demo dataset chip
    final chip = find.text('COW-104 CSV (14 Days)');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // Verify telemetry summary is displayed
    expect(find.text('14 Days Telemetry Imported'), findsOneWidget);
    expect(find.text('Mean Activity'), findsOneWidget);
    expect(find.text('Mean Skin Temp'), findsOneWidget);
    expect(find.text('Mean THI Index'), findsOneWidget);
    expect(find.text('Signal Channels Verified:'), findsOneWidget);

    // Tap Continue to Milk Tester
    final continueBtn = find.text('Continue to Milk Tester');
    await tester.ensureVisible(continueBtn);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Verify MilkTesterScreen opened with collar telemetry attached
    expect(find.text('Handheld Milk Tester'), findsOneWidget);
    expect(find.textContaining('Collar Telemetry Attached: 14 Days'), findsOneWidget);
  });
}
