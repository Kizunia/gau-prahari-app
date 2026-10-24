import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';
import 'register_screen.dart';

/// Distinct veterinarian login portal enforcing strict role validation per AUTH-06, 07, 08.
class VeterinarianLoginScreen extends StatefulWidget {
  const VeterinarianLoginScreen({super.key});

  @override
  State<VeterinarianLoginScreen> createState() =>
      _VeterinarianLoginScreenState();
}

class _VeterinarianLoginScreenState extends State<VeterinarianLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _roleError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleVetLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _roleError = null);

    if (!_formKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();
    final success = await authController.login(
      identifier: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final user = authController.currentUser;
      if (user != null && !user.isVeterinarian) {
        // AUTH-08: Stored account is NOT a veterinarian (e.g. farmer account signed in here)
        await authController.logout();
        if (!mounted) return;
        setState(() {
          _roleError =
              'Access Restricted: This portal is reserved for registered veterinarians. Farmer accounts cannot log in through this portal.';
        });
      } else {
        // Successfully verified as veterinarian. AuthGate will route to VeterinarianDashboard.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Veterinary Portal'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vet Portal Badge Header
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.medical_services_rounded,
                            size: 40,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Veterinarian Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Clinical Case Reviews & Teleconsultations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Role Restriction Alert Banner
                    if (_roleError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _roleError!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (authController.errorMessage != null && _roleError == null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          authController.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Veterinarian Sign In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Enter your registered veterinarian credentials',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: _emailController,
                            label: 'Veterinarian Email',
                            hint: 'dr.name@clinic.org',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                Validators.validateIdentifier(v, context),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),

                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            validator: (v) =>
                                Validators.validatePassword(v, context),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleVetLogin(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          const SizedBox(height: 24),

                          CustomButton(
                            text: 'Sign In as Veterinarian',
                            icon: Icons.login_rounded,
                            backgroundColor: const Color(0xFF1565C0),
                            isLoading: authController.isLoading,
                            onPressed: _handleVetLogin,
                          ),
                          const SizedBox(height: 16),

                          // Link to register as vet
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Need a vet account? ',
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
                                        initialRole: 'veterinarian',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Register as Vet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}
