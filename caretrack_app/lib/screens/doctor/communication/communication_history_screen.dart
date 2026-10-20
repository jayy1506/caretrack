import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state_view.dart';

class CommunicationHistoryScreen extends StatelessWidget {
  const CommunicationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final doctorId = auth.currentUser?.uid ?? '';
    final notificationService = NotificationTrackingService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication History'),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationService.streamDoctorNotifications(doctorId),
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

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const EmptyStateView(
              icon: Icons.outgoing_mail,
              title: 'No Notifications Sent Yet',
              description: 'Real-time records of patient emails, SMS, and reminders will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final channelIcon = log.channel == 'email'
                  ? Icons.email_outlined
                  : (log.channel == 'sms' ? Icons.sms_outlined : Icons.notifications_active_outlined);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.borderLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(channelIcon, size: 20, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log.readableType,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                StatusBadge(status: log.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recipient: ${log.recipient}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.slateDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateUtilsHelper.formatDateTime(log.createdAt),
                              style: const TextStyle(fontSize: 11, color: AppTheme.slateMuted),
                            ),
                            if (log.error != null && log.error!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusDangerBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Error: ${log.error}',
                                  style: const TextStyle(color: AppTheme.statusDanger, fontSize: 11),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
