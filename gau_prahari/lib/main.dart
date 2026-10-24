import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/firebase/firebase_initializer.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/firebase_auth_repository.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/cow_selection/data/repositories/cow_repository_impl.dart';
import 'features/cow_selection/presentation/controllers/cow_controller.dart';
import 'features/cow_selection/presentation/screens/cow_selection_screen.dart';
import 'features/vet_review/data/repositories/firestore_vet_review_repository.dart';
import 'features/vet_review/data/repositories/local_draft_repository.dart';
import 'features/vet_review/domain/repositories/vet_review_repository.dart';
import 'features/vet_review/presentation/screens/veterinarian_dashboard_screen.dart';
import 'features/appointment_booking/data/repositories/firestore_appointment_repository.dart';
import 'features/appointment_booking/domain/repositories/appointment_repository.dart';
import 'features/voice_assistant/data/repositories/conversation_repository_impl.dart';
import 'features/voice_assistant/data/services/speech_output_service_impl.dart';
import 'features/voice_assistant/data/services/speech_recognition_service_impl.dart';
import 'features/voice_assistant/data/services/ai_assistant_service.dart';
import 'features/voice_assistant/domain/repositories/conversation_repository.dart';
import 'features/voice_assistant/presentation/controllers/voice_assistant_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (real cloud backend)
  await FirebaseInitializer.initialize();

  final AuthRepository authRepository = FirebaseAuthRepository();
  final authController = AuthController(authRepository: authRepository);
  final cowController = CowController(repository: CowRepositoryImpl());

  // Load locale preference and auth session in parallel
  final localeController = LocaleController();
  await Future.wait([
    authController.checkAuthStatus(),
    localeController.loadSavedLocale(),
  ]);

  runApp(
    GauPrahariApp(
      authController: authController,
      localeController: localeController,
      cowController: cowController,
    ),
  );
}

class GauPrahariApp extends StatelessWidget {
  final AuthController authController;
  final LocaleController localeController;
  final CowController? cowController;
  final VoiceAssistantController? voiceAssistantController;
  final VetReviewRepository? vetReviewRepository;
  final LocalDraftRepository? localDraftRepository;
  final AppointmentRepository? appointmentRepository;

  const GauPrahariApp({
    super.key,
    required this.authController,
    required this.localeController,
    this.cowController,
    this.voiceAssistantController,
    this.vetReviewRepository,
    this.localDraftRepository,
    this.appointmentRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<LocaleController>.value(value: localeController),
        ChangeNotifierProvider<CowController>(
          create: (_) =>
              cowController ?? CowController(repository: CowRepositoryImpl()),
        ),
        Provider<ConversationRepository>(
          create: (_) => ConversationRepositoryImpl(),
        ),
        ChangeNotifierProvider<VoiceAssistantController>(
          create: (context) =>
              voiceAssistantController ??
              VoiceAssistantController(
                conversationRepository: context.read<ConversationRepository>(),
                speechRecognitionService: SpeechRecognitionServiceImpl(),
                speechOutputService: SpeechOutputServiceImpl(),
                responder: AiAssistantService(cowRepository: CowRepositoryImpl()),
              ),
        ),
        Provider<VetReviewRepository>(
          create: (_) =>
              vetReviewRepository ?? FirestoreVetReviewRepository(),
        ),
        Provider<LocalDraftRepository>(
          create: (_) =>
              localDraftRepository ?? LocalDraftRepository(),
        ),
        Provider<AppointmentRepository>(
          create: (context) {
            final auth = context.read<AuthController>();
            final isDemo = auth.currentUser?.isDemo == true;
            return appointmentRepository ??
                FirestoreAppointmentRepository(isDemo: isDemo);
          },
        ),
      ],
      child: Consumer<LocaleController>(
        builder: (context, localeCtrl, _) {
          return MaterialApp(
            title: 'Gau-Prahari',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: localeCtrl.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// Dynamic gate directing the user to Login or Home based on auth state and role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final t = AppLocalizations.of(context);

    if (authController.status == AuthStatus.initial ||
        (authController.isLoading && authController.currentUser == null)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                t.translate('initializingApp'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authController.isAuthenticated) {
      if (authController.currentUser?.isVeterinarian == true &&
          authController.currentUser?.isDemo != true) {
        return const VeterinarianDashboardScreen();
      }
      return const CowSelectionScreen();
    }

    return const LoginScreen();
  }
}
