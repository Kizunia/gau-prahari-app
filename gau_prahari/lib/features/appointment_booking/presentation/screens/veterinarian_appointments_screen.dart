import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_status.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../widgets/appointment_card.dart';
import 'appointment_detail_screen.dart';
import 'veterinarian_availability_screen.dart';

/// Screen displaying appointments assigned to the logged-in veterinarian (SRS Section 8.2).
class VeterinarianAppointmentsScreen extends StatefulWidget {
  const VeterinarianAppointmentsScreen({super.key});

  @override
  State<VeterinarianAppointmentsScreen> createState() =>
      _VeterinarianAppointmentsScreenState();
}

class _VeterinarianAppointmentsScreenState
    extends State<VeterinarianAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final repo = context.watch<AppointmentRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            tooltip: 'Manage Availability',
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VeterinarianAvailabilityScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('Please sign in as a veterinarian.'))
            : StreamBuilder<List<Appointment>>(
                stream: repo.streamVeterinarianAppointments(user.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    );
                  }

                  final all = snapshot.data ?? [];
                  final upcoming = all.where((a) => a.isBooked).toList();
                  final completed = all.where((a) => a.isCompleted).toList();
                  final cancelled = all.where((a) => a.isCancelled).toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(
                        appointments: upcoming,
                        emptyMessage: 'No upcoming appointments scheduled.',
                        status: AppointmentStatus.booked,
                      ),
                      _buildList(
                        appointments: completed,
                        emptyMessage: 'No completed consultations.',
                        status: AppointmentStatus.completed,
                      ),
                      _buildList(
                        appointments: cancelled,
                        emptyMessage: 'No cancelled appointments.',
                        status: AppointmentStatus.cancelled,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildList({
    required List<Appointment> appointments,
    required String emptyMessage,
    required AppointmentStatus status,
  }) {
    if (appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == AppointmentStatus.booked
                      ? Icons.event_available_rounded
                      : (status == AppointmentStatus.completed
                          ? Icons.check_circle_outline_rounded
                          : Icons.cancel_outlined),
                  size: 36,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appt = appointments[index];
        return AppointmentCard(
          appointment: appt,
          isVetView: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AppointmentDetailScreen(appointmentId: appt.id),
              ),
            );
          },
        );
      },
    );
  }
}
