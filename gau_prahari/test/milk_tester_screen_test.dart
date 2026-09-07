import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/cow_selection/domain/entities/cow.dart';
import 'package:gau_prahari/features/milk_tester/presentation/screens/milk_tester_screen.dart';

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

  testWidgets('MilkTesterScreen renders cow details and empty measurement state', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MilkTesterScreen(cow: testCow),
      ),
    );
    await tester.pumpAndSettle();

    // Verify animal header and status
    expect(find.text('Handheld Milk Tester'), findsOneWidget);
    expect(find.text('COW-104'), findsWidgets);
    expect(find.text('Tester Standby (Mock Provider)'), findsOneWidget);
    expect(find.text('No Milk Measurement Yet'), findsOneWidget);
    expect(find.text('Start Milk Sample Analysis'), findsOneWidget);
  });

  testWidgets('Triggering measurement samples and displays 6 metric cards', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MilkTesterScreen(cow: testCow),
      ),
    );
    await tester.pumpAndSettle();

    // Tap trigger button
    final triggerBtn = find.text('Start Milk Sample Analysis');
    await tester.ensureVisible(triggerBtn);
    await tester.tap(triggerBtn);

    // Pump past the simulated delays
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Verify completion status and 6 metric cards
    expect(find.text('Milk Sample Captured Successfully'), findsOneWidget);
    expect(find.text('Sample Measurements'), findsOneWidget);
    expect(find.text('Valid Sample'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('pH Value'), findsOneWidget);
    expect(find.text('Conductivity'), findsOneWidget);
    expect(find.text('Somatic Cell Count'), findsOneWidget);
    expect(find.text('Fat Content'), findsOneWidget);
    expect(find.text('SNF (Solids)'), findsOneWidget);
    expect(find.text('Proceed to Mastitis Risk Analysis'), findsOneWidget);
  });
}
