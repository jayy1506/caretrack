import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/appointment_service.dart';
import '../../../services/patient_service.dart';
import '../../../models/appointment_model.dart';
import '../../../models/patient_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state_view.dart';
import 'add_appointment_screen.dart';

class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  final _appointmentService = AppointmentService();
  final _patientService = PatientService();
  String _filter = 'all'; // 'all' | 'today' | 'upcoming' | 'missed' | 'pending'

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final doctorId = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Appointment',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surfaceWhite,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Visits', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Today', 'today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Upcoming', 'upcoming'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending Confirmation', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Missed / Needs Review', 'missed'),
                ],
              ),
            ),
          ),
          const Divider(),

          // Appointments Stream
          Expanded(
            child: StreamBuilder<List<AppointmentModel>>(
              stream: _appointmentService.streamDoctorAppointments(doctorId),
              builder: (context, snapshot) {
                if (snapshot.data == null && snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Notice: ${snapshot.error}'));
                }

                var list = snapshot.data ?? [];
                final todayStr = DateUtilsHelper.formatStorageDate(DateTime.now());

                // Apply filter
                if (_filter == 'today') {
                  list = list.where((a) => a.date == todayStr).toList();
                } else if (_filter == 'upcoming') {
                  list = list.where((a) => a.date.compareTo(todayStr) > 0 && a.status != 'Cancelled').toList();
                } else if (_filter == 'pending') {
                  list = list.where((a) => a.isPending).toList();
                } else if (_filter == 'missed') {
                  list = list.where((a) => a.status == 'Missed' || (a.date.compareTo(todayStr) < 0 && a.status == 'Scheduled')).toList();
                }

                if (list.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.calendar_month_outlined,
                    title: 'No Appointments Found',
                    description: 'No appointments match the selected filter criteria.',
                    actionText: 'Add Appointment',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final appt = list[index];
                    return _buildAppointmentItemCard(appt);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryNavy,
      backgroundColor: AppTheme.surfaceWhite,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.slateDark,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _filter = value);
        }
      },
    );
  }

  Widget _buildAppointmentItemCard(AppointmentModel appt) {
    return FutureBuilder<PatientModel?>(
      future: _patientService.getPatient(appt.patientId),
      builder: (context, snapshot) {
        final patientName = snapshot.data?.name ?? 'Loading...';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.slateDark),
                    ),
                    StatusBadge(status: appt.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${appt.date} at ${appt.time} • ${appt.type}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted),
                ),
                if (appt.reason != null && appt.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Reason: ${appt.reason}', style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Patient Response: ', style: TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                    StatusBadge(status: appt.confirmationStatus, fontSize: 11),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Actions: Complete, Missed, Reschedule, Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (appt.status != 'Completed' && appt.status != 'Cancelled') ...[
                      TextButton(
                        onPressed: () {
                          _appointmentService.updateAppointmentStatus(
                            appointmentId: appt.id,
                            status: 'Completed',
                          );
                        },
                        child: const Text('Mark Completed', style: TextStyle(color: AppTheme.statusSuccess, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () {
                          _appointmentService.updateAppointmentStatus(
                            appointmentId: appt.id,
                            status: 'Missed',
                          );
                        },
                        child: const Text('Mark Missed', style: TextStyle(color: AppTheme.statusWarning, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.slateMuted),
                      tooltip: 'Delete Appointment',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Appointment?'),
                            content: const Text('Are you sure you want to permanently remove this scheduled visit?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.statusDanger),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          _appointmentService.deleteAppointment(appt.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
