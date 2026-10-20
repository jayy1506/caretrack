import 'package:flutter/material.dart';
import '../models/prescription_safety_warning.dart';

class PrescriptionSafetyBanner extends StatelessWidget {
  final List<PrescriptionSafetyWarning> warnings;
  final bool isOverridden;
  final ValueChanged<String>? onDoctorOverride;

  const PrescriptionSafetyBanner({
    super.key,
    required this.warnings,
    this.isOverridden = false,
    this.onDoctorOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDCF5EC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0B6B4A).withAlpha(51)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF0B6B4A), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Safety Check Passed: No drug interactions or allergy conflicts detected.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0B6B4A),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasDanger = warnings.any((w) => w.isDanger);
    final bgColor = hasDanger ? const Color(0xFFFDE3E3) : const Color(0xFFFFF1D6);
    final borderColor = hasDanger ? const Color(0xFFA12626) : const Color(0xFF8A5300);
    final textColor = hasDanger ? const Color(0xFFA12626) : const Color(0xFF8A5300);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasDanger ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
                color: textColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasDanger
                    ? 'Clinical Safety Alert (${warnings.length} issues)'
                    : 'Prescription Warnings (${warnings.length} issues)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              if (isOverridden)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Override Logged',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F2A47)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      w.clinicalRationale,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF53657A),
                      ),
                    ),
                  ],
                ),
              )),
          if (!isOverridden && onDoctorOverride != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.verified_user_outlined, size: 16),
                label: const Text('Doctor Override'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showOverrideDialog(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showOverrideDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Confirm Doctor Override'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are choosing to override the automated safety check warnings. This action and your clinical rationale will be permanently recorded in the audit log.',
                style: TextStyle(fontSize: 13, color: Color(0xFF53657A)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter clinical justification (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final reason = controller.text.trim();
                Navigator.of(ctx).pop();
                onDoctorOverride?.call(reason.isEmpty ? 'Doctor clinical judgement override' : reason);
              },
              child: const Text('Confirm Override'),
            ),
          ],
        );
      },
    );
  }
}
