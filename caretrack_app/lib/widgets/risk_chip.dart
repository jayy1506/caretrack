import 'package:flutter/material.dart';

class RiskChip extends StatelessWidget {
  final double? riskScore; // 0.0 to 1.0
  final String? riskLevel; // 'low' | 'medium' | 'high'
  final List<String>? riskFactors;

  const RiskChip({
    super.key,
    this.riskScore,
    this.riskLevel,
    this.riskFactors,
  });

  @override
  Widget build(BuildContext context) {
    if (riskScore == null && riskLevel == null) {
      return const SizedBox.shrink();
    }

    final level = (riskLevel ?? 'low').toLowerCase();
    final pct = riskScore != null ? (riskScore! * 100).round() : 0;

    Color bg;
    Color textColor;
    IconData icon;
    String label;

    switch (level) {
      case 'high':
        bg = const Color(0xFFFDE3E3);
        textColor = const Color(0xFFA12626);
        icon = Icons.warning_amber_rounded;
        label = 'High Risk ($pct%)';
        break;
      case 'medium':
        bg = const Color(0xFFFFF1D6);
        textColor = const Color(0xFF8A5300);
        icon = Icons.info_outline;
        label = 'Medium Risk ($pct%)';
        break;
      case 'low':
      default:
        bg = const Color(0xFFDCF5EC);
        textColor = const Color(0xFF0B6B4A);
        icon = Icons.check_circle_outline;
        label = 'Low Risk';
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _showRiskDetailsDialog(context, level, pct, riskFactors);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRiskDetailsDialog(
    BuildContext context,
    String level,
    int pct,
    List<String>? factors,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'No-Show Risk Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predicted Risk Score: $pct% (${level.toUpperCase()})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Calculated by predictive scoring engine based on past attendance, booking lead time, and confirmation responses.',
                style: TextStyle(fontSize: 13, color: Color(0xFF53657A)),
              ),
              const SizedBox(height: 12),
              if (factors != null && factors.isNotEmpty) ...[
                const Text(
                  'Contributing Factors:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...factors.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF0F766E))),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'No adverse risk factors detected for this appointment.',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
