import 'package:flutter/material.dart';
import '../../../models/medication_schedule_model.dart';
import '../../../services/medication_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state_view.dart';

class MedicationAdherenceScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const MedicationAdherenceScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    final medicationService = MedicationService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Medication Adherence: $patientName'),
      ),
      body: FutureBuilder<List<MedicationScheduleModel>>(
        future: medicationService.getPatientSchedules(patientId: patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final schedules = snapshot.data ?? [];

          if (schedules.isEmpty) {
            return const EmptyStateView(
              icon: Icons.medication_outlined,
              title: 'No Active Medication Schedules',
              description: 'Medication reminders and adherence logs will display once prescriptions are confirmed.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: schedules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              final adherence = schedule.adherence;
              final rate = adherence.adherenceRate;

              Color rateColor = AppTheme.statusConfirmedText;
              if (rate < 50) {
                rateColor = AppTheme.statusMissedText;
              } else if (rate < 80) {
                rateColor = AppTheme.statusPendingText;
              }

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderGrey),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Course: ${schedule.startDate} to ${schedule.endDate}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        StatusBadge(status: schedule.status.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Adherence KPI summary box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: rateColor, width: 4),
                            ),
                            child: Center(
                              child: Text(
                                '${rate.round()}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: rateColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Adherence Rate',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Taken: ${adherence.takenCount} • Missed: ${adherence.missedCount} (Total: ${adherence.totalReminders})',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Prescribed Medications',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),

                    ...schedule.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, size: 16, color: AppTheme.primaryTeal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.medicineName} (${item.dosage}) - ${item.frequency}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              item.timing.join(', ').toUpperCase(),
                              style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
