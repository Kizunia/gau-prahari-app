import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/core/localization/locale_controller.dart';
import 'package:gau_prahari/features/auth/domain/entities/user.dart';
import 'package:gau_prahari/features/auth/domain/repositories/auth_repository.dart';
import 'package:gau_prahari/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gau_prahari/main.dart';

class MockPipelineAuthRepository implements AuthRepository {
  User? _user;
  bool _loggedIn = false;

  @override
  Future<User> login({required String identifier, required String password}) async {
    _user = User(
      id: 'USR-101',
      name: 'Dr. Rajesh Sharma',
      identifier: identifier,
      role: 'Field Veterinarian',
      isDemo: true,
    );
    _loggedIn = true;
    return _user!;
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _user = User(
      id: 'USR-101',
      name: name,
      identifier: email,
      role: role,
    );
    _loggedIn = true;
    return _user!;
  }

  @override
  Future<User> loginDemo({required String role}) async {
    _user = User(
      id: 'USR-101',
      name: 'Dr. Rajesh Sharma',
      identifier: 'vet@gauprahari.org',
      role: role,
      isDemo: true,
    );
    _loggedIn = true;
    return _user!;
  }

  @override
  Future<void> logout() async {
    _user = null;
    _loggedIn = false;
  }

  @override
  Future<User?> getCurrentUser() async => _user;

  @override
  Future<bool> isLoggedIn() async => _loggedIn;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'gau_prahari_locale': 'en'});
  });

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('Complete End-to-End Prototype Flow: Login -> Select Cow -> Import Collar -> Milk Test -> ML Inference -> Result', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authRepo = MockPipelineAuthRepository();
    final authController = AuthController(authRepository: authRepo);
    await authController.checkAuthStatus();
    final localeController = LocaleController();
    await localeController.loadSavedLocale();

    await tester.pumpWidget(GauPrahariApp(authController: authController, localeController: localeController));
    await tester.pumpAndSettle();

    // 1. Login Screen -> Tap Field Vet chip & Sign In
    expect(find.text('Sign In to Gau-Prahari'), findsOneWidget);
    final vetChip = find.text('Field Vet');
    await tester.ensureVisible(vetChip);
    await tester.tap(vetChip);
    await tester.pumpAndSettle();

    final signInBtn = find.text('Sign In to Gau-Prahari');
    await tester.ensureVisible(signInBtn);
    await tester.tap(signInBtn);
    await tester.pumpAndSettle();

    // 2. Cow Selection Screen -> Select COW-104
    expect(find.text('Select Animal for Analysis'), findsOneWidget);
    expect(find.text('COW-104'), findsOneWidget);
    final cowCard = find.text('COW-104');
    await tester.ensureVisible(cowCard);
    await tester.tap(cowCard);
    await tester.pumpAndSettle();

    // 3. Collar Import Screen -> Load 14-day CSV dataset
    expect(find.text('Smart Collar History'), findsOneWidget);
    final demoCsvChip = find.text('COW-104 CSV (14 Days)');
    await tester.ensureVisible(demoCsvChip);
    await tester.tap(demoCsvChip);
    await tester.pumpAndSettle();

    expect(find.text('14 Days Telemetry Imported'), findsOneWidget);

    // Proceed to Milk Tester
    final continueToMilkBtn = find.text('Continue to Milk Tester');
    await tester.ensureVisible(continueToMilkBtn);
    await tester.tap(continueToMilkBtn);
    await tester.pumpAndSettle();

    // 4. Handheld Milk Tester Screen -> Start Sample Analysis
    expect(find.text('Handheld Milk Tester'), findsOneWidget);
    expect(find.textContaining('Collar Telemetry Attached: 14 Days'), findsOneWidget);

    final startMilkBtn = find.text('Start Milk Sample Analysis');
    await tester.ensureVisible(startMilkBtn);
    await tester.tap(startMilkBtn);

    // Pump past the simulation timers
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.text('Sample Measurements'), findsOneWidget);
    expect(find.text('Proceed to Mastitis Risk Analysis'), findsOneWidget);

    // 5. Trigger ML Inference
    final proceedAnalysisBtn = find.text('Proceed to Mastitis Risk Analysis');
    await tester.ensureVisible(proceedAnalysisBtn);
    await tester.tap(proceedAnalysisBtn);
    await tester.pumpAndSettle();

    // 6. Analysis Result Screen verification
    expect(find.text('Mastitis Risk Assessment'), findsOneWidget);
    expect(find.text('HIGH MASTITIS RISK'), findsOneWidget);
    expect(find.text('AI Model Risk Confidence'), findsOneWidget);
    expect(find.text('Key Diagnostic Drivers'), findsOneWidget);
    expect(find.text('Recommended Veterinary Action'), findsOneWidget);

    // 7. Complete flow -> Done & Return to Cow Selection
    final doneBtn = find.text('Done & Select Next Animal');
    await tester.ensureVisible(doneBtn);
    await tester.tap(doneBtn);
    await tester.pumpAndSettle();

    expect(find.text('Select Animal for Analysis'), findsOneWidget);
  });
}
