import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../cow_selection/domain/entities/cow.dart';
import '../../../analysis/domain/entities/analysis_result.dart';
import '../../../milk_tester/domain/entities/milk_measurement.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import '../../data/repositories/local_draft_repository.dart';
import '../../domain/entities/review_draft.dart';
import '../../domain/entities/review_request.dart';
import '../../domain/repositories/vet_review_repository.dart';
import '../widgets/review_request_card.dart';
import 'create_review_request_screen.dart';
import 'farmer_review_detail_screen.dart';

/// Screen listing all submitted review requests and locally saved drafts for the farmer.
class FarmerReviewRequestsScreen extends StatefulWidget {
  const FarmerReviewRequestsScreen({super.key});

  @override
  State<FarmerReviewRequestsScreen> createState() =>
      _FarmerReviewRequestsScreenState();
}

class _FarmerReviewRequestsScreenState
    extends State<FarmerReviewRequestsScreen> {
  List<ReviewDraft> _drafts = [];
  bool _isLoadingDrafts = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final user = context.read<AuthController>().currentUser;
    if (user != null) {
      final draftRepo = context.read<LocalDraftRepository>();
      final list = await draftRepo.getDrafts(user.id);
      if (mounted) {
        setState(() {
          _drafts = list;
          _isLoadingDrafts = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingDrafts = false);
      }
    }
  }

  void _openDraft(ReviewDraft draft) {
    try {
      final cowMap = draft.snapshot['cow'] as Map<String, dynamic>? ?? {};
      final predMap =
          draft.snapshot['prediction'] as Map<String, dynamic>? ?? {};
      final milkMap =
          draft.snapshot['milkMeasurement'] as Map<String, dynamic>? ?? {};
      final collarMap =
          draft.snapshot['collarHistory'] as Map<String, dynamic>?;

      final cow = Cow(
        id: cowMap['id'] as String? ?? draft.cowId,
        tagNumber: cowMap['tag_number'] as String? ?? draft.cowTagNumber,
        breed: cowMap['breed'] as String? ?? 'Gir',
        ageYears: (cowMap['age_years'] as num?)?.toInt() ?? 4,
        lactationStage: cowMap['lactation_stage'] as String? ?? '',
        status: cowMap['status'] as String? ?? 'Draft',
        name: cowMap['name'] as String?,
      );

      final result = AnalysisResult.fromJson(predMap);
      final milk = MilkMeasurement.fromJson(milkMap);
      final collar =
          collarMap != null ? CollarHistory.fromJson(collarMap) : null;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateReviewRequestScreen(
            cow: cow,
            result: result,
            milkMeasurement: milk,
            collarHistory: collar,
            existingDraftId: draft.id,
          ),
        ),
      ).then((_) => _loadDrafts());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open draft: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteDraft(ReviewDraft draft) async {
    final user = context.read<AuthController>().currentUser;
    if (user != null) {
      final draftRepo = context.read<LocalDraftRepository>();
      await draftRepo.deleteDraft(user.id, draft.id);
      _loadDrafts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final reviewRepo = context.watch<VetReviewRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Review Requests'),
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('Please log in to view review requests.'))
            : StreamBuilder<List<ReviewRequest>>(
                stream: reviewRepo.streamFarmerRequests(user.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _isLoadingDrafts) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    );
                  }

                  final requests = snapshot.data ?? [];

                  if (requests.isEmpty && _drafts.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Drafts section
                      if (_drafts.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.bookmark_outline_rounded,
                              size: 18,
                              color: Color(0xFFE65100),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Local Drafts (${_drafts.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._drafts.map((d) => _buildDraftCard(d)),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),
                      ],

                      // Submitted requests section
                      if (requests.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.send_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Submitted Requests (${requests.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...requests.map(
                          (req) => ReviewRequestCard(
                            request: req,
                            isVetView: false,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FarmerReviewDetailScreen(
                                    requestId: req.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDraftCard(ReviewDraft draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFFE65100).withValues(alpha: 0.3)),
      ),
      color: const Color(0xFFFFF8E1),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE65100).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.drafts_rounded,
            color: Color(0xFFE65100),
            size: 20,
          ),
        ),
        title: Text(
          'Cow: ${draft.cowTagNumber}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${draft.predictionLabel} (${draft.riskLevel} Risk)\nSaved locally',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              tooltip: 'Submit Draft',
              onPressed: () => _openDraft(draft),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Delete Draft',
              onPressed: () => _deleteDraft(draft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.mark_chat_unread_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Review Requests Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you perform an AI mastitis assessment on a cow, you can request a clinical review from a registered veterinarian directly from the results screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
