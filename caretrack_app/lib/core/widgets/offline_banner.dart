import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppTheme.statusWarningBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 16, color: AppTheme.statusWarning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "You are offline. Showing cached clinic records. Remote updates are paused until reconnected.",
              style: TextStyle(
                color: AppTheme.statusWarning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
