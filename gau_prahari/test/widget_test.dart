import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/core/localization/locale_controller.dart';
import 'package:gau_prahari/features/auth/domain/entities/user.dart';
import 'package:gau_prahari/features/auth/domain/repositories/auth_repository.dart';
import 'package:gau_prahari/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gau_prahari/main.dart';

class MockAuthRepository implements AuthRepository {
  User? _currentUser;
  bool _isLoggedIn = false;

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    if (password == 'wrong') {
      throw Exception('Invalid credentials');
    }
    _currentUser = User(
      id: 'USR-TEST',
      name: 'Test Vet',
      identifier: identifier,
      role: 'Field Veterinarian',
    );
    _isLoggedIn = true;
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
  }

  @override
  Future<User?> getCurrentUser() async => _currentUser;

  @override
  Future<bool> isLoggedIn() async => _isLoggedIn;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'gau_prahari_locale': 'en'});
  });

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('App renders LoginScreen when unauthenticated', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = MockAuthRepository();
    final authController = AuthController(authRepository: mockRepo);
    await authController.checkAuthStatus();
    final localeController = LocaleController();
    await localeController.loadSavedLocale();

    await tester.pumpWidget(GauPrahariApp(authController: authController, localeController: localeController));
    await tester.pumpAndSettle();

    // Verify brand header and login elements appear (English locale)
    expect(find.text('Gau-Prahari'), findsOneWidget);
    expect(find.text('Early Bovine Mastitis Forecasting'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign In to Gau-Prahari'), findsOneWidget);
    expect(find.text('Quick Demo Logins (Tap to prefill)'), findsOneWidget);
  });

  testWidgets('Tapping demo chip pre-fills credentials', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = MockAuthRepository();
    final authController = AuthController(authRepository: mockRepo);
    await authController.checkAuthStatus();
    final localeController = LocaleController();
    await localeController.loadSavedLocale();

    await tester.pumpWidget(GauPrahariApp(authController: authController, localeController: localeController));
    await tester.pumpAndSettle();

    // Tap the 'Field Vet' demo chip
    final chip = find.text('Field Vet');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // Verify text field contains prefilled email
    expect(find.text('vet@gauprahari.org'), findsOneWidget);
  });

  testWidgets('Shows validation errors on empty fields', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = MockAuthRepository();
    final authController = AuthController(authRepository: mockRepo);
    await authController.checkAuthStatus();
    final localeController = LocaleController();
    await localeController.loadSavedLocale();

    await tester.pumpWidget(GauPrahariApp(authController: authController, localeController: localeController));
    await tester.pumpAndSettle();

    // Tap login button with empty fields
    final submitBtn = find.text('Sign In to Gau-Prahari');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify validation errors appear
    expect(find.text('Please enter your Email or Officer/Farmer ID'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('Successful login navigates to CowSelectionScreen', (WidgetTester tester) async {
    setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = MockAuthRepository();
    final authController = AuthController(authRepository: mockRepo);
    await authController.checkAuthStatus();
    final localeController = LocaleController();
    await localeController.loadSavedLocale();

    await tester.pumpWidget(GauPrahariApp(authController: authController, localeController: localeController));
    await tester.pumpAndSettle();

    // Tap demo chip to fill fields
    final chip = find.text('Field Vet');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // Tap submit button
    final submitBtn = find.text('Sign In to Gau-Prahari');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify navigation to CowSelectionScreen
    expect(find.text('Select Animal for Analysis'), findsOneWidget);
    expect(find.text('COW-104'), findsOneWidget);
  });
}
