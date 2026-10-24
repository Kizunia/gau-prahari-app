import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../analysis/domain/entities/analysis_result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../milk_tester/domain/entities/milk_measurement.dart';
import '../../data/repositories/local_draft_repository.dart';
import '../../domain/entities/review_draft.dart';
import '../../domain/entities/review_request.dart';
import '../../domain/entities/review_status.dart';
import '../../domain/entities/vet_profile.dart';
import '../../domain/repositories/vet_review_repository.dart';
import 'farmer_review_detail_screen.dart';
import 'farmer_review_requests_screen.dart';

/// Screen allowing a farmer to choose a registered veterinarian and submit or draft a review request.
class CreateReviewRequestScreen extends StatefulWidget {
  final Cow cow;
  final AnalysisResult result;
  final MilkMeasurement milkMeasurement;
  final CollarHistory? collarHistory;
  final String? existingDraftId;

  const CreateReviewRequestScreen({
    super.key,
    required this.cow,
    required this.result,
    required this.milkMeasurement,
    this.collarHistory,
    this.existingDraftId,
  });

  @override
  State<CreateReviewRequestScreen> createState() =>
      _CreateReviewRequestScreenState();
}

class _CreateReviewRequestScreenState extends State<CreateReviewRequestScreen> {
  bool _isLoadingVets = true;
  String? _loadError;
  List<VetProfile> _vets = [];
  VetProfile? _selectedVet;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchVeterinarians();
  }

  Future<void> _fetchVeterinarians() async {
    setState(() {
      _isLoadingVets = true;
      _loadError = null;
    });

    try {
      final repo = context.read<VetReviewRepository>();
      final vets = await repo.getRegisteredVeterinarians();
      if (!mounted) return;
      setState(() {
        _vets = vets;
        _selectedVet = vets.isNotEmpty ? vets.first : null;
        _isLoadingVets = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load veterinarian directory: ${e.toString()}';
        _isLoadingVets = false;
      });
    }
  }

  Future<void> _saveAsDraft() async {
    final authCtrl = context.read<AuthController>();
    final user = authCtrl.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save a draft.')),
      );
      return;
    }

    final draftRepo = context.read<LocalDraftRepository>();
    final snapshot = ReviewRequest.buildSnapshot(
      cow: widget.cow,
      result: widget.result,
      milkMeasurement: widget.milkMeasurement,
      collarHistory: widget.collarHistory,
    );

    final draft = ReviewDraft(
      id: widget.existingDraftId ??
          'draft_${DateTime.now().millisecondsSinceEpoch}',
      farmerUid: user.id,
      cowId: widget.cow.id,
      cowTagNumber: widget.cow.tagNumber,
      predictionLabel: widget.result.isHighRisk
          ? 'High Mastitis Risk'
          : (widget.result.isModerateRisk
              ? 'Moderate Risk'
              : 'Healthy / Low Risk'),
      riskLevel: widget.result.riskLevel,
      snapshot: snapshot,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await draftRepo.saveDraft(draft);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report saved to local drafts successfully.'),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const FarmerReviewRequestsScreen()),
    );
  }

  Future<void> _submitReview() async {
    if (_selectedVet == null) return;
    final authCtrl = context.read<AuthController>();
    final user = authCtrl.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a request.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = context.read<VetReviewRepository>();
      final draftRepo = context.read<LocalDraftRepository>();

      final snapshot = ReviewRequest.buildSnapshot(
        cow: widget.cow,
        result: widget.result,
        milkMeasurement: widget.milkMeasurement,
        collarHistory: widget.collarHistory,
      );

      final predictionLabel = widget.result.isHighRisk
          ? 'High Mastitis Risk'
          : (widget.result.isModerateRisk
              ? 'Moderate Risk'
              : 'Healthy / Low Risk');

      final request = ReviewRequest(
        id: '', // Will be assigned by Firestore docRef
        farmerUid: user.id,
        farmerNameSnapshot:
            user.displayName.isNotEmpty ? user.displayName : 'Farmer',
        veterinarianUid: _selectedVet!.uid,
        veterinarianNameSnapshot: _selectedVet!.name,
        cowId: widget.cow.id,
        cowTagNumber: widget.cow.tagNumber,
        predictionLabel: predictionLabel,
        riskLevel: widget.result.riskLevel,
        status: ReviewStatus.pending,
        snapshotVersion: 1,
        snapshot: snapshot,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final requestId = await repo.submitReviewRequest(request);

      // If this came from a draft, delete the local draft now
      if (widget.existingDraftId != null) {
        await draftRepo.deleteDraft(user.id, widget.existingDraftId!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review request submitted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate to review detail screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FarmerReviewDetailScreen(requestId: requestId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Vet Review'),
      ),
      body: SafeArea(
        child: _isLoadingVets
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _loadError != null
                ? _buildErrorView()
                : _vets.isEmpty
                    ? _buildNoVetsView()
                    : _buildFormView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _fetchVeterinarians,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVetsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Veterinarians Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are currently no registered veterinarians online. You can save this diagnostic report as a local draft and submit it later when a veterinarian is available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Save as Local Draft',
              icon: Icons.save_alt_rounded,
              onPressed: _saveAsDraft,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchVeterinarians,
              child: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Cow & Prediction summary card
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subject: ${widget.cow.displayName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.cow.tagNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'AI Assessment: ',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${widget.result.riskLevel} RISK',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.result.isHighRisk
                          ? AppColors.error
                          : (widget.result.isModerateRisk
                              ? AppColors.warning
                              : AppColors.success),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Select Veterinarian Section
        const Text(
          'Select Veterinarian',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        ..._vets.map((vet) {
          final isSelected = _selectedVet?.uid == vet.uid;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryLight.withValues(alpha: 0.4)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(
                vet.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                vet.designation ?? 'Field Veterinary Officer',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                setState(() => _selectedVet = vet);
              },
            ),
          );
        }),
        const SizedBox(height: 20),

        // Information notice card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Clinical Data Included in Snapshot',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '• Cow profile (Tag, Breed, Age, Lactation stage)\n'
                '• AI prediction score, confidence and risk level\n'
                '• Milk tester parameters (Temperature, pH, Conductivity, SCC, Fat, SNF)\n'
                '• 14-day smart collar telemetry and activity records',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        CustomButton(
          text: _isSubmitting
              ? 'Submitting Request...'
              : 'Confirm & Submit to Vet',
          icon: Icons.send_rounded,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submitReview,
        ),
        const SizedBox(height: 12),

        // Or Save Draft option
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _saveAsDraft,
          icon: const Icon(Icons.bookmark_border_rounded, size: 18),
          label: const Text('Save as Local Draft'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
