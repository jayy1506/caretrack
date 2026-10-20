import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state_view.dart';
import '../doctor/appointments/add_appointment_screen.dart';
import '../doctor/inbox/inbox_screen.dart';

class ReceptionistHomeScreen extends StatefulWidget {
  final String clinicId;

  const ReceptionistHomeScreen({super.key, this.clinicId = 'default-clinic'});

  @override
  State<ReceptionistHomeScreen> createState() => _ReceptionistHomeScreenState();
}

class _ReceptionistHomeScreenState extends State<ReceptionistHomeScreen> {
  final _appointmentService = AppointmentService();
  final Set<String> _checkedInApptIds = {};

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toString().split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reception Front Desk'),
        actions: [
          IconButton(
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.mark_email_unread_outlined),
            ),
            tooltip: 'Clinic WhatsApp Inbox',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InboxScreen(clinicId: widget.clinicId)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Booking Action Bar
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderGrey),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_task_rounded, color: AppTheme.primaryTeal, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Front Desk Quick Actions',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Book patient into doctor availability slot or check in arrivals.',
                          style: TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Quick Book'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Today's Schedule Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Patient Schedule",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
                Text(
                  todayStr,
                  style: const TextStyle(fontSize: 13, color: AppTheme.slateMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Today's appointments stream
            StreamBuilder<List<AppointmentModel>>(
              stream: _appointmentService.streamDoctorAppointments(''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data ?? [];
                final todayVisits = all.where((a) => a.date == todayStr).toList();

                if (todayVisits.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.event_available,
                    title: 'No Appointments Today',
                    description: 'No visits currently booked on the schedule for today.',
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todayVisits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final appt = todayVisits[index];
                    final isCheckedIn = _checkedInApptIds.contains(appt.id);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderGrey),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              appt.time,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appt.reason ?? 'General Consultation',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Status: ${appt.confirmationStatus}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: isCheckedIn ? 'Confirmed' : appt.confirmationStatus),
                          const SizedBox(width: 10),
                          if (!isCheckedIn)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primaryTeal),
                                foregroundColor: AppTheme.primaryTeal,
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.how_to_reg, size: 16),
                              label: const Text('Check In', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                setState(() => _checkedInApptIds.add(appt.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Patient checked in! Doctor alerted.'),
                                    backgroundColor: AppTheme.statusConfirmedText,
                                  ),
                                );
                              },
                            )
                          else
                            const Icon(Icons.check_circle, color: AppTheme.statusConfirmedText, size: 28),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
