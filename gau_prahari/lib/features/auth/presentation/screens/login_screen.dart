import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';
import 'register_screen.dart';
import 'veterinarian_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _roleError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillDemoCredentials(String identifier, String password) {
    setState(() {
      _identifierController.text = identifier;
      _passwordController.text = password;
      _roleError = null;
    });
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _roleError = null);

    if (!_formKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();
    final success = await authController.login(
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (success && mounted) {
      final user = authController.currentUser;
      // AUTH-08: Check role for real accounts. Veterinarians should use the Veterinarian portal.
      if (user != null && !user.isDemo && user.isVeterinarian) {
        await authController.logout();
        if (mounted) {
          setState(() {
            _roleError =
                'Veterinarian account detected. Please use the Veterinarian Portal to sign in.';
          });
        }
      }
    }
  }

  Future<void> _handleTryDemo() async {
    final authController = context.read<AuthController>();
    await authController.loginDemo(role: 'farmer');
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    _buildHeader(),
                    const SizedBox(height: 28),

                    // Role Restriction Error
                    if (_roleError != null) ...[
                      _buildErrorBanner(_roleError!),
                      const SizedBox(height: 16),
                    ],

                    // Error Alert Banner
                    if (authController.errorMessage != null && _roleError == null) ...[
                      _buildErrorBanner(authController.errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            t.translate('signIn'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.translate('signInSubtitle'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Identifier Field
                          CustomTextField(
                            controller: _identifierController,
                            label: t.translate('emailOrId'),
                            hint: t.translate('emailHint'),
                            prefixIcon: Icons.badge_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                Validators.validateIdentifier(value, context),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          CustomTextField(
                            controller: _passwordController,
                            label: t.translate('password'),
                            hint: t.translate('passwordHint'),
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            validator: (value) =>
                                Validators.validatePassword(value, context),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          CustomButton(
                            text: t.translate('signInButton'),
                            icon: Icons.login_rounded,
                            isLoading: authController.isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 16),

                          // Create Account Link (AUTH-02)
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(
                                        initialRole: 'farmer',
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  t.translate('createAccount'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 14),

                          // Separate Veterinarian Portal Link (AUTH-06)
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.medical_services_rounded,
                              size: 18,
                              color: Color(0xFF1565C0),
                            ),
                            label: Text(
                              t.translate('vetPortal'),
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1565C0)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VeterinarianLoginScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Direct Try Demo Entry Point (AUTH-09)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_circle_outline_rounded,
                          color: AppColors.secondary),
                      label: Text(
                        t.translate('tryDemo'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _handleTryDemo,
                    ),
                    const SizedBox(height: 16),

                    // Quick Demo Credentials Selector
                    _buildDemoChips(),
                    const SizedBox(height: 24),

                    // Footer
                    Text(
                      t.translate('footerText'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 42,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t.translate('appName'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.translate('appSubtitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoChips() {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.translate('quickDemoLogins'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _demoChip(
                label: t.translate('fieldVet'),
                email: 'vet@gauprahari.org',
                pass: 'vet123',
              ),
              _demoChip(
                label: t.translate('farmSupervisor'),
                email: 'farmer@gauprahari.org',
                pass: 'farmer123',
              ),
              _demoChip(
                label: t.translate('evaluator'),
                email: 'admin@gauprahari.org',
                pass: 'admin123',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _demoChip({
    required String label,
    required String email,
    required String pass,
  }) {
    return InkWell(
      onTap: () => _fillDemoCredentials(email, pass),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
