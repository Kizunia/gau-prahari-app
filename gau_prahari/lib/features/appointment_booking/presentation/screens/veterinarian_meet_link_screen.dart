import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/google_meet_link.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Lets a veterinarian manage the one Google Meet link shared by their
/// appointments.
class VeterinarianMeetLinkScreen extends StatefulWidget {
  const VeterinarianMeetLinkScreen({super.key});

  @override
  State<VeterinarianMeetLinkScreen> createState() =>
      _VeterinarianMeetLinkScreenState();
}

class _VeterinarianMeetLinkScreenState
    extends State<VeterinarianMeetLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  bool _didLoad = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _veterinarianUid;
  String? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;

    final user = context.read<AuthController>().currentUser;
    if (user == null || !user.isVeterinarian) {
      _loadError = 'Sign in with a veterinarian account to manage this link.';
      _isLoading = false;
      return;
    }

    _veterinarianUid = user.id;
    _loadMeetLink(user.id);
  }

  Future<void> _loadMeetLink(String veterinarianUid) async {
    try {
      final link = await context
          .read<AppointmentRepository>()
          .getVeterinarianMeetLink(veterinarianUid);
      if (!mounted) return;
      _linkController.text = link ?? '';
    } catch (_) {
      if (!mounted) return;
      _loadError = 'Could not load your saved Google Meet link.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMeetLink() async {
    if (!_formKey.currentState!.validate() || _veterinarianUid == null) return;

    setState(() => _isSaving = true);
    try {
      await context.read<AppointmentRepository>().saveVeterinarianMeetLink(
        veterinarianUid: _veterinarianUid!,
        meetLink: _linkController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _linkController.text.trim().isEmpty
                ? 'Google Meet link removed from your appointments.'
                : 'Google Meet link saved for your appointments.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save the link: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Google Meet Link')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_loadError!, textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(
                    Icons.video_call_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'One link for your appointments',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Farmers with an appointment can use this link to join a video consultation with you. Updating it here changes the link for all your appointments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Google Meet URL',
                        hintText: 'https://meet.google.com/abc-defg-hij',
                        prefixIcon: Icon(Icons.link_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          GoogleMeetLink.normalize(value ?? '') == null
                          ? 'Enter a valid https://meet.google.com link.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveMeetLink,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving...' : 'Save Meet Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (_linkController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => setState(_linkController.clear),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove shared link'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
