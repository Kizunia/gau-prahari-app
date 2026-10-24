import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/review_request.dart';
import '../../domain/entities/review_status.dart';
import '../../domain/repositories/vet_review_repository.dart';
import '../widgets/review_request_card.dart';
import 'veterinarian_review_detail_screen.dart';
import '../../../appointment_booking/presentation/screens/veterinarian_appointments_screen.dart';
import '../../../appointment_booking/presentation/screens/veterinarian_availability_screen.dart';


/// Dashboard screen for authenticated veterinarians displaying assigned review requests.
class VeterinarianDashboardScreen extends StatefulWidget {
  const VeterinarianDashboardScreen({super.key});

  @override
  State<VeterinarianDashboardScreen> createState() =>
      _VeterinarianDashboardScreenState();
}

class _VeterinarianDashboardScreenState
    extends State<VeterinarianDashboardScreen> {
  ReviewStatus? _selectedStatusFilter;

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from the Veterinary Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authController = context.read<AuthController>();
      await authController.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final repo = context.watch<VetReviewRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vet Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (user != null)
              Text(
                'Dr. ${user.displayName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note_rounded, color: AppColors.primary),
            tooltip: 'Appointments',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VeterinarianAppointmentsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
            tooltip: 'Availability',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VeterinarianAvailabilityScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('Please sign in as a veterinarian.'))
            : Column(
                children: [
                  // Quick Consultation & Scheduling Action Banner
                  _buildAppointmentQuickActions(context),

                  // Filter Chips
                  _buildFilterChips(),
                  const Divider(height: 1, color: AppColors.border),

                  // Request List (streamed)
                  Expanded(
                    child: StreamBuilder<List<ReviewRequest>>(
                      stream: repo.streamVeterinarianRequests(
                        user.id,
                        statusFilter: _selectedStatusFilter,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          );
                        }

                        final requests = snapshot.data ?? [];

                        if (requests.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            return ReviewRequestCard(
                              request: req,
                              isVetView: true,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        VeterinarianReviewDetailScreen(
                                      requestId: req.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'All', 'status': null},
      {'label': 'Pending', 'status': ReviewStatus.pending},
      {'label': 'In Review', 'status': ReviewStatus.inReview},
      {'label': 'Responded', 'status': ReviewStatus.responded},
      {'label': 'Closed', 'status': ReviewStatus.closed},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.map((f) {
          final status = f['status'] as ReviewStatus?;
          final isSelected = _selectedStatusFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1565C0)
                    : AppColors.textSecondary,
              ),
              onSelected: (_) {
                setState(() => _selectedStatusFilter = status);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filterName = _selectedStatusFilter?.label ?? '';
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
                Icons.assignment_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No review requests assigned to you yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filterName.isNotEmpty
                  ? 'There are no $filterName clinical review requests in your queue.'
                  : 'When farmers submit clinical review requests to you, they will appear here live.',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
  Widget _buildAppointmentQuickActions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VeterinarianAppointmentsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.event_note_rounded, size: 18),
              label: const Text(
                'Appointments',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VeterinarianAvailabilityScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text(
                'Set Schedule',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
