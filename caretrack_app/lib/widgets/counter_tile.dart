import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class CounterTile extends StatelessWidget {
  final String label;
  final int count;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color? bgColor;
  final bool isDanger;
  final VoidCallback? onTap;

  const CounterTile({
    super.key,
    required this.label,
    required this.count,
    this.subtitle,
    required this.icon,
    required this.color,
    this.bgColor,
    this.isDanger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = bgColor ?? (isDanger ? AppTheme.statusMissedBg : Colors.white);
    final effectiveColor = isDanger ? AppTheme.statusMissedText : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDanger
              ? AppTheme.statusMissedText.withAlpha(51)
              : AppTheme.borderGrey,
          ),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectiveColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: effectiveColor),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: effectiveColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDanger ? AppTheme.statusMissedText : AppTheme.slateDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.slateMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
