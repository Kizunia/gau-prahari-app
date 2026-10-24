import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';

/// Screen allowing new farmers or veterinarians to register a real Firebase account.
class RegisterScreen extends StatefulWidget {
  final String initialRole;

  const RegisterScreen({super.key, this.initialRole = 'farmer'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late String _selectedRole;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match. Please verify.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final authController = context.read<AuthController>();
    final success = await authController.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
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
                    if (authController.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
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

                    // Card
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
                            'Register for Gau-Prahari',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Select your role and create your credentials',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Role Selector
                          const Text(
                            'Account Role',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedRole = 'farmer'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedRole == 'farmer'
                                          ? AppColors.primaryLight
                                          : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _selectedRole == 'farmer'
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Farmer',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _selectedRole == 'farmer'
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _selectedRole = 'veterinarian'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedRole == 'veterinarian'
                                          ? AppColors.primaryLight
                                          : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _selectedRole == 'veterinarian'
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Veterinarian',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _selectedRole == 'veterinarian'
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Full Name
                          CustomTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'Dr. or Farmer Name',
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),

                          // Email
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'name@example.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                Validators.validateIdentifier(v, context),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),

                          // Password
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'At least 6 characters',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            validator: (v) =>
                                Validators.validatePassword(v, context),
                            textInputAction: TextInputAction.next,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Confirm Password
                          CustomTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            prefixIcon: Icons.lock_clock_outlined,
                            obscureText: _obscureConfirmPassword,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Please confirm your password' : null,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleRegister(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          CustomButton(
                            text: 'Create Account',
                            icon: Icons.person_add_rounded,
                            isLoading: authController.isLoading,
                            onPressed: _handleRegister,
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
