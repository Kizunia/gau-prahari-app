import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../widgets/appointment_card.dart';
import 'appointment_detail_screen.dart';
import 'veterinarian_directory_screen.dart';

/// Screen displaying the farmer's appointments organized by Upcoming and History (SRS FR-04).
class FarmerAppointmentsScreen extends StatefulWidget {
  const FarmerAppointmentsScreen({super.key});

  @override
  State<FarmerAppointmentsScreen> createState() =>
      _FarmerAppointmentsScreenState();
}

class _FarmerAppointmentsScreenState extends State<FarmerAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('My Appointments'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past / History'),
          ],
        ),
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('Please sign in to view your appointments.'))
            : StreamBuilder<List<Appointment>>(
                stream: repo.streamFarmerAppointments(user.id),
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
                  final history = all.where((a) => !a.isBooked).toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(
                        appointments: upcoming,
                        emptyMessage: 'No upcoming appointments scheduled.',
                        isUpcoming: true,
                      ),
                      _buildList(
                        appointments: history,
                        emptyMessage: 'No past appointment history.',
                        isUpcoming: false,
                      ),
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VeterinarianDirectoryScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Book Veterinarian',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildList({
    required List<Appointment> appointments,
    required String emptyMessage,
    required bool isUpcoming,
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
                  isUpcoming ? Icons.event_available_rounded : Icons.history_rounded,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appt = appointments[index];
        return AppointmentCard(
          appointment: appt,
          isVetView: false,
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
