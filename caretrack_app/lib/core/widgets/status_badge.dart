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
    Color bg = AppTheme.statusNeutralBg;
    Color fg = AppTheme.statusNeutral;
    IconData? icon;

    final normalized = status.trim().toLowerCase();

    if (normalized == 'confirmed' || normalized == 'delivered' || normalized == 'sent') {
      bg = AppTheme.statusSuccessBg;
      fg = AppTheme.statusSuccess;
      icon = Icons.check_circle_outline;
    } else if (normalized == 'pending' || normalized == 'scheduled') {
      bg = AppTheme.statusWarningBg;
      fg = AppTheme.statusWarning;
      icon = Icons.access_time;
    } else if (normalized == 'missed' || normalized == 'overdue' || normalized == 'failed' || normalized == 'cancelled' || normalized == 'declined') {
      bg = AppTheme.statusDangerBg;
      fg = AppTheme.statusDanger;
      icon = Icons.error_outline;
    } else if (normalized == 'rescheduled' || normalized == 'reschedule requested' || normalized == 'completed') {
      bg = AppTheme.statusPurpleBg;
      fg = AppTheme.statusPurple;
      icon = Icons.event_repeat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
