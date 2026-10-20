import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppTheme.statusPendingBg;
    Color fg = AppTheme.statusPendingText;
    IconData? icon;

    final normalized = status.trim().toLowerCase();

    if (normalized == 'confirmed' || normalized == 'delivered' || normalized == 'sent' || normalized == 'completed') {
      bg = AppTheme.statusConfirmedBg;
      fg = AppTheme.statusConfirmedText;
      icon = Icons.check_circle_outline;
    } else if (normalized == 'pending' || normalized == 'scheduled' || normalized == 'upcoming') {
      bg = AppTheme.statusPendingBg;
      fg = AppTheme.statusPendingText;
      icon = Icons.access_time;
    } else if (normalized == 'rescheduled' || normalized == 'reschedule requested' || normalized == 'reschedule_requested') {
      bg = AppTheme.statusRescheduleBg;
      fg = AppTheme.statusRescheduleText;
      icon = Icons.event_repeat;
    } else if (normalized == 'missed' || normalized == 'overdue' || normalized == 'failed' || normalized == 'cancelled' || normalized == 'declined' || normalized == 'at_risk') {
      bg = AppTheme.statusMissedBg;
      fg = AppTheme.statusMissedText;
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
