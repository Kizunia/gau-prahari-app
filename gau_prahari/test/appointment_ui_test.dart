import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/core/theme/app_theme.dart';
import 'package:gau_prahari/features/appointment_booking/data/repositories/firestore_appointment_repository.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/appointment.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/appointment_slot.dart';
import 'package:gau_prahari/features/appointment_booking/domain/entities/appointment_status.dart';
import 'package:gau_prahari/features/appointment_booking/domain/repositories/appointment_repository.dart';
import 'package:gau_prahari/features/appointment_booking/presentation/screens/appointment_detail_screen.dart';
import 'package:gau_prahari/features/appointment_booking/presentation/screens/farmer_appointments_screen.dart';
import 'package:gau_prahari/features/appointment_booking/presentation/screens/veterinarian_availability_screen.dart';
import 'package:gau_prahari/features/appointment_booking/presentation/screens/veterinarian_directory_screen.dart';
import 'package:gau_prahari/features/auth/domain/entities/user.dart';
import 'package:gau_prahari/features/auth/domain/repositories/auth_repository.dart';
import 'package:gau_prahari/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gau_prahari/features/cow_selection/data/repositories/cow_repository_impl.dart';
import 'package:gau_prahari/features/cow_selection/presentation/controllers/cow_controller.dart';
import 'package:gau_prahari/features/vet_review/data/repositories/firestore_vet_review_repository.dart';
import 'package:gau_prahari/features/vet_review/domain/repositories/vet_review_repository.dart';

class MockAuthRepository implements AuthRepository {
  User? _user;

  void setUser(User user) {
    _user = user;
  }

  @override
  Future<User> login({required String identifier, required String password}) async => _user!;

  @override
  Future<User> loginDemo({required String role}) async => _user!;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async =>
      _user!;

  @override
  Future<void> logout() async {
    _user = null;
  }

  @override
  Future<User?> getCurrentUser() async => _user;

  @override
  Future<bool> isLoggedIn() async => _user != null;
}

Widget buildTestApp({
  required Widget child,
  required AuthController authController,
  required AppointmentRepository appointmentRepository,
  CowController? cowController,
  VetReviewRepository? vetReviewRepository,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: authController),
      ChangeNotifierProvider<CowController>(
        create: (_) => cowController ?? CowController(repository: CowRepositoryImpl()),
      ),
      Provider<AppointmentRepository>.value(value: appointmentRepository),
      Provider<VetReviewRepository>(
        create: (_) => vetReviewRepository ?? FirestoreVetReviewRepository(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Appointment UI & Screen Flow Tests (SRS Section 8 & 11)', () {
    testWidgets('VeterinarianDirectoryScreen renders list of veterinarians and book button', (tester) async {
      final authRepo = MockAuthRepository();
      authRepo.setUser(const User(
        id: 'demo_farmer_001',
        name: 'Ramesh Patel',
        identifier: 'farmer@gauprahari.org',
        role: 'farmer',
        isDemo: true,
      ));
      final authController = AuthController(authRepository: authRepo);
      await authController.checkAuthStatus();

      final appointmentRepo = FirestoreAppointmentRepository(isDemo: true);

      await tester.pumpWidget(
        buildTestApp(
          authController: authController,
          appointmentRepository: appointmentRepo,
          child: const VeterinarianDirectoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book Veterinarian'), findsOneWidget);
      expect(find.text('Dr. Dr. Sharma, DVM'), findsOneWidget);
      expect(find.text('View Slots & Book'), findsWidgets);
    });

    testWidgets('FarmerAppointmentsScreen displays tabs and lists booked appointments', (tester) async {
      final authRepo = MockAuthRepository();
      authRepo.setUser(const User(
        id: 'demo_farmer_001',
        name: 'Ramesh Patel',
        identifier: 'farmer@gauprahari.org',
        role: 'farmer',
        isDemo: true,
      ));
      final authController = AuthController(authRepository: authRepo);
      await authController.checkAuthStatus();
      final farmer = authController.currentUser!;

      final appointmentRepo = FirestoreAppointmentRepository(isDemo: true);

      // Book an appointment first
      final slotStart = DateTime.now().add(const Duration(days: 1, hours: 10));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slot = AppointmentSlot(
        id: 'slot_farmer_view',
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await appointmentRepo.publishSlots('demo_vet_001', [slot]);

      await appointmentRepo.bookAppointment(
        Appointment(
          id: 'appt_farmer_view',
          farmerUid: farmer.id,
          farmerNameSnapshot: farmer.name,
          veterinarianUid: 'demo_vet_001',
          veterinarianNameSnapshot: 'Dr. Sharma, DVM',
          slotId: slot.id,
          cowTagNumber: 'TAG-104',
          startAt: slotStart,
          endAt: slotEnd,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          authController: authController,
          appointmentRepository: appointmentRepo,
          child: const FarmerAppointmentsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Appointments'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past / History'), findsOneWidget);
      expect(find.text('Dr. Dr. Sharma, DVM'), findsOneWidget);
      expect(find.text('TAG-104'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
    });

    testWidgets('VeterinarianAvailabilityScreen renders all 7 days and publishing action', (tester) async {
      final authRepo = MockAuthRepository();
      authRepo.setUser(const User(
        id: 'demo_vet_001',
        name: 'Dr. Sharma, DVM',
        identifier: 'vet@gauprahari.org',
        role: 'veterinarian',
        isDemo: true,
      ));
      final authController = AuthController(authRepository: authRepo);
      await authController.checkAuthStatus();

      final appointmentRepo = FirestoreAppointmentRepository(isDemo: true);

      await tester.pumpWidget(
        buildTestApp(
          authController: authController,
          appointmentRepository: appointmentRepo,
          child: const VeterinarianAvailabilityScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage Availability'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Sunday'), 200);
      expect(find.text('Sunday'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Publish Next 14 Days Slots'), 200);
      expect(find.text('Publish Next 14 Days Slots'), findsOneWidget);
    });

    testWidgets('AppointmentDetailScreen renders consultation details and cancel action', (tester) async {
      final authRepo = MockAuthRepository();
      authRepo.setUser(const User(
        id: 'demo_farmer_001',
        name: 'Ramesh Patel',
        identifier: 'farmer@gauprahari.org',
        role: 'farmer',
        isDemo: true,
      ));
      final authController = AuthController(authRepository: authRepo);
      await authController.checkAuthStatus();
      final farmer = authController.currentUser!;

      final appointmentRepo = FirestoreAppointmentRepository(isDemo: true);

      final slotStart = DateTime.now().add(const Duration(days: 1, hours: 15));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      final slot = AppointmentSlot(
        id: 'slot_detail_test',
        veterinarianUid: 'demo_vet_001',
        startAt: slotStart,
        endAt: slotEnd,
        status: SlotStatus.available,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await appointmentRepo.publishSlots('demo_vet_001', [slot]);

      await appointmentRepo.bookAppointment(
        Appointment(
          id: 'appt_detail_test',
          farmerUid: farmer.id,
          farmerNameSnapshot: farmer.name,
          veterinarianUid: 'demo_vet_001',
          veterinarianNameSnapshot: 'Dr. Sharma, DVM',
          slotId: slot.id,
          cowTagNumber: 'TAG-104',
          startAt: slotStart,
          endAt: slotEnd,
          notes: 'Quarter palpation required.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          authController: authController,
          appointmentRepository: appointmentRepo,
          child: const AppointmentDetailScreen(appointmentId: 'appt_detail_test'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appointment Details'), findsWidgets);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('Dr. Dr. Sharma, DVM'), findsOneWidget);
      expect(find.text('Ramesh Patel'), findsOneWidget);
      expect(find.text('TAG-104'), findsOneWidget);
      expect(find.text('Quarter palpation required.'), findsOneWidget);
      expect(find.text('Cancel Appointment'), findsOneWidget);
    });
  });
}
