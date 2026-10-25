import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../vet_review/presentation/screens/farmer_review_detail_screen.dart';
import '../../../vet_review/presentation/screens/veterinarian_review_detail_screen.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/google_meet_link.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../widgets/appointment_status_badge.dart';

/// Screen displaying the complete details, linked case review, and lifecycle actions for an appointment (SRS FR-04 & FR-05).
class AppointmentDetailScreen extends StatefulWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  bool _isProcessing = false;

  Future<void> _handleCancelAppointment(Appointment appointment, String currentUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment? This action is terminal and will release the time slot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel Appointment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final repo = context.read<AppointmentRepository>();
      await repo.cancelAppointment(
        appointmentId: appointment.id,
        cancelledByUid: currentUid,
        slotId: appointment.slotId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment has been cancelled.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel appointment: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleCompleteAppointment(Appointment appointment, String vetUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Consultation'),
        content: const Text(
          'Mark this consultation appointment as successfully completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Mark Completed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final repo = context.read<AppointmentRepository>();
      await repo.completeAppointment(
        appointmentId: appointment.id,
        veterinarianUid: vetUid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment marked as completed.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete appointment: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _openLinkedReview(Appointment appointment, bool isVet) {
    if (appointment.reviewRequestId == null) return;
    if (isVet) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VeterinarianReviewDetailScreen(
            requestId: appointment.reviewRequestId!,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FarmerReviewDetailScreen(
            requestId: appointment.reviewRequestId!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final repo = context.watch<AppointmentRepository>();

    return StreamBuilder<Appointment?>(
      stream: repo.streamAppointmentById(widget.appointmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        final appointment = snapshot.data;
        if (appointment == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Appointment Details')),
            body: const Center(child: Text('Appointment not found.')),
          );
        }

        final isVet = user?.isVeterinarian == true && user?.isDemo != true;
        final canCancel = appointment.isBooked &&
            user != null &&
            (appointment.farmerUid == user.id || appointment.veterinarianUid == user.id);
        final canComplete = appointment.isBooked && isVet && user?.id == appointment.veterinarianUid;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Appointment Details'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: AppointmentStatusBadge(status: appointment.status),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Date & Time Banner Card
                _buildDateTimeBanner(appointment),
                const SizedBox(height: 14),

                // 2. Participants Section
                _buildParticipantsCard(appointment),
                const SizedBox(height: 14),

                // 3. Animal Details Card (if linked)
                if (appointment.hasLinkedCow) ...[
                  _buildCowCard(appointment),
                  const SizedBox(height: 14),
                ],

                // 4. Linked Clinical Review Request Card
                if (appointment.hasLinkedReview) ...[
                  _buildLinkedReviewCard(appointment, isVet),
                  const SizedBox(height: 14),
                ],

                if (appointment.isBooked &&
                    user != null &&
                    (user.id == appointment.farmerUid ||
                        user.id == appointment.veterinarianUid)) ...[
                  _buildMeetLinkCard(appointment, repo),
                  const SizedBox(height: 14),
                ],

                // 5. Notes / Reason Card
                if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                  _buildNotesCard(appointment.notes!),
                  const SizedBox(height: 14),
                ],

                // 6. Action Buttons
                if (canComplete || canCancel) ...[
                  const SizedBox(height: 10),
                  if (canComplete && user != null)
                    ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleCompleteAppointment(appointment, user.id),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark Consultation Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  if (canComplete && canCancel) const SizedBox(height: 10),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleCancelAppointment(appointment, user.id),
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                      label: const Text(
                        'Cancel Appointment',
                        style: TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateTimeBanner(Appointment appointment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.dateString,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  appointment.timeRangeString,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '30 Minute Field Consultation',
                  style: TextStyle(fontSize: 11, color: AppColors.primary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsCard(Appointment appointment) {
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
          const Text(
            'Consultation Participants',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildParticipantRow(
            icon: Icons.medical_services_outlined,
            role: 'Veterinarian',
            name: 'Dr. ${appointment.veterinarianNameSnapshot}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _buildParticipantRow(
            icon: Icons.person_rounded,
            role: 'Farmer / Client',
            name: appointment.farmerNameSnapshot,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow({
    required IconData icon,
    required String role,
    required String name,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCowCard(Appointment appointment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pets_rounded, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registered Cattle Tag',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(
                  appointment.cowTagNumber ?? appointment.cowId ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedReviewCard(Appointment appointment, bool isVet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Linked Case Review Request',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openLinkedReview(appointment, isVet),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open Thread', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This appointment was booked as a clinical follow-up for case #${appointment.reviewRequestId}. Tap above to review diagnostics, milk SCC readings, and collar telemetry.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
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
          const Text('Consultation Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            notes,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetLinkCard(
    Appointment appointment,
    AppointmentRepository repo,
  ) {
    return StreamBuilder<String?>(
      stream: repo.streamVeterinarianMeetLink(appointment.veterinarianUid),
      builder: (context, snapshot) {
        final meetLink = snapshot.data;
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
              const Row(
                children: [
                  Icon(Icons.video_call_outlined, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Video consultation',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                const Text(
                  'Could not load the veterinarian’s Google Meet link.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else if (meetLink == null || meetLink.trim().isEmpty)
                const Text(
                  'The veterinarian has not added a Google Meet link yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openMeetLink(meetLink),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Join Google Meet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMeetLink(String meetLink) async {
    final normalized = GoogleMeetLink.normalize(meetLink);
    final uri = normalized == null || normalized.isEmpty
        ? null
        : Uri.tryParse(normalized);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Google Meet link.')),
      );
    }
  }
}
